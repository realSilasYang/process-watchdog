class SvgRenderLibrary {
    static MaximumInputBytes := 16 * 1024 * 1024
    static MaximumRenderSize := 2048

    __New(libraryPath) {
        this.LibraryPath := libraryPath
        this.ModuleHandle := 0
        this.Options := 0
        this.Functions := Map()
        this.LoadAttempted := false
        this.Rendering := false
    }

    IsAvailable() {
        return this.EnsureLoaded()
    }

    EnsureLoaded() {
        if this.ModuleHandle && this.Options
            return true
        if this.LoadAttempted
            return false
        this.LoadAttempted := true
        if !FileExist(this.LibraryPath) || DirExist(this.LibraryPath)
            return false

        moduleHandle := DllCall("kernel32\LoadLibraryExW",
            "WStr", this.LibraryPath, "Ptr", 0, "UInt", 0x00000900, "Ptr")
        if !moduleHandle
            moduleHandle := DllCall("kernel32\LoadLibraryW",
                "WStr", this.LibraryPath, "Ptr")
        if !moduleHandle
            return false

        requiredExports := [
            "resvg_options_create",
            "resvg_options_set_resources_dir",
            "resvg_options_set_dpi",
            "resvg_options_load_system_fonts",
            "resvg_options_destroy",
            "resvg_parse_tree_from_data",
            "resvg_is_image_empty",
            "resvg_get_image_size",
            "resvg_render",
            "resvg_tree_destroy"
        ]
        resolvedFunctions := Map()
        for exportName in requiredExports {
            functionAddress := DllCall("kernel32\GetProcAddress",
                "Ptr", moduleHandle, "AStr", exportName, "Ptr")
            if !functionAddress {
                DllCall("kernel32\FreeLibrary", "Ptr", moduleHandle)
                return false
            }
            resolvedFunctions[exportName] := functionAddress
        }

        options := DllCall(resolvedFunctions["resvg_options_create"], "Ptr")
        if !options {
            DllCall("kernel32\FreeLibrary", "Ptr", moduleHandle)
            return false
        }
        try DllCall(resolvedFunctions["resvg_options_load_system_fonts"],
            "Ptr", options)
        catch {
            try DllCall(resolvedFunctions["resvg_options_destroy"],
                "Ptr", options)
            DllCall("kernel32\FreeLibrary", "Ptr", moduleHandle)
            return false
        }

        this.ModuleHandle := moduleHandle
        this.Options := options
        this.Functions := resolvedFunctions
        return true
    }

    RenderFile(filePath, dpi, renderSize) {
        if this.Rendering
            return 0
        try sourceSize := FileGetSize(filePath)
        catch
            return 0
        if sourceSize <= 0 || sourceSize > SvgRenderLibrary.MaximumInputBytes
            return 0
        try renderSize := Integer(renderSize)
        catch
            return 0
        renderSize := Max(1, Min(SvgRenderLibrary.MaximumRenderSize,
            renderSize))
        try dpi := Float(dpi)
        catch
            dpi := 96.0
        dpi := Max(24.0, Min(960.0, dpi))

        previousCritical := A_IsCritical
        Critical("On")
        this.Rendering := true
        renderTree := 0
        try {
            if !this.EnsureLoaded()
                return 0
            try svgData := FileRead(filePath, "RAW")
            catch
                return 0
            if !IsObject(svgData) || svgData.Size <= 0
                return 0

            SplitPath(filePath, , &resourceDirectory)
            resourceDirectoryUtf8 := this.EncodeUtf8(resourceDirectory)
            DllCall(this.Functions["resvg_options_set_resources_dir"],
                "Ptr", this.Options, "Ptr", resourceDirectoryUtf8.Ptr)
            DllCall(this.Functions["resvg_options_set_dpi"],
                "Ptr", this.Options, "Float", dpi)
            parseResult := DllCall(
                this.Functions["resvg_parse_tree_from_data"],
                "Ptr", svgData.Ptr, "UPtr", svgData.Size,
                "Ptr", this.Options, "Ptr*", &renderTree, "Int")
            if parseResult != 0 || !renderTree
                return 0
            if DllCall(this.Functions["resvg_is_image_empty"],
                "Ptr", renderTree, "Char")
                return 0

            packedSize := DllCall(this.Functions["resvg_get_image_size"],
                "Ptr", renderTree, "Int64")
            sizeBytes := Buffer(8, 0)
            NumPut("Int64", packedSize, sizeBytes, 0)
            sourceWidth := NumGet(sizeBytes, 0, "Float")
            sourceHeight := NumGet(sizeBytes, 4, "Float")
            if sourceWidth <= 0 || sourceHeight <= 0
                || sourceWidth > 1000000 || sourceHeight > 1000000
                return 0

            aspectRatio := sourceWidth / sourceHeight
            if aspectRatio >= 1 {
                outputWidth := renderSize
                outputHeight := Max(1, Round(renderSize / aspectRatio))
            } else {
                outputHeight := renderSize
                outputWidth := Max(1, Round(renderSize * aspectRatio))
            }
            scale := Min(outputWidth / sourceWidth,
                outputHeight / sourceHeight)
            translateX := (outputWidth - sourceWidth * scale) / 2
            translateY := (outputHeight - sourceHeight * scale) / 2
            transform := Buffer(24, 0)
            NumPut("Float", scale, transform, 0)
            NumPut("Float", 0.0, transform, 4)
            NumPut("Float", 0.0, transform, 8)
            NumPut("Float", scale, transform, 12)
            NumPut("Float", translateX, transform, 16)
            NumPut("Float", translateY, transform, 20)
            pixels := Buffer(outputWidth * outputHeight * 4, 0)
            ; Windows x64 ABI 对 24 字节的按值结构参数传入指向调用方副本的
            ; 指针；AHK 的 Ptr 参数与 resvg_transform 在此 ABI 下完全对应。
            DllCall(this.Functions["resvg_render"],
                "Ptr", renderTree, "Ptr", transform.Ptr,
                "UInt", outputWidth, "UInt", outputHeight,
                "Ptr", pixels.Ptr)

            visiblePixels := 0
            Loop outputWidth * outputHeight {
                pixelOffset := (A_Index - 1) * 4
                red := NumGet(pixels, pixelOffset, "UChar")
                blue := NumGet(pixels, pixelOffset + 2, "UChar")
                NumPut("UChar", blue, pixels, pixelOffset)
                NumPut("UChar", red, pixels, pixelOffset + 2)
                if NumGet(pixels, pixelOffset + 3, "UChar")
                    visiblePixels++
            }
            if !visiblePixels
                return 0
            ; resvg 输出预乘 RGBA；交换红蓝通道后即为 WIC 所需的预乘 BGRA。
            return {Width: outputWidth, Height: outputHeight, Pixels: pixels}
        } catch {
            return 0
        } finally {
            if renderTree && this.Functions.Has("resvg_tree_destroy")
                try DllCall(this.Functions["resvg_tree_destroy"],
                    "Ptr", renderTree)
            this.Rendering := false
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    EncodeUtf8(value) {
        requiredBytes := StrPut(String(value), "UTF-8")
        encoded := Buffer(requiredBytes, 0)
        StrPut(String(value), encoded, "UTF-8")
        return encoded
    }

    Shutdown(*) {
        if this.Options && this.Functions.Has("resvg_options_destroy")
            try DllCall(this.Functions["resvg_options_destroy"],
                "Ptr", this.Options)
        this.Options := 0
        this.Functions := Map()
        if this.ModuleHandle
            try DllCall("kernel32\FreeLibrary", "Ptr", this.ModuleHandle)
        this.ModuleHandle := 0
        this.Rendering := false
    }
}

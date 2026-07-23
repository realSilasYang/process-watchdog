; Native dark-theme helpers and the main-window icon rendering pipeline.

/*  * ========================================================================
 * 5. 系统底层原生 UI 接口调用集
 * 通过 DWM 和 UxTheme 等组件，调整界面的深色及原生组件适配。
 * ========================================================================
 */
SetDarkTitleBar(hWnd) {
    ; 修改 DWM 窗口属性以调用深色层级的标题栏
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", attr, "Int*", 1, "Int", 4)

        ; 开启进程级别的暗黑模式支持及当前窗口暗黑，以适配滚动条和右键菜单 (Ordinal 135 & 133)
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if (uxtheme) {
                SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
                if SetPreferredAppMode
                    DllCall(SetPreferredAppMode, "Int", 1) ; 1 = AllowDark

                AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                if AllowDarkModeForWindow
                    DllCall(AllowDarkModeForWindow, "Ptr", hWnd, "Int", 1)
            }
        }
    }
}

SetWindowIcon(hWnd, iconPath) {
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        || !FileExist(iconPath)
        return false

    hIconSmall := 0
    hIconBig := 0
    try {
        ; 两个尺寸必须都加载成功后才替换，避免窗口继续引用已被释放的旧图标。
        hIconSmall := DllCall("user32\LoadImage", "Ptr", 0, "Str", iconPath,
            "UInt", 1, "Int", SysGet(49), "Int", SysGet(50),
            "UInt", 0x00000010, "Ptr")
        hIconBig := DllCall("user32\LoadImage", "Ptr", 0, "Str", iconPath,
            "UInt", 1, "Int", SysGet(11), "Int", SysGet(12),
            "UInt", 0x00000010, "Ptr")
    } catch {
        DestroyIconHandles([hIconSmall, hIconBig])
        return false
    }
    if !hIconSmall || !hIconBig {
        DestroyIconHandles([hIconSmall, hIconBig])
        return false
    }

    previousSmall := 0
    smallAssigned := false
    try {
        previousSmall := SendMessage(Win32.WM_SETICON, Win32.ICON_SMALL,
            hIconSmall, , hWnd)
        smallAssigned := true
        SendMessage(Win32.WM_SETICON, Win32.ICON_BIG, hIconBig, , hWnd)
    } catch {
        if smallAssigned && DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
            try SendMessage(Win32.WM_SETICON, Win32.ICON_SMALL,
                previousSmall, , hWnd)
        DestroyIconHandles([hIconSmall, hIconBig])
        return false
    }

    oldHandles := App.iconResources.ReplaceWindowIcons(hWnd,
        [hIconSmall, hIconBig])
    DestroyIconHandles(oldHandles, hIconSmall, hIconBig)
    return true
}

SetDarkListView(hLV) {
    if !hLV
        return
    ; 控件首次显示时可能被系统重新套用主题，因此显示前后各应用一次。
    ApplyDarkListViewTheme(hLV)
    SetTimer(ApplyDarkListViewTheme.Bind(hLV), -100)
}

CreateMainImageList(statusIconIndices) {
    statusIconIndices.Clear()
    imageList := IL_Create(10, 10, 1)
    if !imageList
        return imageList
    iconResources := App.iconResources
    previousMetrics := iconResources.GetMainIconMetrics()
    dpi := 96
    try dpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd, "UInt")
    if !dpi
        dpi := 96
    iconResources.UpdateMainIconMetrics(dpi)
    try DllCall("comctl32\ImageList_SetIconSize", "Ptr", imageList,
        "Int", iconResources.MainIconCellPixelSize,
        "Int", iconResources.MainIconCellPixelSize)
    try AddMainStatusIcons(imageList, statusIconIndices)
    catch {
        try IL_Destroy(imageList)
        statusIconIndices.Clear()
        iconResources.RestoreMainIconMetrics(previousMetrics)
        return 0
    }
    return imageList
}

GetShellImageListIcon(filePath, imageListKind) {
    sfi := Buffer(A_PtrSize + 688, 0)
    flags := Win32.SHGFI_SYSICONINDEX
    attributes := 0
    if !FileExist(filePath) {
        flags |= Win32.SHGFI_USEFILEATTRIBUTES
        attributes := Win32.FILE_ATTRIBUTE_NORMAL
    }
    if !DllCall("shell32\SHGetFileInfoW", "WStr", filePath, "UInt", attributes,
        "Ptr", sfi, "UInt", sfi.Size, "UInt", flags, "UPtr")
        return 0

    systemIconIndex := NumGet(sfi, A_PtrSize, "Int")
    imageListIid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString", "WStr", "{46EB5926-582E-4017-9FDF-E8998DAA0950}",
        "Ptr", imageListIid, "Int") < 0
        return 0

    shellImageList := 0
    hIcon := 0
    try {
        if DllCall("shell32\SHGetImageList", "Int", imageListKind,
            "Ptr", imageListIid, "Ptr*", &shellImageList, "Int") < 0
            || !shellImageList
            return 0
        vtable := NumGet(shellImageList, 0, "Ptr")
        getIcon := NumGet(vtable, 10 * A_PtrSize, "Ptr")
        if DllCall(getIcon, "Ptr", shellImageList,
            "Int", systemIconIndex, "UInt", Win32.ILD_TRANSPARENT,
            "Ptr*", &hIcon, "Int") == 0 {
            resultIcon := hIcon
            hIcon := 0
            return resultIcon
        }
    } catch {
        return 0
    } finally {
        if hIcon
            try DllCall("user32\DestroyIcon", "Ptr", hIcon)
        if shellImageList
            try ReleaseIconComObject(shellImageList)
    }
    return 0
}

GetPreferredMainIcon(filePath, &useHighQualityResampling := false) {
    useHighQualityResampling := false
    iconSource := ParseCustomIconSource(filePath)
    sourcePath := iconSource.Path
    if !FileExist(sourcePath) || DirExist(sourcePath)
        return 0
    SplitPath(sourcePath, , , &extension)
    extension := StrLower(extension)
    if extension == "exe" || extension == "ico"
        || extension == "dll" || extension == "cpl" {
        sourceSize := SelectClosestIconSourceSize(
            App.iconResources.MainIconPixelSize)
        hIcon := 0
        iconResourceId := 0
        extractedCount := 0
        try extractedCount := DllCall("user32\PrivateExtractIconsW",
            "WStr", sourcePath, "Int", iconSource.Index,
            "Int", sourceSize, "Int", sourceSize,
            "Ptr*", &hIcon, "UInt*", &iconResourceId,
            "UInt", 1, "UInt", 0, "UInt")
        if extractedCount && hIcon {
            useHighQualityResampling := true
            return hIcon
        }
        if hIcon
            DllCall("user32\DestroyIcon", "Ptr", hIcon)
    }
    return GetShellImageListIcon(sourcePath, Win32.SHIL_EXTRALARGE)
}

SelectClosestIconSourceSize(targetSize) {
    for candidateSize in [16, 20, 24, 32, 40, 48, 64, 96, 128, 256] {
        if candidateSize >= targetSize
            return candidateSize
    }
    return 256
}

EnsureIconResampler() {
    iconResources := App.iconResources
    if iconResources.GetResamplerFactory()
        return true
    factoryClsid := Buffer(16, 0)
    factoryIid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString", "WStr", "{CACAF262-9370-4615-A13B-9F5539DA4C0A}",
        "Ptr", factoryClsid, "Int") < 0
        return false
    if DllCall("ole32\CLSIDFromString", "WStr", "{EC5EC8A9-C395-4314-9C77-54D7A935FF70}",
        "Ptr", factoryIid, "Int") < 0
        return false
    factory := 0
    if DllCall("ole32\CoCreateInstance", "Ptr", factoryClsid, "Ptr", 0,
        "UInt", 1, "Ptr", factoryIid, "Ptr*", &factory, "Int") < 0
        || !factory
        return false
    if iconResources.InstallResamplerFactory(factory)
        return true
    ; 若可重入调用已先安装工厂，释放本次多创建的 COM 引用。
    try ReleaseIconComObject(factory)
    return iconResources.GetResamplerFactory() != 0
}

IsIconResourceContainerExtension(extension) {
    extension := StrLower(Trim(extension))
    return InStr("|exe|dll|cpl|", "|" extension "|") != 0
}

ParseCustomIconSource(source) {
    sourceText := NormalizeTargetPath(String(source))
    result := {Path: sourceText, Index: 0, HasIndex: false}
    if !RegExMatch(sourceText, "s)^(.*),\s*(-?\d+)\s*$", &match)
        return result
    candidatePath := NormalizeTargetPath(Trim(match[1], " `t`r`n`""))
    SplitPath(candidatePath, , , &extension)
    if !IsIconResourceContainerExtension(extension)
        return result
    try iconIndex := Integer(match[2])
    catch
        return result
    result.Path := candidatePath
    result.Index := iconIndex
    result.HasIndex := true
    return result
}

FormatCustomIconSource(filePath, iconIndex := 0,
    includeResourceIndex := false) {
    filePath := NormalizeTargetPath(filePath)
    if filePath == "" || !includeResourceIndex
        return filePath
    try iconIndex := Integer(iconIndex)
    catch
        iconIndex := 0
    return filePath "," iconIndex
}

CustomIconSourceExists(source) {
    iconSource := ParseCustomIconSource(source)
    return iconSource.Path != "" && FileExist(iconSource.Path)
        && !DirExist(iconSource.Path)
}

ConfigureSingleFileDialogInitialPath(fileDialog, initialPath) {
    initialPath := NormalizeTargetPath(initialPath)
    if initialPath == ""
        return
    initialName := ""
    if DirExist(initialPath) {
        initialDirectory := initialPath
    } else {
        SplitPath(initialPath, &initialName, &initialDirectory)
        if !DirExist(initialDirectory)
            return
    }
    shellItemIid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString",
        "WStr", "{43826D1E-E718-42EE-BC55-A1E261C37BFE}",
        "Ptr", shellItemIid, "Int") < 0
        return
    shellItem := 0
    try {
        if DllCall("shell32\SHCreateItemFromParsingName",
            "WStr", initialDirectory, "Ptr", 0, "Ptr", shellItemIid,
            "Ptr*", &shellItem, "Int") < 0 || !shellItem
            return
        ComCall(12, fileDialog, "Ptr", shellItem)
        if initialName != ""
            ComCall(15, fileDialog, "Str", initialName)
    } finally {
        if shellItem
            try ObjRelease(shellItem)
    }
}

ReadSingleFileDialogPath(fileDialog, ownerHwnd := 0) {
    if ComCall(3, fileDialog, "Ptr", ownerHwnd, "Int") != 0
        return ""
    shellItem := 0
    pathBuffer := 0
    try {
        ComCall(20, fileDialog, "Ptr*", &shellItem)
        ComCall(5, shellItem, "UInt", 0x80058000,
            "Ptr*", &pathBuffer)
        return pathBuffer ? StrGet(pathBuffer, "UTF-16") : ""
    } finally {
        if pathBuffer
            try DllCall("ole32\CoTaskMemFree", "Ptr", pathBuffer)
        if shellItem
            try ObjRelease(shellItem)
    }
}

SelectFileWithNamedFilter(ownerHwnd, initialPath, prompt,
    filterName, filterPattern) {
    try {
        fileDialog := ComObject(
            "{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}",
            "{D57C7288-D4AD-4768-BE02-9D969532D960}")
        ; 文件类型名称和扩展名模式分开传递。界面只显示中文名称，
        ; 不再为了 FileSelect 的语法暴露空格加半角括号。
        ComCall(9, fileDialog, "UInt", 0x1840)
        filterSpec := Buffer(A_PtrSize * 2, 0)
        NumPut("Ptr", StrPtr(filterName), filterSpec, 0)
        NumPut("Ptr", StrPtr(filterPattern), filterSpec, A_PtrSize)
        ComCall(4, fileDialog, "UInt", 1, "Ptr", filterSpec)
        ComCall(17, fileDialog, "Str", prompt)
        ConfigureSingleFileDialogInitialPath(fileDialog, initialPath)
        return ReadSingleFileDialogPath(fileDialog, ownerHwnd)
    } catch {
        return ""
    }
}

PickCustomIconResource(ownerHwnd, filePath, initialIndex := 0) {
    filePath := NormalizeTargetPath(filePath)
    if filePath == "" || !FileExist(filePath) || DirExist(filePath)
        return ""
    capacity := 32768
    pathBuffer := Buffer(capacity * 2, 0)
    StrPut(filePath, pathBuffer, "UTF-16")
    try iconIndex := Integer(initialIndex)
    catch
        iconIndex := 0
    try selected := DllCall("shell32\PickIconDlg", "Ptr", ownerHwnd,
        "Ptr", pathBuffer, "UInt", capacity, "Int*", &iconIndex, "Int")
    catch
        return ""
    if !selected
        return ""
    selectedPath := NormalizeTargetPath(StrGet(pathBuffer, "UTF-16"))
    if selectedPath == "" || !FileExist(selectedPath)
        return ""
    return FormatCustomIconSource(selectedPath, iconIndex, true)
}

GetCustomIconSourceExtension(filePath) {
    iconSource := ParseCustomIconSource(filePath)
    SplitPath(iconSource.Path, , , &extension)
    return StrLower(Trim(extension))
}

IsRasterImageIconExtension(extension) {
    extension := StrLower(Trim(extension))
    return InStr("|png|jpg|jpeg|jpe|jfif|bmp|gif|tif|tiff|webp|",
        "|" extension "|") != 0
}

IsSupportedCustomIconSource(filePath) {
    extension := GetCustomIconSourceExtension(filePath)
    return IsRasterImageIconExtension(extension)
        || InStr("|ico|exe|dll|cpl|lnk|svg|ani|",
            "|" extension "|") != 0
}

CreatePaddedIconFromPremultipliedPixels(pixelBuffer, pixelWidth,
    pixelHeight, cellSize) {
    if !IsObject(pixelBuffer) || pixelWidth <= 0 || pixelHeight <= 0
        || cellSize < pixelWidth || cellSize < pixelHeight
        return 0
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    colorBitmap := 0
    maskBitmap := 0
    try {
        if !screenDC
            return 0
        bitmapInfo := Buffer(40, 0)
        NumPut("UInt", 40, bitmapInfo, 0)
        NumPut("Int", cellSize, bitmapInfo, 4)
        NumPut("Int", -cellSize, bitmapInfo, 8)
        NumPut("UShort", 1, bitmapInfo, 12)
        NumPut("UShort", 32, bitmapInfo, 14)
        colorBits := 0
        colorBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
            "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &colorBits,
            "Ptr", 0, "UInt", 0, "Ptr")
        if !colorBitmap || !colorBits
            return 0

        DllCall("ntdll\RtlZeroMemory", "Ptr", colorBits,
            "UPtr", cellSize * cellSize * 4)
        offsetX := Floor((cellSize - pixelWidth) / 2)
        offsetY := Floor((cellSize - pixelHeight) / 2)
        Loop pixelHeight {
            row := A_Index - 1
            destination := colorBits
                + ((offsetY + row) * cellSize + offsetX) * 4
            source := pixelBuffer.Ptr + row * pixelWidth * 4
            DllCall("ntdll\RtlMoveMemory", "Ptr", destination,
                "Ptr", source, "UPtr", pixelWidth * 4)
        }
        maskBitmap := CreateIconMaskFromAlpha(screenDC, colorBits,
            cellSize, cellSize)
        if !maskBitmap
            return 0
        iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        NumPut("Int", 1, iconInfo, 0)
        bitmapOffset := A_PtrSize == 8 ? 16 : 12
        NumPut("Ptr", maskBitmap, iconInfo, bitmapOffset)
        NumPut("Ptr", colorBitmap, iconInfo, bitmapOffset + A_PtrSize)
        return DllCall("user32\CreateIconIndirect", "Ptr", iconInfo, "Ptr")
    } finally {
        if maskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
        if colorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", colorBitmap)
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

EnqueueLightMattePixel(pixelBuffer, matteMask, queue, pixelIndex,
    backgroundBlue, backgroundGreen, backgroundRed, tolerance) {
    if pixelIndex < 0 || pixelIndex >= matteMask.Size
        || NumGet(matteMask, pixelIndex, "UChar")
        return false
    offset := pixelIndex * 4
    if NumGet(pixelBuffer, offset + 3, "UChar") < 250
        return false
    distance := Max(
        Abs(NumGet(pixelBuffer, offset, "UChar") - backgroundBlue),
        Abs(NumGet(pixelBuffer, offset + 1, "UChar") - backgroundGreen),
        Abs(NumGet(pixelBuffer, offset + 2, "UChar") - backgroundRed))
    if distance > tolerance
        return false
    NumPut("UChar", 1, matteMask, pixelIndex)
    queue.Push(pixelIndex)
    return true
}

RemoveConnectedLightMatte(pixelBuffer, width, height) {
    if !IsObject(pixelBuffer) || width <= 1 || height <= 1
        return false
    cornerOffsets := [0, (width - 1) * 4,
        (height - 1) * width * 4,
        (width * height - 1) * 4]
    blueTotal := 0
    greenTotal := 0
    redTotal := 0
    for offset in cornerOffsets {
        if NumGet(pixelBuffer, offset + 3, "UChar") < 250
            return false
        blue := NumGet(pixelBuffer, offset, "UChar")
        green := NumGet(pixelBuffer, offset + 1, "UChar")
        red := NumGet(pixelBuffer, offset + 2, "UChar")
        if Min(blue, green, red) < 245
            return false
        blueTotal += blue
        greenTotal += green
        redTotal += red
    }
    backgroundBlue := Round(blueTotal / cornerOffsets.Length)
    backgroundGreen := Round(greenTotal / cornerOffsets.Length)
    backgroundRed := Round(redTotal / cornerOffsets.Length)
    for offset in cornerOffsets {
        if Max(
            Abs(NumGet(pixelBuffer, offset, "UChar") - backgroundBlue),
            Abs(NumGet(pixelBuffer, offset + 1, "UChar") - backgroundGreen),
            Abs(NumGet(pixelBuffer, offset + 2, "UChar") - backgroundRed)) > 8
            return false
    }

    ; 只沿边缘清理近白色像素；较深的描边必须成为阻断边界，避免
    ; 洪泛进入图标内部的银白面板或高光区域。
    tolerance := 32
    matteMask := Buffer(width * height, 0)
    queue := []
    enqueue := (pixelIndex) => EnqueueLightMattePixel(pixelBuffer,
        matteMask, queue, pixelIndex, backgroundBlue, backgroundGreen,
        backgroundRed, tolerance)
    Loop width {
        x := A_Index - 1
        enqueue(x)
        enqueue((height - 1) * width + x)
    }
    Loop height {
        y := A_Index - 1
        enqueue(y * width)
        enqueue(y * width + width - 1)
    }
    queueIndex := 1
    while queueIndex <= queue.Length {
        pixelIndex := queue[queueIndex++]
        x := Mod(pixelIndex, width)
        if x > 0
            enqueue(pixelIndex - 1)
        if x + 1 < width
            enqueue(pixelIndex + 1)
        if pixelIndex >= width
            enqueue(pixelIndex - width)
        if pixelIndex + width < width * height
            enqueue(pixelIndex + width)
    }
    for pixelIndex in queue {
        offset := pixelIndex * 4
        inputBlue := NumGet(pixelBuffer, offset, "UChar")
        inputGreen := NumGet(pixelBuffer, offset + 1, "UChar")
        inputRed := NumGet(pixelBuffer, offset + 2, "UChar")
        outputAlpha := Max(
            Abs(inputBlue - backgroundBlue),
            Abs(inputGreen - backgroundGreen),
            Abs(inputRed - backgroundRed))
        inverseAlpha := 255 - outputAlpha
        outputBlue := Max(0, Min(outputAlpha,
            Round(inputBlue - backgroundBlue * inverseAlpha / 255)))
        outputGreen := Max(0, Min(outputAlpha,
            Round(inputGreen - backgroundGreen * inverseAlpha / 255)))
        outputRed := Max(0, Min(outputAlpha,
            Round(inputRed - backgroundRed * inverseAlpha / 255)))
        NumPut("UChar", outputBlue, pixelBuffer, offset)
        NumPut("UChar", outputGreen, pixelBuffer, offset + 1)
        NumPut("UChar", outputRed, pixelBuffer, offset + 2)
        NumPut("UChar", outputAlpha, pixelBuffer, offset + 3)
    }
    return queue.Length > 0
}

CreatePaddedIconFromWicSource(wicSource, sourceWidth, sourceHeight,
    iconSize, cellSize, removeLightMatte := false) {
    if !wicSource || sourceWidth <= 0 || sourceHeight <= 0
        || iconSize <= 0 || cellSize < iconSize || !EnsureIconResampler()
        return 0
    resamplerFactory := App.iconResources.GetResamplerFactory()
    if !resamplerFactory
        return 0

    scale := Min(iconSize / sourceWidth, iconSize / sourceHeight)
    scaledWidth := Max(1, Min(iconSize, Round(sourceWidth * scale)))
    scaledHeight := Max(1, Min(iconSize, Round(sourceHeight * scale)))
    wicScaler := 0
    try {
        factoryVtable := NumGet(resamplerFactory, 0, "Ptr")
        createScaler := NumGet(factoryVtable, 11 * A_PtrSize, "Ptr")
        if DllCall(createScaler, "Ptr", resamplerFactory,
            "Ptr*", &wicScaler, "Int") < 0 || !wicScaler
            return 0
        scalerVtable := NumGet(wicScaler, 0, "Ptr")
        initializeScaler := NumGet(scalerVtable, 8 * A_PtrSize, "Ptr")
        interpolationMode := (scaledWidth < sourceWidth
            || scaledHeight < sourceHeight) ? 3 : 2
        if DllCall(initializeScaler, "Ptr", wicScaler, "Ptr", wicSource,
            "UInt", scaledWidth, "UInt", scaledHeight,
            "Int", interpolationMode, "Int") < 0
            return 0
        scaledPixels := Buffer(scaledWidth * scaledHeight * 4, 0)
        copyPixels := NumGet(scalerVtable, 7 * A_PtrSize, "Ptr")
        if DllCall(copyPixels, "Ptr", wicScaler, "Ptr", 0,
            "UInt", scaledWidth * 4, "UInt", scaledPixels.Size,
            "Ptr", scaledPixels, "Int") < 0
            return 0
        if removeLightMatte
            RemoveConnectedLightMatte(scaledPixels, scaledWidth,
                scaledHeight)
        return CreatePaddedIconFromPremultipliedPixels(scaledPixels,
            scaledWidth, scaledHeight, cellSize)
    } finally {
        try ReleaseIconComObject(wicScaler)
    }
}

CreateWicDecodedPaddedIcon(filePath, iconSize, cellSize,
    removeLightMatte := false) {
    if !EnsureIconResampler()
        return 0
    resamplerFactory := App.iconResources.GetResamplerFactory()
    decoder := 0
    frame := 0
    converter := 0
    try {
        factoryVtable := NumGet(resamplerFactory, 0, "Ptr")
        createDecoderFromFilename := NumGet(factoryVtable,
            3 * A_PtrSize, "Ptr")
        if DllCall(createDecoderFromFilename, "Ptr", resamplerFactory,
            "WStr", filePath, "Ptr", 0, "UInt", Win32.GENERIC_READ,
            "Int", 1, "Ptr*", &decoder, "Int") < 0 || !decoder
            return 0
        decoderVtable := NumGet(decoder, 0, "Ptr")
        getFrame := NumGet(decoderVtable, 13 * A_PtrSize, "Ptr")
        if DllCall(getFrame, "Ptr", decoder, "UInt", 0,
            "Ptr*", &frame, "Int") < 0 || !frame
            return 0

        createFormatConverter := NumGet(factoryVtable,
            10 * A_PtrSize, "Ptr")
        if DllCall(createFormatConverter, "Ptr", resamplerFactory,
            "Ptr*", &converter, "Int") < 0 || !converter
            return 0
        pixelFormat := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString",
            "WStr", "{6FDDC324-4E03-4BFE-B185-3D77768DC910}",
            "Ptr", pixelFormat, "Int") < 0
            return 0
        converterVtable := NumGet(converter, 0, "Ptr")
        initializeConverter := NumGet(converterVtable,
            8 * A_PtrSize, "Ptr")
        if DllCall(initializeConverter, "Ptr", converter, "Ptr", frame,
            "Ptr", pixelFormat, "Int", 0, "Ptr", 0, "Double", 0.0,
            "Int", 0, "Int") < 0
            return 0
        getSize := NumGet(converterVtable, 3 * A_PtrSize, "Ptr")
        sourceWidth := 0
        sourceHeight := 0
        if DllCall(getSize, "Ptr", converter, "UInt*", &sourceWidth,
            "UInt*", &sourceHeight, "Int") < 0
            return 0
        return CreatePaddedIconFromWicSource(converter, sourceWidth,
            sourceHeight, iconSize, cellSize, removeLightMatte)
    } finally {
        try ReleaseIconComObject(converter)
        try ReleaseIconComObject(frame)
        try ReleaseIconComObject(decoder)
    }
}

RemoveShellThumbnailMatte(pixelBuffer, width, height) {
    if !IsObject(pixelBuffer) || width <= 0 || height <= 0
        return false
    cornerOffsets := [0, (width - 1) * 4,
        (height - 1) * width * 4,
        ((height - 1) * width + width - 1) * 4]
    backgroundOffset := cornerOffsets[1]
    backgroundAlpha := 255
    for cornerOffset in cornerOffsets {
        cornerAlpha := NumGet(pixelBuffer, cornerOffset + 3, "UChar")
        if cornerAlpha < backgroundAlpha {
            backgroundAlpha := cornerAlpha
            backgroundOffset := cornerOffset
        }
    }
    ; Shell 的 SVG 缩略图会合成在半透明主题底色上。四角均接近
    ; 完全不透明时应视为图像自身背景，不能误抠除。
    if backgroundAlpha >= 250
        return false
    backgroundBlue := NumGet(pixelBuffer, backgroundOffset, "UChar")
    backgroundGreen := NumGet(pixelBuffer, backgroundOffset + 1, "UChar")
    backgroundRed := NumGet(pixelBuffer, backgroundOffset + 2, "UChar")
    denominator := 255 - backgroundAlpha
    Loop width * height {
        pixelOffset := (A_Index - 1) * 4
        inputAlpha := NumGet(pixelBuffer, pixelOffset + 3, "UChar")
        outputAlpha := Max(0, Min(255,
            Round((inputAlpha - backgroundAlpha) * 255 / denominator)))
        inverseAlpha := 255 - outputAlpha
        outputBlue := Max(0, Min(outputAlpha,
            Round(NumGet(pixelBuffer, pixelOffset, "UChar")
                - backgroundBlue * inverseAlpha / 255)))
        outputGreen := Max(0, Min(outputAlpha,
            Round(NumGet(pixelBuffer, pixelOffset + 1, "UChar")
                - backgroundGreen * inverseAlpha / 255)))
        outputRed := Max(0, Min(outputAlpha,
            Round(NumGet(pixelBuffer, pixelOffset + 2, "UChar")
                - backgroundRed * inverseAlpha / 255)))
        NumPut("UChar", outputBlue, pixelBuffer, pixelOffset)
        NumPut("UChar", outputGreen, pixelBuffer, pixelOffset + 1)
        NumPut("UChar", outputRed, pixelBuffer, pixelOffset + 2)
        NumPut("UChar", outputAlpha, pixelBuffer, pixelOffset + 3)
    }
    return true
}

ConvertSvgLengthToPixels(value, unit) {
    try value := Float(value)
    catch
        return 0
    if value <= 0
        return 0
    unit := StrLower(Trim(unit))
    switch unit {
        case "", "px": return value
        case "in": return value * 96
        case "cm": return value * 96 / 2.54
        case "mm": return value * 96 / 25.4
        case "q": return value * 96 / 101.6
        case "pt": return value * 96 / 72
        case "pc": return value * 16
    }
    ; 百分比、em、rem 等长度依赖外部布局环境，不能作为独立图标尺寸。
    return 0
}

GetSvgIntrinsicAspectRatio(filePath) {
    svgFile := 0
    try {
        svgFile := FileOpen(filePath, "r", "UTF-8")
        if !svgFile
            return 1
        ; 根元素及其尺寸通常位于文件开头；设上限避免异常大文件阻塞 UI。
        svgPrefix := svgFile.Read(131072)
    } catch {
        return 1
    } finally {
        if svgFile
            try svgFile.Close()
    }
    if !RegExMatch(svgPrefix, "is)<svg\b([^>]*)>", &rootMatch)
        return 1
    rootAttributes := rootMatch[1]
    lengthPattern := "i)\b{1}\s*=\s*[\x22']\s*"
        . "([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?)"
        . "\s*([a-z%]*)"
    width := 0
    height := 0
    if RegExMatch(rootAttributes, Format(lengthPattern, "width"),
        &widthMatch)
        width := ConvertSvgLengthToPixels(widthMatch[1], widthMatch[2])
    if RegExMatch(rootAttributes, Format(lengthPattern, "height"),
        &heightMatch)
        height := ConvertSvgLengthToPixels(heightMatch[1], heightMatch[2])
    if width > 0 && height > 0
        return Max(0.01, Min(100, width / height))

    if RegExMatch(rootAttributes,
        "i)\bviewBox\s*=\s*[\x22']\s*([^\x22']+)[\x22']",
        &viewBoxMatch) {
        viewBoxText := RegExReplace(Trim(viewBoxMatch[1]), "[,\s]+", " ")
        viewBoxParts := StrSplit(viewBoxText, " ")
        if viewBoxParts.Length == 4 {
            try viewBoxWidth := Float(viewBoxParts[3])
            catch
                viewBoxWidth := 0
            try viewBoxHeight := Float(viewBoxParts[4])
            catch
                viewBoxHeight := 0
            if viewBoxWidth > 0 && viewBoxHeight > 0
                return Max(0.01, Min(100, viewBoxWidth / viewBoxHeight))
        }
    }
    return 1
}

CopyShellBitmapPixels(bitmapObject, sourceWidth, sourceHeight,
    destinationPixels) {
    sourceBitsOffset := A_PtrSize == 8 ? 24 : 20
    sourceBits := NumGet(bitmapObject, sourceBitsOffset, "Ptr")
    sourceStride := Abs(NumGet(bitmapObject, 12, "Int"))
    dibHeaderOffset := A_PtrSize == 8 ? 32 : 24
    dibHeight := NumGet(bitmapObject, dibHeaderOffset + 8, "Int")
    if !sourceBits || sourceStride < sourceWidth * 4
        return false
    sourceIsTopDown := dibHeight < 0
    Loop sourceHeight {
        destinationRow := A_Index - 1
        sourceRow := sourceIsTopDown ? destinationRow
            : sourceHeight - destinationRow - 1
        DllCall("ntdll\RtlMoveMemory",
            "Ptr", destinationPixels.Ptr + destinationRow * sourceWidth * 4,
            "Ptr", sourceBits + sourceRow * sourceStride,
            "UPtr", sourceWidth * 4)
    }
    return true
}

GetShellThumbnailPixelSnapshot(filePath, preferredSize) {
    imageFactoryIid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString",
        "WStr", "{BCC18B79-BA16-442F-80C4-8A59C30C463B}",
        "Ptr", imageFactoryIid, "Int") < 0
        return 0
    imageFactory := 0
    thumbnailBitmap := 0
    screenDC := 0
    try {
        if DllCall("shell32\SHCreateItemFromParsingName", "WStr", filePath,
            "Ptr", 0, "Ptr", imageFactoryIid, "Ptr*", &imageFactory,
            "Int") < 0 || !imageFactory
            return 0
        sourceSize := Max(128, Min(256, preferredSize))
        packedSize := (sourceSize & 0xFFFFFFFF)
            | ((sourceSize & 0xFFFFFFFF) << 32)
        imageFactoryVtable := NumGet(imageFactory, 0, "Ptr")
        getImage := NumGet(imageFactoryVtable, 3 * A_PtrSize, "Ptr")
        flags := Win32.SIIGBF_THUMBNAILONLY
            | Win32.SIIGBF_BIGGERSIZEOK | Win32.SIIGBF_SCALEUP
        if DllCall(getImage, "Ptr", imageFactory, "Int64", packedSize,
            "UInt", flags, "Ptr*", &thumbnailBitmap, "Int") < 0
            || !thumbnailBitmap
            return 0

        ; 读取完整 DIBSECTION，优先复制原始 Alpha。GetDIBits 会在部分
        ; Shell 缩略图上把半透明背景展平为不透明像素。
        bitmapObject := Buffer(A_PtrSize == 8 ? 104 : 84, 0)
        if !DllCall("gdi32\GetObjectW", "Ptr", thumbnailBitmap,
            "Int", bitmapObject.Size, "Ptr", bitmapObject)
            return 0
        sourceWidth := NumGet(bitmapObject, 4, "Int")
        sourceHeight := Abs(NumGet(bitmapObject, 8, "Int"))
        if sourceWidth <= 0 || sourceHeight <= 0
            return 0
        sourceInfo := Buffer(40, 0)
        NumPut("UInt", 40, sourceInfo, 0)
        NumPut("Int", sourceWidth, sourceInfo, 4)
        NumPut("Int", -sourceHeight, sourceInfo, 8)
        NumPut("UShort", 1, sourceInfo, 12)
        NumPut("UShort", 32, sourceInfo, 14)
        sourcePixels := Buffer(sourceWidth * sourceHeight * 4, 0)
        if !CopyShellBitmapPixels(bitmapObject, sourceWidth, sourceHeight,
            sourcePixels) {
            screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
            if !screenDC || !DllCall("gdi32\GetDIBits", "Ptr", screenDC,
                "Ptr", thumbnailBitmap, "UInt", 0, "UInt", sourceHeight,
                "Ptr", sourcePixels, "Ptr", sourceInfo, "UInt", 0)
                return 0
        }
        return {Width: sourceWidth, Height: sourceHeight,
            Pixels: sourcePixels}
    } finally {
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
        if thumbnailBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", thumbnailBitmap)
        try ReleaseIconComObject(imageFactory)
    }
}

CreatePixelSnapshotPaddedIcon(snapshot, iconSize, cellSize,
    desiredAspectRatio := 0) {
    if !IsObject(snapshot) || !snapshot.HasOwnProp("Width")
        || !snapshot.HasOwnProp("Height") || !snapshot.HasOwnProp("Pixels")
        || snapshot.Width <= 0 || snapshot.Height <= 0
        || !EnsureIconResampler()
        return 0
    resamplerFactory := App.iconResources.GetResamplerFactory()
    pixelFormat := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString",
        "WStr", "{6FDDC324-4E03-4BFE-B185-3D77768DC910}",
        "Ptr", pixelFormat, "Int") < 0
        return 0
    wicSource := 0
    try {
        factoryVtable := NumGet(resamplerFactory, 0, "Ptr")
        createFromMemory := NumGet(factoryVtable, 20 * A_PtrSize, "Ptr")
        if DllCall(createFromMemory, "Ptr", resamplerFactory,
            "UInt", snapshot.Width, "UInt", snapshot.Height,
            "Ptr", pixelFormat, "UInt", snapshot.Width * 4,
            "UInt", snapshot.Pixels.Size, "Ptr", snapshot.Pixels,
            "Ptr*", &wicSource, "Int") < 0 || !wicSource
            return 0
        layoutWidth := snapshot.Width
        layoutHeight := snapshot.Height
        if desiredAspectRatio > 0
            layoutWidth := layoutHeight * desiredAspectRatio
        return CreatePaddedIconFromWicSource(wicSource, layoutWidth,
            layoutHeight, iconSize, cellSize)
    } finally {
        try ReleaseIconComObject(wicSource)
    }
}

CreateShellThumbnailPaddedIcon(filePath, iconSize, cellSize,
    desiredAspectRatio := 0) {
    snapshot := GetShellThumbnailPixelSnapshot(filePath,
        Max(128, Min(256, iconSize * 4)))
    if !snapshot
        return 0
    RemoveShellThumbnailMatte(snapshot.Pixels, snapshot.Width,
        snapshot.Height)
    return CreatePixelSnapshotPaddedIcon(snapshot, iconSize, cellSize,
        desiredAspectRatio)
}

CreateSvgBackdropVariant(svgText, backgroundColor) {
    background := '<rect x="-10%" y="-10%" width="120%" height="120%" '
        . 'style="fill:#' backgroundColor
        . '!important;stroke:none!important;opacity:1!important"/>'
    variant := RegExReplace(svgText, "is)(<svg\b[^>]*>)",
        "$1" background, &replacementCount, 1)
    return replacementCount == 1 ? variant : ""
}

IsShellMatteCandidate(blackPixels, whitePixels, offset,
    blackReference, whiteReference) {
    if Abs(NumGet(blackPixels, offset, "UChar") - blackReference[1]) > 10
        || Abs(NumGet(blackPixels, offset + 1, "UChar")
            - blackReference[2]) > 10
        || Abs(NumGet(blackPixels, offset + 2, "UChar")
            - blackReference[3]) > 10
        || Abs(NumGet(whitePixels, offset, "UChar")
            - whiteReference[1]) > 10
        || Abs(NumGet(whitePixels, offset + 1, "UChar")
            - whiteReference[2]) > 10
        || Abs(NumGet(whitePixels, offset + 2, "UChar")
            - whiteReference[3]) > 10
        return false
    return Abs(NumGet(whitePixels, offset, "UChar")
            - NumGet(blackPixels, offset, "UChar"))
        + Abs(NumGet(whitePixels, offset + 1, "UChar")
            - NumGet(blackPixels, offset + 1, "UChar"))
        + Abs(NumGet(whitePixels, offset + 2, "UChar")
            - NumGet(blackPixels, offset + 2, "UChar")) <= 12
}

BuildShellMatteMask(blackSnapshot, whiteSnapshot) {
    width := blackSnapshot.Width
    height := blackSnapshot.Height
    pixelCount := width * height
    matteMask := Buffer(pixelCount, 0)
    blackReference := [
        NumGet(blackSnapshot.Pixels, 0, "UChar"),
        NumGet(blackSnapshot.Pixels, 1, "UChar"),
        NumGet(blackSnapshot.Pixels, 2, "UChar")]
    whiteReference := [
        NumGet(whiteSnapshot.Pixels, 0, "UChar"),
        NumGet(whiteSnapshot.Pixels, 1, "UChar"),
        NumGet(whiteSnapshot.Pixels, 2, "UChar")]
    queue := []
    enqueueCandidate := (pixelIndex) => (
        pixelIndex >= 0 && pixelIndex < pixelCount
        && !NumGet(matteMask, pixelIndex, "UChar")
        && IsShellMatteCandidate(blackSnapshot.Pixels,
            whiteSnapshot.Pixels, pixelIndex * 4,
            blackReference, whiteReference)
        ? (NumPut("UChar", 1, matteMask, pixelIndex),
            queue.Push(pixelIndex))
        : 0)
    Loop width {
        x := A_Index - 1
        enqueueCandidate(x)
        enqueueCandidate((height - 1) * width + x)
    }
    Loop height {
        y := A_Index - 1
        enqueueCandidate(y * width)
        enqueueCandidate(y * width + width - 1)
    }
    queueIndex := 1
    while queueIndex <= queue.Length {
        pixelIndex := queue[queueIndex++]
        x := Mod(pixelIndex, width)
        if x > 0
            enqueueCandidate(pixelIndex - 1)
        if x + 1 < width
            enqueueCandidate(pixelIndex + 1)
        if pixelIndex >= width
            enqueueCandidate(pixelIndex - width)
        if pixelIndex + width < pixelCount
            enqueueCandidate(pixelIndex + width)
    }
    return matteMask
}

RecoverSvgPixelsFromBackdrops(blackSnapshot, whiteSnapshot) {
    if !IsObject(blackSnapshot) || !IsObject(whiteSnapshot)
        || blackSnapshot.Width != whiteSnapshot.Width
        || blackSnapshot.Height != whiteSnapshot.Height
        return ""
    width := blackSnapshot.Width
    height := blackSnapshot.Height
    changedPixels := 0
    Loop width * height {
        offset := (A_Index - 1) * 4
        difference := Abs(NumGet(blackSnapshot.Pixels,
            offset, "UChar") - NumGet(whiteSnapshot.Pixels,
            offset, "UChar"))
            + Abs(NumGet(blackSnapshot.Pixels,
                offset + 1, "UChar") - NumGet(whiteSnapshot.Pixels,
                offset + 1, "UChar"))
            + Abs(NumGet(blackSnapshot.Pixels,
                offset + 2, "UChar") - NumGet(whiteSnapshot.Pixels,
                offset + 2, "UChar"))
        if difference >= 60
            changedPixels++
    }
    ; 有些 Shell SVG 处理器会无视文件内容，始终返回白页类型图标。
    ; 黑白底派生文件若连 5% 像素都没有明显变化，得到的不是 SVG 渲染。
    if changedPixels < Max(16, Floor(width * height * 0.05))
        return ""
    recoveredPixels := Buffer(width * height * 4, 0)
    matteMask := BuildShellMatteMask(blackSnapshot, whiteSnapshot)
    Loop width * height {
        pixelIndex := A_Index - 1
        if NumGet(matteMask, pixelIndex, "UChar")
            continue
        offset := pixelIndex * 4
        blackBlue := NumGet(blackSnapshot.Pixels, offset, "UChar")
        blackGreen := NumGet(blackSnapshot.Pixels, offset + 1, "UChar")
        blackRed := NumGet(blackSnapshot.Pixels, offset + 2, "UChar")
        whiteBlue := NumGet(whiteSnapshot.Pixels, offset, "UChar")
        whiteGreen := NumGet(whiteSnapshot.Pixels, offset + 1, "UChar")
        whiteRed := NumGet(whiteSnapshot.Pixels, offset + 2, "UChar")
        inverseAlpha := Round((Max(0, whiteBlue - blackBlue)
            + Max(0, whiteGreen - blackGreen)
            + Max(0, whiteRed - blackRed)) / 3)
        alpha := Max(0, Min(255, 255 - inverseAlpha))
        if alpha <= 3
            continue
        if alpha >= 252
            alpha := 255
        NumPut("UChar", Min(alpha, blackBlue), recoveredPixels, offset)
        NumPut("UChar", Min(alpha, blackGreen), recoveredPixels, offset + 1)
        NumPut("UChar", Min(alpha, blackRed), recoveredPixels, offset + 2)
        NumPut("UChar", alpha, recoveredPixels, offset + 3)
    }
    return {Width: width, Height: height, Pixels: recoveredPixels}
}

CreateShellSvgPaddedIcon(filePath, iconSize, cellSize) {
    try {
        if FileGetSize(filePath) > 16 * 1024 * 1024
            return 0
        svgText := FileRead(filePath, "UTF-8")
    } catch {
        return 0
    }
    ; 派生图像使用不透明黑白底渲染。两次结果的通道差可恢复原始
    ; Alpha，避免 Shell 对透明 SVG 叠加随位置变化的深色主题底纹。
    blackVariant := CreateSvgBackdropVariant(svgText, "000000")
    whiteVariant := CreateSvgBackdropVariant(svgText, "FFFFFF")
    if blackVariant == "" || whiteVariant == ""
        return 0
    uniqueSuffix := DllCall("kernel32\GetCurrentProcessId", "UInt") "-"
        . A_TickCount "-" Random(100000, 999999)
    blackPath := A_Temp "\watchdog-svg-black-" uniqueSuffix ".svg"
    whitePath := A_Temp "\watchdog-svg-white-" uniqueSuffix ".svg"
    try {
        FileAppend(blackVariant, blackPath, "UTF-8-RAW")
        FileAppend(whiteVariant, whitePath, "UTF-8-RAW")
        preferredSize := Max(128, Min(256, iconSize * 4))
        blackSnapshot := GetShellThumbnailPixelSnapshot(blackPath,
            preferredSize)
        whiteSnapshot := GetShellThumbnailPixelSnapshot(whitePath,
            preferredSize)
        recoveredSnapshot := RecoverSvgPixelsFromBackdrops(blackSnapshot,
            whiteSnapshot)
        if !recoveredSnapshot
            return 0
        return CreatePixelSnapshotPaddedIcon(recoveredSnapshot, iconSize,
            cellSize, GetSvgIntrinsicAspectRatio(filePath))
    } finally {
        try FileDelete(blackPath)
        try FileDelete(whitePath)
    }
}

CreateSvgPaddedIcon(filePath, iconSize, cellSize, useStatusQuality := false) {
    ; 状态图标使用更高的超采样倍率后再由 WIC Fant 缩小，可显著改善
    ; 小尺寸圆弧和斜边；普通自定义 SVG 保持原开销，避免大量导入时变慢。
    renderSize := useStatusQuality
        ? Max(256, Min(512, iconSize * 8))
        : Max(128, Min(256, iconSize * 4))
    snapshot := App.svgRenderer.RenderFile(filePath,
        App.iconResources.MainDpi, renderSize)
    if snapshot {
        renderedIcon := CreatePixelSnapshotPaddedIcon(snapshot,
            iconSize, cellSize)
        if renderedIcon
            return renderedIcon
    }
    ; DLL 缺失、加载失败或 SVG 无法解析时，仍允许系统缩略图处理器
    ; 提供后备结果；该路径不会启动浏览器或写入中间 PNG。
    return CreateShellSvgPaddedIcon(filePath, iconSize, cellSize)
}

CreateAnimatedCursorPaddedIcon(filePath, iconSize, cellSize) {
    cursorHandle := 0
    paddedIcon := 0
    try {
        sourceSize := SelectClosestIconSourceSize(iconSize)
        cursorHandle := DllCall("user32\LoadImageW", "Ptr", 0,
            "WStr", filePath, "UInt", Win32.IMAGE_CURSOR,
            "Int", sourceSize, "Int", sourceSize,
            "UInt", Win32.LR_LOADFROMFILE, "Ptr")
        if !cursorHandle
            cursorHandle := DllCall("user32\LoadCursorFromFileW",
                "WStr", filePath, "Ptr")
        if !cursorHandle
            return 0
        paddedIcon := CreateHighQualityPaddedIcon(cursorHandle,
            iconSize, cellSize)
        if !paddedIcon
            paddedIcon := CreateMaskPaddedIcon(cursorHandle,
                iconSize, cellSize)
        return paddedIcon
    } finally {
        if cursorHandle
            try DllCall("user32\DestroyCursor", "Ptr", cursorHandle)
    }
}

CreateCustomImagePaddedIcon(filePath, iconSize, cellSize) {
    filePath := ParseCustomIconSource(filePath).Path
    extension := GetCustomIconSourceExtension(filePath)
    if extension == "ani"
        return CreateAnimatedCursorPaddedIcon(filePath, iconSize, cellSize)
    if extension == "svg"
        return CreateSvgPaddedIcon(filePath, iconSize, cellSize)
    if IsRasterImageIconExtension(extension) {
        paddedIcon := CreateWicDecodedPaddedIcon(filePath,
            iconSize, cellSize, extension == "bmp")
        if paddedIcon
            return paddedIcon
        ; WebP 等格式依赖系统安装的 WIC 编解码器；Explorer 能生成真实
        ; 缩略图时仍可作为后备，但绝不回退为普通文件类型图标。
        return CreateShellThumbnailPaddedIcon(filePath, iconSize, cellSize)
    }
    return 0
}

ReleaseIconComObject(pointer) {
    if !pointer
        return
    vtable := NumGet(pointer, 0, "Ptr")
    release := NumGet(vtable, 2 * A_PtrSize, "Ptr")
    DllCall(release, "Ptr", pointer, "UInt")
}

ShutdownIconResampler(*) {
    factory := App.iconResources.TakeResamplerFactory()
    if !factory
        return
    try ReleaseIconComObject(factory)
}

CreateIconMaskFromAlpha(screenDC, colorBits, width, height) {
    maskStride := Floor((width + 31) / 32) * 4
    bitmapInfo := Buffer(48, 0)
    NumPut("UInt", 40, bitmapInfo, 0)
    NumPut("Int", width, bitmapInfo, 4)
    NumPut("Int", -height, bitmapInfo, 8)
    NumPut("UShort", 1, bitmapInfo, 12)
    NumPut("UShort", 1, bitmapInfo, 14)
    NumPut("UInt", 0x00000000, bitmapInfo, 40)
    NumPut("UInt", 0x00FFFFFF, bitmapInfo, 44)
    maskBits := 0
    maskBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
        "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &maskBits,
        "Ptr", 0, "UInt", 0, "Ptr")
    if !maskBitmap
        return 0
    if !maskBits {
        DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
        return 0
    }

    Loop maskStride * height
        NumPut("UChar", 0xFF, maskBits, A_Index - 1)
    Loop height {
        y := A_Index - 1
        Loop width {
            x := A_Index - 1
            alpha := NumGet(colorBits, (y * width + x) * 4 + 3, "UChar")
            if alpha > 8 {
                byteOffset := y * maskStride + (x >> 3)
                bitMask := 0x80 >> (x & 7)
                value := NumGet(maskBits, byteOffset, "UChar")
                NumPut("UChar", value & ~bitMask, maskBits, byteOffset)
            }
        }
    }
    return maskBitmap
}

StatusIconResourceFiles() {
    static resourceFiles := Map(
        "Running", "running.svg",
        "Paused", "paused.svg",
        "Warning", "warning.svg",
        "SuspectedStop", "suspected-stop.svg",
        "Error", "error.svg",
        "Pending", "pending.svg",
        "Countdown", "countdown.svg",
        "Updating", "updating.svg",
        "Idle", "idle.svg"
    )
    return resourceFiles
}

GetStatusIconResourcePath(statusKind) {
    resourceFiles := StatusIconResourceFiles()
    if !resourceFiles.Has(statusKind)
        return ""
    resourceName := resourceFiles[statusKind]
    ; A_LineFile 在主脚本被测试入口 Include 时会指向测试脚本，不能作为
    ; 资源根目录。依次覆盖正式运行、子目录入口和 tests\core 入口。
    for relativeRoot in ["", "\..", "\..\.."] {
        candidatePath := A_ScriptDir relativeRoot
            . "\assets\status-icons\" resourceName
        if FileExist(candidatePath)
            return candidatePath
    }
    return A_ScriptDir "\assets\status-icons\" resourceName
}

CreateStatusResourceIcon(statusKind, glyphSize, cellSize) {
    resourcePath := GetStatusIconResourcePath(statusKind)
    if resourcePath == "" || !FileExist(resourcePath)
        return 0
    ; 状态图标全部来自随项目分发的 SVG 资源。CreateSvgPaddedIcon 只负责
    ; 使用 resvg/WIC 解码、缩放和居中，不再在运行时计算任何图标几何。
    return CreateSvgPaddedIcon(resourcePath, glyphSize, cellSize, true)
}

StatusIconVisualScale(statusKind) {
    ; 相同最大边长下，圆形、八边形和三角形的视觉面积明显小于方形。
    ; 这里仅补偿外部容器的视觉尺寸；SVG 内部仍独立保留语义符号的安全边距。
    static visualScales := Map(
        "Running", 1.00,
        "Paused", 1.10,
        "Warning", 1.10,
        "SuspectedStop", 1.16,
        "Error", 1.10,
        "Pending", 1.10,
        "Countdown", 1.10,
        "Updating", 1.10,
        "Idle", 1.10)
    return visualScales.Has(statusKind) ? visualScales[statusKind] : 1.00
}

AddMainStatusIcons(imageList, statusIconIndices) {
    statusIconIndices.Clear()
    iconResources := App.iconResources
    glyphSize := Max(16, Round(20 * iconResources.MainDpi / 96))
    for statusKind, resourceFile in StatusIconResourceFiles() {
        visualSize := Min(iconResources.MainIconCellPixelSize - 2,
            Round(glyphSize * StatusIconVisualScale(statusKind)))
        statusIcon := CreateStatusResourceIcon(statusKind, visualSize,
            iconResources.MainIconCellPixelSize)
        try iconIndex := statusIcon
                ? IL_Add(imageList, "HICON:" statusIcon)
                : 0
        finally {
            if statusIcon
                try DllCall("user32\DestroyIcon", "Ptr", statusIcon)
        }
        statusIconIndices[statusKind] := iconIndex
    }
}

CreateHighQualityPaddedIcon(hIcon, iconSize, cellSize) {
    if !hIcon || !EnsureIconResampler()
        return 0
    resamplerFactory := App.iconResources.GetResamplerFactory()
    if !resamplerFactory
        return 0

    iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
    if !DllCall("user32\GetIconInfo", "Ptr", hIcon, "Ptr", iconInfo)
        return 0
    bitmapOffset := A_PtrSize == 8 ? 16 : 12
    sourceMaskBitmap := NumGet(iconInfo, bitmapOffset, "Ptr")
    sourceColorBitmap := NumGet(iconInfo, bitmapOffset + A_PtrSize, "Ptr")
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    wicSource := 0
    wicScaler := 0
    targetColorBitmap := 0
    targetMaskBitmap := 0
    try {
        if !sourceColorBitmap || !screenDC
            return 0
        bitmapObject := Buffer(A_PtrSize == 8 ? 32 : 24, 0)
        if !DllCall("gdi32\GetObjectW", "Ptr", sourceColorBitmap,
            "Int", bitmapObject.Size, "Ptr", bitmapObject)
            return 0
        sourceWidth := NumGet(bitmapObject, 4, "Int")
        sourceHeight := Abs(NumGet(bitmapObject, 8, "Int"))
        if sourceWidth <= 0 || sourceHeight <= 0
            return 0

        sourceInfo := Buffer(40, 0)
        NumPut("UInt", 40, sourceInfo, 0)
        NumPut("Int", sourceWidth, sourceInfo, 4)
        NumPut("Int", -sourceHeight, sourceInfo, 8)
        NumPut("UShort", 1, sourceInfo, 12)
        NumPut("UShort", 32, sourceInfo, 14)
        sourcePixels := Buffer(sourceWidth * sourceHeight * 4, 0)
        if !DllCall("gdi32\GetDIBits", "Ptr", screenDC,
            "Ptr", sourceColorBitmap, "UInt", 0, "UInt", sourceHeight,
            "Ptr", sourcePixels, "Ptr", sourceInfo, "UInt", 0)
            return 0
        hasAlphaChannel := false
        Loop sourceWidth * sourceHeight {
            if NumGet(sourcePixels, (A_Index - 1) * 4 + 3, "UChar") {
                hasAlphaChannel := true
                break
            }
        }
        ; 旧式图标只用 AND mask，没有有效 Alpha；交给 mask 路径，避免透明或黑底。
        if !hasAlphaChannel
            return 0
        sourcePixelFormat := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString",
            "WStr", "{6FDDC324-4E03-4BFE-B185-3D77768DC910}",
            "Ptr", sourcePixelFormat, "Int") < 0
            return 0
        factoryVtable := NumGet(resamplerFactory, 0, "Ptr")
        createFromMemory := NumGet(factoryVtable, 20 * A_PtrSize, "Ptr")
        if DllCall(createFromMemory, "Ptr", resamplerFactory,
            "UInt", sourceWidth, "UInt", sourceHeight, "Ptr", sourcePixelFormat,
            "UInt", sourceWidth * 4, "UInt", sourcePixels.Size,
            "Ptr", sourcePixels, "Ptr*", &wicSource, "Int") < 0
            return 0
        createScaler := NumGet(factoryVtable, 11 * A_PtrSize, "Ptr")
        if DllCall(createScaler, "Ptr", resamplerFactory,
            "Ptr*", &wicScaler, "Int") < 0 || !wicScaler
            return 0
        scalerVtable := NumGet(wicScaler, 0, "Ptr")
        initializeScaler := NumGet(scalerVtable, 8 * A_PtrSize, "Ptr")
        scaledWidth := iconSize
        scaledHeight := iconSize
        if DllCall(initializeScaler, "Ptr", wicScaler, "Ptr", wicSource,
            "UInt", scaledWidth, "UInt", scaledHeight, "Int", 3, "Int") < 0
            return 0
        scaledPixels := Buffer(scaledWidth * scaledHeight * 4, 0)
        copyPixels := NumGet(scalerVtable, 7 * A_PtrSize, "Ptr")
        if DllCall(copyPixels, "Ptr", wicScaler, "Ptr", 0,
            "UInt", scaledWidth * 4, "UInt", scaledPixels.Size,
            "Ptr", scaledPixels, "Int") < 0
            return 0

        targetInfo := Buffer(40, 0)
        NumPut("UInt", 40, targetInfo, 0)
        NumPut("Int", cellSize, targetInfo, 4)
        NumPut("Int", -cellSize, targetInfo, 8)
        NumPut("UShort", 1, targetInfo, 12)
        NumPut("UShort", 32, targetInfo, 14)
        targetBits := 0
        targetColorBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
            "Ptr", targetInfo, "UInt", 0, "Ptr*", &targetBits,
            "Ptr", 0, "UInt", 0, "Ptr")
        if !targetColorBitmap || !targetBits
            return 0
        offsetX := Floor((cellSize - scaledWidth) / 2)
        offsetY := Floor((cellSize - scaledHeight) / 2)
        Loop scaledHeight {
            row := A_Index - 1
            destination := targetBits
                + ((offsetY + row) * cellSize + offsetX) * 4
            source := scaledPixels.Ptr + row * scaledWidth * 4
            DllCall("ntdll\RtlMoveMemory", "Ptr", destination,
                "Ptr", source, "UPtr", scaledWidth * 4)
        }
        targetMaskBitmap := CreateIconMaskFromAlpha(screenDC,
            targetBits, cellSize, cellSize)
        if !targetMaskBitmap
            return 0

        outputInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        NumPut("Int", 1, outputInfo, 0)
        NumPut("Ptr", targetMaskBitmap, outputInfo, bitmapOffset)
        NumPut("Ptr", targetColorBitmap, outputInfo, bitmapOffset + A_PtrSize)
        return DllCall("user32\CreateIconIndirect", "Ptr", outputInfo, "Ptr")
    } finally {
        try ReleaseIconComObject(wicScaler)
        try ReleaseIconComObject(wicSource)
        if targetMaskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", targetMaskBitmap)
        if targetColorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", targetColorBitmap)
        if sourceMaskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", sourceMaskBitmap)
        if sourceColorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", sourceColorBitmap)
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

CreateMaskPaddedIcon(hIcon, iconSize, cellSize) {
    if !hIcon || iconSize <= 0 || cellSize < iconSize
        return 0
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    colorDC := 0
    maskDC := 0
    colorBitmap := 0
    maskBitmap := 0
    previousColorBitmap := 0
    previousMaskBitmap := 0
    try {
        colorDC := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDC, "Ptr")
        maskDC := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDC, "Ptr")
        bitmapInfo := Buffer(40, 0)
        NumPut("UInt", 40, bitmapInfo, 0)
        NumPut("Int", cellSize, bitmapInfo, 4)
        NumPut("Int", -cellSize, bitmapInfo, 8)
        NumPut("UShort", 1, bitmapInfo, 12)
        NumPut("UShort", 32, bitmapInfo, 14)
        bits := 0
        colorBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
            "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &bits,
            "Ptr", 0, "UInt", 0, "Ptr")
        maskBitmap := DllCall("gdi32\CreateBitmap", "Int", cellSize,
            "Int", cellSize, "UInt", 1, "UInt", 1, "Ptr", 0, "Ptr")
        if !colorDC || !maskDC || !colorBitmap || !maskBitmap || !bits
            return 0
        previousColorBitmap := DllCall("gdi32\SelectObject", "Ptr", colorDC,
            "Ptr", colorBitmap, "Ptr")
        previousMaskBitmap := DllCall("gdi32\SelectObject", "Ptr", maskDC,
            "Ptr", maskBitmap, "Ptr")
        DllCall("ntdll\RtlZeroMemory", "Ptr", bits,
            "UPtr", cellSize * cellSize * 4)
        DllCall("gdi32\PatBlt", "Ptr", maskDC, "Int", 0, "Int", 0,
            "Int", cellSize, "Int", cellSize, "UInt", 0x00FF0062)
        offset := Floor((cellSize - iconSize) / 2)
        DllCall("user32\DrawIconEx", "Ptr", colorDC, "Int", offset,
            "Int", offset, "Ptr", hIcon, "Int", iconSize, "Int", iconSize,
            "UInt", 0, "Ptr", 0, "UInt", 0x0003)
        DllCall("user32\DrawIconEx", "Ptr", maskDC, "Int", offset,
            "Int", offset, "Ptr", hIcon, "Int", iconSize, "Int", iconSize,
            "UInt", 0, "Ptr", 0, "UInt", 0x0001)
        iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        NumPut("Int", 1, iconInfo, 0)
        bitmapOffset := A_PtrSize == 8 ? 16 : 12
        NumPut("Ptr", maskBitmap, iconInfo, bitmapOffset)
        NumPut("Ptr", colorBitmap, iconInfo, bitmapOffset + A_PtrSize)
        return DllCall("user32\CreateIconIndirect", "Ptr", iconInfo, "Ptr")
    } finally {
        if previousColorBitmap && previousColorBitmap != -1
            try DllCall("gdi32\SelectObject", "Ptr", colorDC,
                "Ptr", previousColorBitmap)
        if previousMaskBitmap && previousMaskBitmap != -1
            try DllCall("gdi32\SelectObject", "Ptr", maskDC,
                "Ptr", previousMaskBitmap)
        if colorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", colorBitmap)
        if maskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
        if colorDC
            try DllCall("gdi32\DeleteDC", "Ptr", colorDC)
        if maskDC
            try DllCall("gdi32\DeleteDC", "Ptr", maskDC)
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

AddIconToImageList(imageList, hIcon, useHighQualityResampling := false) {
    if !hIcon
        return 0
    paddedIcon := 0
    if imageList == Main.appIcons {
        iconResources := App.iconResources
        if useHighQualityResampling
            try paddedIcon := CreateHighQualityPaddedIcon(hIcon,
                iconResources.MainIconPixelSize,
                iconResources.MainIconCellPixelSize)
        if !paddedIcon
            paddedIcon := CreateMaskPaddedIcon(hIcon,
                iconResources.MainIconPixelSize,
                iconResources.MainIconCellPixelSize)
    }
    iconToAdd := paddedIcon ? paddedIcon : hIcon
    try return IL_Add(imageList, "HICON:" iconToAdd)
    finally {
        if paddedIcon
            try DllCall("user32\DestroyIcon", "Ptr", paddedIcon)
    }
}

FormatMainListLabel(name, isAdmin := false) {
    ; NBSP 不参与中西文断行规则，可稳定补充少量图文间距且保持名称左侧对齐。
    return Chr(0x00A0) name . (isAdmin ? " 🛡️" : "")
}

GetDefaultMainDisplayName(path) {
    SplitPath(path, , , , &nameNoExt)
    return nameNoExt != "" ? nameNoExt : path
}

GetMainDisplayName(path, stateObj := "") {
    if stateObj && stateObj.HasOwnProp("DisplayConfig") {
        displayName := Trim(stateObj.DisplayConfig.Name)
        if (displayName != "")
            return displayName
    }
    return GetDefaultMainDisplayName(path)
}

GetMainDisplayIconSource(path, stateObj := "") {
    if stateObj && stateObj.HasOwnProp("DisplayConfig") {
        iconPath := stateObj.DisplayConfig.IconPath
        if (iconPath != "" && CustomIconSourceExists(iconPath))
            return iconPath
    }
    return path
}

AcquireMainImageListUse(imageList) {
    return App.iconResources.AcquireMainImageList(imageList,
        Main.appIcons)
}

ReleaseMainImageListUse(imageList) {
    if App.iconResources.ReleaseMainImageList(imageList) {
        ClearImageListIconCache(imageList)
        try IL_Destroy(imageList)
    }
}

RetireMainImageList(imageList) {
    if App.iconResources.RetireMainImageList(imageList, Main.appIcons) {
        ClearImageListIconCache(imageList)
        try IL_Destroy(imageList)
    }
}

IsMainImageListTracked(imageList) {
    return App.iconResources.IsMainImageListTracked(imageList,
        Main.appIcons)
}

GetMainListIconIndex(path, stateObj, imageList) {
    imageList := AcquireMainImageListUse(imageList)
    if !imageList
        return 0
    try return GetFileIconIndex(GetMainDisplayIconSource(path, stateObj),
        imageList)
    finally ReleaseMainImageListUse(imageList)
}

RefreshMainListDisplay(path) {
    if !App.appStates.Has(path)
        return false
    row := FindRow(path)
    if !row
        return false
    stateObj := App.appStates[path]
    Main.lv.Modify(row, "Col1", FormatMainListLabel(
        GetMainDisplayName(path, stateObj), stateObj.RunAsAdmin))
    iconIndex := GetMainListIconIndex(path, stateObj, Main.lv.IL)
    if iconIndex
        Main.lv.Modify(row, "Icon" iconIndex)
    return true
}

NormalizeUserVisibleParentheses(text) {
    ; 中文界面不保留“空格 + 半角括号”的英文排版痕迹。
    return RegExReplace(String(text), "\h+\(([^()\r\n]*)\)", "（$1）")
}

FormatMainStatusLabel(statusText) {
    ; 原生 ListView 会把 Emoji 回退为单色字形，状态色改由真彩图标槽呈现。
    label := RegExReplace(statusText,
        "^(?:✅|❌|⚠|⏸|⏳|🔄|🚀)\x{FE0F}?\h*", "")
    return NormalizeUserVisibleParentheses(label)
}

GetMainStatusVisualKind(statusText) {
    label := FormatMainStatusLabel(statusText)
    if InStr(label, "不存在") || InStr(label, "失败")
        || InStr(label, "无法停止")
        return "Error"
    if InStr(label, "疑似停止")
        return "SuspectedStop"
    if InStr(label, "倒计时")
        return "Countdown"
    if InStr(label, "超时") || InStr(label, "权限不符")
        || InStr(label, "已停止")
        return "Warning"
    if InStr(label, "暂停")
        return "Paused"
    if InStr(label, "运行中") || InStr(label, "已启动")
        return "Running"
    if InStr(label, "升级") || InStr(label, "程序文件")
        return "Updating"
    if InStr(label, "初始化")
        return "Idle"
    return "Pending"
}

SetMainListSubItemIcon(row, iconIndex) {
    if (row < 1 || !Main.lv)
        return false
    listItem := Buffer(A_PtrSize == 8 ? 88 : 60, 0)
    NumPut("UInt", Win32.LVIF_IMAGE, listItem, 0)
    NumPut("Int", row - 1, listItem, 4)
    NumPut("Int", 1, listItem, 8) ; 状态列的零基子项索引
    NumPut("Int", iconIndex > 0 ? iconIndex - 1 : -1,
        listItem, A_PtrSize == 8 ? 36 : 28)
    return SendMessage(Win32.LVM_SETITEMW, 0,
        listItem.Ptr, Main.lv.Hwnd) != 0
}

SetMainListStatus(row, statusText) {
    if (row < 1 || row > Main.lv.GetCount())
        return
    Main.lv.Modify(row, "Col2", FormatMainStatusLabel(statusText))
    statusKind := GetMainStatusVisualKind(statusText)
    iconIndex := Main.HasOwnProp("statusIconIndices")
        && Main.statusIconIndices.Has(statusKind)
        ? Main.statusIconIndices[statusKind]
        : 0
    SetMainListSubItemIcon(row, iconIndex)
}

ApplyDarkListViewTheme(hLV) {
    ; 通过 SetWindowTheme 和 AllowDarkModeForWindow 将 ListView 及其滚动条设定为暗黑样式
    if !DllCall("user32\IsWindow", "Ptr", hLV, "Int")
        return
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if (uxtheme) {
                AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                if AllowDarkModeForWindow
                    DllCall(AllowDarkModeForWindow, "Ptr", hLV, "Int", 1)
            }
        }
        try DllCall("uxtheme\SetWindowTheme", "Ptr", hLV, "Str", "DarkMode_Explorer", "Ptr", 0)
        hHeader := SendMessage(0x101F, 0, 0, hLV) ; 获取子组件 header 字段栏
        if (hHeader) {
            try {
                uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
                if (uxtheme) {
                    AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                    if AllowDarkModeForWindow
                        DllCall(AllowDarkModeForWindow, "Ptr", hHeader, "Int", 1)
                }
            }
            try DllCall("uxtheme\SetWindowTheme", "Ptr", hHeader, "Str", "DarkMode_ItemsView", "Ptr", 0)
            try DllCall("user32\InvalidateRect", "Ptr", hHeader, "Ptr", 0, "Int", 1)
        }
    }
    try DllCall("user32\InvalidateRect", "Ptr", hLV, "Ptr", 0, "Int", 1)
}

SetDarkControl(hCtrl) {
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if (uxtheme) {
                AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                if AllowDarkModeForWindow
                    DllCall(AllowDarkModeForWindow, "Ptr", hCtrl, "Int", 1)
            }
        }
        try DllCall("uxtheme\SetWindowTheme", "Ptr", hCtrl, "Str", "DarkMode_Explorer", "Ptr", 0)
    }
}

AddCenteredSingleLineEdit(guiObj, x, y, width, outerHeight, value := "", extraOptions := "", backgroundColor := "252526") {
    innerHeight := Max(18, outerHeight - 6)
    innerY := y + Floor((outerHeight - innerHeight) / 2)
    background := guiObj.Add("Text", "x" x " y" y " w" width " h" outerHeight " Background" backgroundColor)
    editOptions := "x" x " y" innerY " w" width " h" innerHeight " Background" backgroundColor " cWhite -E0x200"
    if extraOptions
        editOptions .= " " extraOptions
    inputEditControl := guiObj.Add("Edit", editOptions, value)
    RegisterTextInputControl(inputEditControl)
    RegisterTextInputHitTarget(background, inputEditControl)
    return {Background: background, Edit: inputEditControl}
}

ShowSingleLineEditFromStart(inputControl) {
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    if !textEditHwnd || !DllCall("user32\IsWindow", "Ptr", textEditHwnd, "Int")
        return
    SendMessage(Win32.EM_SETSEL, 0, 0, textEditHwnd)
    SendMessage(Win32.EM_SCROLLCARET, 0, 0, textEditHwnd)
}

; ==========================================
; 15. 系统资源文件与应用图标抓取解析支持以及资源释放容灾队列
; ==========================================

ClearImageListIconCache(imageList) {
    return App.iconResources.ClearImageListCache(imageList)
}

GetFileIconIndex(filePath, IL_ID) {
    if !IL_ID
        return 0
    iconResources := App.iconResources
    if iconResources.HasCachedIcon(IL_ID, filePath)
        return iconResources.GetCachedIcon(IL_ID, filePath)

    iconSource := ParseCustomIconSource(filePath)
    sourcePath := iconSource.Path

    if IsMainImageListTracked(IL_ID) {
        extension := GetCustomIconSourceExtension(filePath)
        if IsRasterImageIconExtension(extension)
            || extension == "svg" || extension == "ani" {
            customImageIcon := CreateCustomImagePaddedIcon(sourcePath,
                iconResources.MainIconPixelSize,
                iconResources.MainIconCellPixelSize)
            try idx := customImageIcon
                ? IL_Add(IL_ID, "HICON:" customImageIcon) : 0
            finally {
                if customImageIcon
                    try DllCall("user32\DestroyIcon", "Ptr",
                        customImageIcon)
            }
            if idx {
                iconResources.StoreCachedIcon(IL_ID, filePath, idx)
                return idx
            }
        }
        useHighQuality := false
        preferredSource := GetPreferredMainIcon(filePath, &useHighQuality)
        if preferredSource {
            try idx := AddIconToImageList(IL_ID, preferredSource,
                useHighQuality)
            finally DllCall("user32\DestroyIcon", "Ptr", preferredSource)
            if idx {
                iconResources.StoreCachedIcon(IL_ID, filePath, idx)
                return idx
            }
        }
    }

    sfi_size := A_PtrSize + 688
    sfi := Buffer(sfi_size)
    flags := 0x100 ; SHGFI_ICON
    attr := 0
    if !FileExist(sourcePath) {
        flags |= Win32.SHGFI_USEFILEATTRIBUTES
        attr := Win32.FILE_ATTRIBUTE_NORMAL
    }

    if DllCall("shell32\SHGetFileInfoW", "Str", sourcePath, "UInt", attr, "Ptr", sfi, "UInt", sfi_size, "UInt", flags) {
        hIcon := NumGet(sfi, 0, "Ptr")
        if hIcon {
            try idx := AddIconToImageList(IL_ID, hIcon)
            finally DllCall("user32\DestroyIcon", "Ptr", hIcon)
            if idx {
                iconResources.StoreCachedIcon(IL_ID, filePath, idx)
                return idx
            }
        }
    }

    fallbackIconNumber := iconSource.HasIndex && iconSource.Index >= 0
        ? iconSource.Index + 1 : 1
    idx := IL_Add(IL_ID, sourcePath, fallbackIconNumber)
    if idx
        iconResources.StoreCachedIcon(IL_ID, filePath, idx)
    return idx
}

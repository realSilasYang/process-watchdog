; 原生主题适配与主窗口图标渲染管线。
; 图标获取按目标类型选择 Shell、图片解码或 SVG 渲染路径，并把缩放、透明通道、
; 图像列表所有权和 DPI 重建放在同一资源边界内，任何失败都必须回退并释放临时句柄。

/*  * ========================================================================
 * 5. 系统底层原生 UI 接口调用集
 * 通过 DWM 和 UxTheme 等组件，调整界面的明暗主题及原生组件适配。
 * ========================================================================
 */
ApplyNativeWindowTheme(hWnd) {
    ; 修改 DWM 窗口属性并许可窗口采用当前主题。进程级首选模式只由
    ; UiThemeService.Configure 设置，不能在每次创建窗口时用固定值覆盖。
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    dark := UiThemeService.IsDark()
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd,
            "Int", attr, "Int*", dark ? 1 : 0, "Int", 4)
        UiThemeService.AllowDarkModeForWindow(hWnd, dark)
    }
    return true
}

; 所有生产子窗口统一经过此入口映射到屏幕。自动化测试可以保留真实窗口、
; 控件和布局生命周期，同时禁止批量窗口闪现在用户桌面；正常运行不改变 Show
; 的任何选项或时序。
class ApplicationWindowPresenter {
    static AutomationHidden := false

    static SetAutomationHidden(hidden) {
        this.AutomationHidden := !!hidden
    }

    static Show(guiObj, options := "") {
        if !IsObject(guiObj)
            return false
        showOptions := Trim(String(options))
        if this.AutomationHidden
            && !RegExMatch(showOptions, "i)(^|\s)Hide(?:\s|$)")
            showOptions := Trim("Hide " showOptions)
        guiObj.Show(showOptions)
        return true
    }
}

ShowApplicationWindow(guiObj, options := "") {
    return ApplicationWindowPresenter.Show(guiObj, options)
}

InitializeApplicationWindow(guiObj, fontOptions := "s10",
    fontName := "") {
    ; 应用窗口的标题栏、图标、客户区和正文默认字体必须作为一个整体初始化。
    ; 具体窗口仍可在此之后为标题、按钮或特殊正文切换字号与字族。
    if !IsObject(guiObj)
        return false
    try hwnd := guiObj.Hwnd
    catch
        return false
    if !ApplyNativeWindowTheme(hwnd)
        return false
    SetWindowIcon(hwnd, GetApplicationIconPath())
    guiObj.BackColor := UiThemeService.Color("Window")
    if fontName == ""
        fontName := LocalizationService.GetUiFontName()
    guiObj.SetFont(Trim(fontOptions) " c" UiThemeService.Color("Text"),
        fontName)
    return true
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
    iconSizeApplied := false
    try iconSizeApplied := DllCall("comctl32\ImageList_SetIconSize",
        "Ptr", imageList, "Int", iconResources.MainIconCellPixelSize,
        "Int", iconResources.MainIconCellPixelSize, "Int") != 0
    if !iconSizeApplied {
        try IL_Destroy(imageList)
        iconResources.RestoreMainIconMetrics(previousMetrics)
        return 0
    }
    ; 应用图标是主列表的基础能力；状态 SVG 与管理员角标属于增强层。
    ; 单个增强资源异常时保留可用 ImageList，不能让所有应用图标一起消失。
    try AddMainStatusIcons(imageList, statusIconIndices)
    catch {
        statusIconIndices.Clear()
    }
    try AddMainAdminOverlayIcon(imageList)
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
    return GetSystemImageListIcon(systemIconIndex, imageListKind)
}

GetSystemImageListIcon(systemIconIndex, imageListKind) {
    if systemIconIndex < 0
        return 0
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

GetWindowsStockIcon(stockIconId, imageListKind) {
    ; SHGetStockIconInfo 返回当前 Windows 版本自己的库存图标索引；再从
    ; Jumbo／Extra Large 系统图像列表取源，可避免复制或仿制 UAC 资源。
    structureSize := A_PtrSize == 8 ? 544 : 536
    stockInfo := Buffer(structureSize, 0)
    NumPut("UInt", structureSize, stockInfo, 0)
    try result := DllCall("shell32\SHGetStockIconInfo", "Int", stockIconId,
        "UInt", Win32.SHGSI_SYSICONINDEX, "Ptr", stockInfo, "Int")
    catch
        return 0
    if result < 0
        return 0
    indexOffset := A_PtrSize == 8 ? 16 : 8
    return GetSystemImageListIcon(NumGet(stockInfo, indexOffset, "Int"),
        imageListKind)
}

GetWindowsStockIconHandle(stockIconId) {
    ; 极少数精简系统可能没有可用的高分辨率系统图像列表，最后直接请求
    ; Shell 库存 HICON，仍然保持使用 Windows 官方资源而不是自带仿制图。
    structureSize := A_PtrSize == 8 ? 544 : 536
    stockInfo := Buffer(structureSize, 0)
    NumPut("UInt", structureSize, stockInfo, 0)
    try result := DllCall("shell32\SHGetStockIconInfo", "Int", stockIconId,
        "UInt", Win32.SHGSI_ICON, "Ptr", stockInfo, "Int")
    catch
        return 0
    if result < 0
        return 0
    iconOffset := A_PtrSize == 8 ? 8 : 4
    return NumGet(stockInfo, iconOffset, "Ptr")
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
        targetSize := App.iconResources.MainIconPixelSize
        preferredSize := SelectHighQualityMainIconSourceSize(targetSize)
        fallbackSize := SelectClosestIconSourceSize(targetSize)
        sourceSizes := preferredSize == fallbackSize
            ? [preferredSize] : [preferredSize, fallbackSize]
        ; 主列表最终会经过 WIC 高质量缩小。优先请求约两倍尺寸，可避开部分
        ; 程序专为小尺寸准备、但质量反而较差的资源；若高分辨率请求失败，
        ; 再回退到贴近显示尺寸的资源，兼容只提供旧式小图标的程序。
        for sourceSize in sourceSizes {
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

SelectHighQualityMainIconSourceSize(targetSize) {
    return SelectClosestIconSourceSize(Max(targetSize, Ceil(targetSize * 2)))
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

BeginNativeDialogThemePreference() {
    themeState := {Callback: 0, PreviousMode: 0, Changed: false}
    if VerCompare(A_OSVersion, "10.0.18362") < 0
        return themeState
    try {
        setPreferredAppMode := UiThemeService.GetUxThemeFunction(135)
        if !setPreferredAppMode
            return themeState
        ; IFileDialog 在创建时读取进程首选主题。短暂使用 ForceDark 或
        ; ForceLight，可让手动主题设置不受 Windows 系统主题牵制。
        preferredMode := UiThemeService.IsDark() ? 2 : 3
        themeState.PreviousMode := DllCall(setPreferredAppMode,
            "Int", preferredMode, "Int")
        themeState.Callback := setPreferredAppMode
        themeState.Changed := true
    }
    return themeState
}

RestoreNativeDialogThemePreference(themeState) {
    if !IsObject(themeState) || !themeState.Changed
        return
    try DllCall(themeState.Callback, "Int", themeState.PreviousMode, "Int")
}

SelectDirectoryWithModernDialog(ownerHwnd := 0, initialDirectory := "",
    prompt := "") {
    return SelectPathWithModernDialog(ownerHwnd, initialDirectory, prompt,
        0x868)
}

SelectPathWithModernDialog(ownerHwnd, initialPath, prompt, options,
    filterName := "", filterPattern := "") {
    themeState := BeginNativeDialogThemePreference()
    try {
        fileDialog := ComObject(
            "{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}",
            "{D57C7288-D4AD-4768-BE02-9D969532D960}")
        ComCall(9, fileDialog, "UInt", options)
        if filterPattern != "" {
            filterSpec := Buffer(A_PtrSize * 2, 0)
            NumPut("Ptr", StrPtr(filterName), filterSpec, 0)
            NumPut("Ptr", StrPtr(filterPattern), filterSpec, A_PtrSize)
            ComCall(4, fileDialog, "UInt", 1, "Ptr", filterSpec)
        }
        if prompt != ""
            ComCall(17, fileDialog, "Str", prompt)
        ConfigureSingleFileDialogInitialPath(fileDialog, initialPath)
        return ReadSingleFileDialogPath(fileDialog, ownerHwnd)
    } catch {
        return ""
    } finally {
        RestoreNativeDialogThemePreference(themeState)
    }
}

SelectFileWithNamedFilter(ownerHwnd, initialPath, prompt,
    filterName, filterPattern) {
    ; 文件选择器要求使用文件系统路径，并同时校验父路径与目标文件确实存在。
    return SelectPathWithModernDialog(ownerHwnd, initialPath, prompt,
        0x1840, filterName, filterPattern)
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
    pixelHeight, cellSize, offsetX := "", offsetY := "") {
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
        ; 两个方向独立解析：状态图标只覆盖纵向位置时，横向仍保持自动
        ; 居中。旧实现会把空横坐标交给 Integer()，导致整个图标创建失败。
        try {
            offsetX := offsetX == ""
                ? Floor((cellSize - pixelWidth) / 2) : Integer(offsetX)
            offsetY := offsetY == ""
                ? Floor((cellSize - pixelHeight) / 2) : Integer(offsetY)
        } catch {
            return 0
        }
        if offsetX < 0 || offsetY < 0
            || offsetX + pixelWidth > cellSize
            || offsetY + pixelHeight > cellSize
            return 0
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
    iconSize, cellSize, removeLightMatte := false, offsetX := "",
    offsetY := "") {
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
        ; offset 表示 iconSize 布局框在单元格中的左上角。某一方向留空时，
        ; 该方向独立采用默认居中，不能因另一方向显式偏移而退回到左上角。
        try {
            positionedX := (offsetX == ""
                ? Floor((cellSize - iconSize) / 2) : Integer(offsetX))
                + Floor((iconSize - scaledWidth) / 2)
            positionedY := (offsetY == ""
                ? Floor((cellSize - iconSize) / 2) : Integer(offsetY))
                + Floor((iconSize - scaledHeight) / 2)
        } catch {
            return 0
        }
        return CreatePaddedIconFromPremultipliedPixels(scaledPixels,
            scaledWidth, scaledHeight, cellSize, positionedX, positionedY)
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
    desiredAspectRatio := 0, offsetX := "", offsetY := "") {
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
            layoutHeight, iconSize, cellSize, false, offsetX, offsetY)
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

CreateShellSvgPaddedIcon(filePath, iconSize, cellSize, offsetX := "",
    offsetY := "") {
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
            cellSize, GetSvgIntrinsicAspectRatio(filePath), offsetX, offsetY)
    } finally {
        try FileDelete(blackPath)
        try FileDelete(whitePath)
    }
}

CreateSvgPaddedIcon(filePath, iconSize, cellSize, useStatusQuality := false,
    offsetX := "", offsetY := "") {
    ; 状态图标使用更高的超采样倍率后再由 WIC Fant 缩小，可显著改善
    ; 小尺寸圆弧和斜边；普通自定义 SVG 保持原开销，避免大量导入时变慢。
    renderSize := useStatusQuality
        ? Max(256, Min(512, iconSize * 8))
        : Max(128, Min(256, iconSize * 4))
    snapshot := App.svgRenderer.RenderFile(filePath,
        App.iconResources.MainDpi, renderSize)
    if snapshot {
        renderedIcon := CreatePixelSnapshotPaddedIcon(snapshot,
            iconSize, cellSize, 0, offsetX, offsetY)
        if renderedIcon
            return renderedIcon
    }
    ; DLL 缺失、加载失败或 SVG 无法解析时，仍允许系统缩略图处理器
    ; 提供后备结果；该路径不会启动浏览器或写入中间 PNG。
    return CreateShellSvgPaddedIcon(filePath, iconSize, cellSize,
        offsetX, offsetY)
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
        GuardStatusKind.Initializing, "loader-circle.svg",
        GuardStatusKind.Running, "circle-check-big.svg",
        GuardStatusKind.PermissionMismatch, "shield-alert.svg",
        GuardStatusKind.Paused, "circle-pause.svg",
        GuardStatusKind.SuspectedStop, "triangle-alert-red.svg",
        GuardStatusKind.WaitingObservation, "timer.svg",
        GuardStatusKind.StartCountdown, "timer.svg",
        GuardStatusKind.RetryCountdown, "timer.svg",
        GuardStatusKind.CoolingDown, "timer.svg",
        GuardStatusKind.Starting, "rocket.svg",
        GuardStatusKind.Verifying, "scan-search.svg",
        GuardStatusKind.TargetMissing, "circle-x.svg",
        GuardStatusKind.ProgramMissing, "file-x-2.svg",
        GuardStatusKind.ScriptMissing, "file-code-2.svg",
        GuardStatusKind.SafeStartWait, "shield-ellipsis.svg",
        GuardStatusKind.LaunchRetry, "rotate-ccw.svg",
        GuardStatusKind.MaintenanceArbitrating,
            "scan-search.svg",
        GuardStatusKind.MaintenanceUpdating, "refresh-cw.svg",
        GuardStatusKind.MaintenanceFileWaiting, "file-clock.svg",
        GuardStatusKind.MaintenanceStabilizing,
            "file-clock.svg",
        GuardStatusKind.MaintenanceRecovering, "timer.svg",
        GuardStatusKind.MaintenanceTimedOut, "triangle-alert-timeout.svg",
        GuardStatusKind.Unknown, "circle-info-unknown.svg"
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
            . "\assets\ui-icons\lucide\" resourceName
        if FileExist(candidatePath)
            return candidatePath
    }
    return A_ScriptDir "\assets\ui-icons\lucide\" resourceName
}

CreateStatusResourceIcon(statusKind, glyphSize, cellSize, offsetY := "") {
    resourcePath := GetStatusIconResourcePath(statusKind)
    if resourcePath == "" || !FileExist(resourcePath)
        return 0
    ; 状态图标全部来自随项目分发的 SVG 资源。CreateSvgPaddedIcon 只负责
    ; 使用 resvg/WIC 解码、缩放和居中，不再在运行时计算任何图标几何。
    return CreateSvgPaddedIcon(resourcePath, glyphSize, cellSize, true,
        "", offsetY)
}

StatusIconVisualScale(statusKind) {
    ; SVG 均使用相同 24×24 Lucide 视口和 2px 描边；只有用户认知中属于
    ; 同一过程的等待、文件就绪和查询状态共享图形，其余状态保持独立语义。
    return 1.00
}

GetMainStatusIconVerticalOffset(iconResources) {
    try {
        textCenterDelta := TextVisualAlignment.MeasureFontInkCenterDelta(
            LocalizationService.GetUiFontName(), 12, 400,
            iconResources.MainDpi,
            Trim(StrReplace(Tr("✅ 运行中"), "✅", "")))
        return Round(textCenterDelta)
    } catch {
        ; 字体度量是视觉增强，不得阻断主图像列表创建。
        return 0
    }
}

AddMainStatusIcons(imageList, statusIconIndices) {
    statusIconIndices.Clear()
    iconResources := App.iconResources
    glyphSize := Max(16, Round(20 * iconResources.MainDpi / 96))
    centerY := Floor((iconResources.MainIconCellPixelSize - glyphSize) / 2)
    verticalOffset := GetMainStatusIconVerticalOffset(iconResources)
    ; ListView 原生文字仍按字体行框布局。把状态 SVG 在透明图标槽内移动到
    ; 可见字形的中心，可在不接管选择、截断和键盘语义的前提下保持图文同轴。
    statusIconY := Max(0, Min(
        iconResources.MainIconCellPixelSize - glyphSize,
        centerY + verticalOffset))
    iconIndexByResource := Map()
    iconIndexByResource.CaseSense := "Off"
    for statusKind, resourceFile in StatusIconResourceFiles() {
        if iconIndexByResource.Has(resourceFile) {
            statusIconIndices[statusKind] :=
                iconIndexByResource[resourceFile]
            continue
        }
        visualSize := Min(iconResources.MainIconCellPixelSize - 2,
            Round(glyphSize * StatusIconVisualScale(statusKind)))
        visualCenterY := Floor(
            (iconResources.MainIconCellPixelSize - visualSize) / 2)
        visualOffsetY := Max(0, Min(
            iconResources.MainIconCellPixelSize - visualSize,
            visualCenterY + (statusIconY - centerY)))
        statusIcon := CreateStatusResourceIcon(statusKind, visualSize,
            iconResources.MainIconCellPixelSize, visualOffsetY)
        if !statusIcon
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
        iconIndexByResource[resourceFile] := iconIndex
    }
}

RefreshMainStatusIconAlignment() {
    if !Main.HasOwnProp("appIcons") || !Main.appIcons
        || !Main.HasOwnProp("statusIconIndices")
        || !IsObject(Main.statusIconIndices)
        return false
    imageList := AcquireMainImageListUse(Main.appIcons)
    if !imageList
        return false
    iconResources := App.iconResources
    glyphSize := Max(16, Round(20 * iconResources.MainDpi / 96))
    verticalOffset := GetMainStatusIconVerticalOffset(iconResources)
    replacedIndices := Map()
    succeeded := true
    redrawSuspended := false
    try {
        if Main.HasOwnProp("lv") && Main.lv {
            Main.lv.Opt("-Redraw")
            redrawSuspended := true
        }
        for statusKind, resourceFile in StatusIconResourceFiles() {
            if !Main.statusIconIndices.Has(statusKind)
                continue
            iconIndex := Main.statusIconIndices[statusKind]
            if iconIndex <= 0 || replacedIndices.Has(iconIndex)
                continue
            visualSize := Min(iconResources.MainIconCellPixelSize - 2,
                Round(glyphSize * StatusIconVisualScale(statusKind)))
            visualCenterY := Floor(
                (iconResources.MainIconCellPixelSize - visualSize) / 2)
            visualOffsetY := Max(0, Min(
                iconResources.MainIconCellPixelSize - visualSize,
                visualCenterY + verticalOffset))
            statusIcon := CreateStatusResourceIcon(statusKind, visualSize,
                iconResources.MainIconCellPixelSize, visualOffsetY)
            if !statusIcon {
                succeeded := false
                continue
            }
            try {
                replacedIndex := DllCall("comctl32\ImageList_ReplaceIcon",
                    "Ptr", imageList, "Int", iconIndex - 1,
                    "Ptr", statusIcon, "Int")
                if replacedIndex != iconIndex - 1
                    succeeded := false
                else
                    replacedIndices[iconIndex] := true
            } finally DllCall("user32\DestroyIcon", "Ptr", statusIcon)
        }
        if Main.HasOwnProp("lv") && Main.lv {
            attachedImageList := SendMessage(Win32.LVM_GETIMAGELIST,
                1, 0, Main.lv.Hwnd)
            if attachedImageList != imageList {
                Main.lv.SetImageList(imageList, 1)
                Main.lv.IL := imageList
            }
        }
        return succeeded
    } finally {
        if redrawSuspended
            Main.lv.Opt("+Redraw")
        ReleaseMainImageListUse(imageList)
    }
}

AddMainAdminOverlayIcon(imageList) {
    if !imageList
        return false
    iconResources := App.iconResources
    badgeSize := Max(12, Round(14 * iconResources.MainDpi / 96))
    badgeMargin := Max(1, Round(iconResources.MainDpi / 96))
    cellSize := iconResources.MainIconCellPixelSize
    badgeOffset := cellSize - badgeSize - badgeMargin
    sourceIcon := GetWindowsStockIcon(Win32.SIID_SHIELD, Win32.SHIL_JUMBO)
    if !sourceIcon
        sourceIcon := GetWindowsStockIcon(Win32.SIID_SHIELD,
            Win32.SHIL_EXTRALARGE)
    if !sourceIcon
        sourceIcon := GetWindowsStockIconHandle(Win32.SIID_SHIELD)
    if !sourceIcon
        return false
    badgeIcon := 0
    try {
        badgeIcon := CreateHighQualityPaddedIcon(sourceIcon, badgeSize,
            cellSize, badgeOffset, badgeOffset)
        if !badgeIcon
            badgeIcon := CreateMaskPaddedIcon(sourceIcon, badgeSize,
                cellSize, badgeOffset, badgeOffset)
    } finally {
        DllCall("user32\DestroyIcon", "Ptr", sourceIcon)
    }
    if !badgeIcon
        return false
    try badgeIndex := IL_Add(imageList, "HICON:" badgeIcon)
    finally DllCall("user32\DestroyIcon", "Ptr", badgeIcon)
    if !badgeIndex
        return false
    ; 图像列表索引从 0 开始，AHK 的 IL_Add 返回值从 1 开始。overlay 槽 1
    ; 由每一行的 LVIS_OVERLAYMASK 独立启停，不会污染普通项目图标。
    return DllCall("comctl32\ImageList_SetOverlayImage", "Ptr", imageList,
        "Int", badgeIndex - 1, "Int", 1, "Int") != 0
}

CreateHighQualityPaddedIcon(hIcon, iconSize, cellSize, offsetX := "",
    offsetY := "") {
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
        if offsetX == "" && offsetY == "" {
            offsetX := Floor((cellSize - scaledWidth) / 2)
            offsetY := Floor((cellSize - scaledHeight) / 2)
        } else {
            try {
                offsetX := Integer(offsetX)
                offsetY := Integer(offsetY)
            } catch {
                return 0
            }
            if offsetX < 0 || offsetY < 0
                || offsetX + scaledWidth > cellSize
                || offsetY + scaledHeight > cellSize
                return 0
        }
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

CreateMaskPaddedIcon(hIcon, iconSize, cellSize, offsetX := "",
    offsetY := "") {
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
        if offsetX == "" && offsetY == "" {
            offsetX := Floor((cellSize - iconSize) / 2)
            offsetY := Floor((cellSize - iconSize) / 2)
        } else {
            try {
                offsetX := Integer(offsetX)
                offsetY := Integer(offsetY)
            } catch {
                return 0
            }
            if offsetX < 0 || offsetY < 0
                || offsetX + iconSize > cellSize
                || offsetY + iconSize > cellSize
                return 0
        }
        DllCall("user32\DrawIconEx", "Ptr", colorDC, "Int", offsetX,
            "Int", offsetY, "Ptr", hIcon, "Int", iconSize, "Int", iconSize,
            "UInt", 0, "Ptr", 0, "UInt", 0x0003)
        DllCall("user32\DrawIconEx", "Ptr", maskDC, "Int", offsetX,
            "Int", offsetY, "Ptr", hIcon, "Int", iconSize, "Int", iconSize,
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
    ; 管理员状态由应用图标右下角的 Windows 库存 overlay 表示，不再把 Emoji 拼进
    ; 可编辑名称。NBSP 仅负责稳定保留应用图标与名称之间的少量间距。
    return Chr(0x00A0) name
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
    return App.iconResources.AcquireImageList(imageList,
        Main.appIcons)
}

ReleaseMainImageListUse(imageList) {
    if App.iconResources.ReleaseImageList(imageList) {
        ClearImageListIconCache(imageList)
        try IL_Destroy(imageList)
    }
}

RetireMainImageList(imageList) {
    if App.iconResources.RetireImageList(imageList, Main.appIcons) {
        ClearImageListIconCache(imageList)
        try IL_Destroy(imageList)
    }
}

IsMainImageListTracked(imageList) {
    return App.iconResources.IsImageListTracked(imageList,
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

ScheduleMainListNativeSurfaceRefresh(delayMs := 15) {
    if !Main.HasOwnProp("listSelectionPresenter")
        || !IsObject(Main.listSelectionPresenter)
        return false
    return Main.listSelectionPresenter.ScheduleNativeSurfaceRefresh(delayMs)
}

SetMainListAdminOverlay(row, isAdmin) {
    if !Main.lv || row < 1 || row > Main.lv.GetCount()
        return false
    item := Buffer(A_PtrSize == 8 ? 88 : 60, 0)
    NumPut("UInt", Win32.LVIF_STATE, item, 0)
    NumPut("Int", row - 1, item, 4)
    NumPut("UInt", isAdmin ? (1 << 8) : 0, item, 12)
    NumPut("UInt", Win32.LVIS_OVERLAYMASK, item, 16)
    updated := SendMessage(Win32.LVM_SETITEMW, 0, item.Ptr,
        Main.lv.Hwnd) != 0
    if updated
        ScheduleMainListNativeSurfaceRefresh()
    return updated
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
    SetMainListAdminOverlay(row, stateObj.RunAsAdmin)
    iconIndex := GetMainListIconIndex(path, stateObj, Main.lv.IL)
    if iconIndex
        Main.lv.Modify(row, "Icon" iconIndex)
    ScheduleMainListTemporarySortRefresh(1)
    return true
}

NormalizeUserVisibleParentheses(text) {
    ; 中文界面不保留“空格 + 半角括号”的英文排版痕迹。
    text := String(text)
    return LocalizationService.IsChinese()
        ? RegExReplace(text, "\h+\(([^()\r\n]*)\)", "（$1）")
        : text
}

FormatMainStatusLabel(statusText) {
    ; 原生 ListView 会把 Emoji 回退为单色字形，状态色改由真彩图标槽呈现。
    label := RegExReplace(statusText,
        "^(?:✅|❌|⚠|⏸|⏳|🔄|🚀)\x{FE0F}?\h*", "")
    return NormalizeUserVisibleParentheses(label)
}

GetMainStatusVisualKind(stateObj) {
    if !IsObject(stateObj)
        return GuardStatusKind.Unknown
    if !stateObj.Enabled || stateObj.Phase == GuardPhase.Paused
        return GuardStatusKind.Paused
    if stateObj.MaintenanceMode == MaintenancePhase.TimedOut
        return GuardStatusKind.MaintenanceTimedOut
    if stateObj.MissingSinceTicks
        && stateObj.StatusKind != GuardStatusKind.ProgramMissing
        && stateObj.StatusKind != GuardStatusKind.ScriptMissing
        return GuardStatusKind.TargetMissing
    if stateObj.RunAsAdmin && stateObj.PIDElevationChecked
        && stateObj.PIDElevationState == 0
        return GuardStatusKind.PermissionMismatch
    resourceFiles := StatusIconResourceFiles()
    if stateObj.StatusKind != "" && resourceFiles.Has(stateObj.StatusKind)
        return stateObj.StatusKind
    ; 兼容仅构造核心控制器、尚未发布首条展示状态的极早阶段。正式更新
    ; 都会显式携带 StatusKind，因此这里不会把不同用户状态重新合并。
    if stateObj.MaintenanceMode == MaintenancePhase.Arbitrating
        return GuardStatusKind.MaintenanceArbitrating
    if stateObj.MaintenanceMode == MaintenancePhase.Updating
        return GuardStatusKind.MaintenanceUpdating
    if stateObj.MaintenanceMode == MaintenancePhase.Stabilizing
        return GuardStatusKind.MaintenanceStabilizing
    if stateObj.MaintenanceMode == MaintenancePhase.Recovering
        return GuardStatusKind.MaintenanceRecovering
    switch stateObj.Phase {
        case GuardPhase.Running:
            return GuardStatusKind.Running
        case GuardPhase.SuspectedStopped:
            return GuardStatusKind.SuspectedStop
        case GuardPhase.WaitingRestart:
            return stateObj.FailCount > 0
                ? GuardStatusKind.RetryCountdown
                : GuardStatusKind.StartCountdown
        case GuardPhase.CoolingDown:
            return GuardStatusKind.CoolingDown
        case GuardPhase.Starting:
            return GuardStatusKind.Starting
        case GuardPhase.Verifying:
            return GuardStatusKind.Verifying
        case GuardPhase.Initializing:
            return GuardStatusKind.Initializing
        case GuardPhase.Exhausted:
            return GuardStatusKind.TargetMissing
        default:
            return GuardStatusKind.Unknown
    }
}

GetMainStatusSemanticPriority(statusKind) {
    ; 数值越小越靠前。具体异常先于未知异常，恢复与等待过程居中，暂停和
    ; 正常运行置后；排序完全依赖稳定语义键，不受界面语言或状态文案影响。
    static priorities := Map(
        GuardStatusKind.MaintenanceTimedOut, 1,
        GuardStatusKind.PermissionMismatch, 2,
        GuardStatusKind.TargetMissing, 3,
        GuardStatusKind.ProgramMissing, 4,
        GuardStatusKind.ScriptMissing, 5,
        GuardStatusKind.SuspectedStop, 6,
        GuardStatusKind.LaunchRetry, 7,
        GuardStatusKind.CoolingDown, 8,
        GuardStatusKind.RetryCountdown, 9,
        GuardStatusKind.Unknown, 10,
        GuardStatusKind.MaintenanceArbitrating, 20,
        GuardStatusKind.MaintenanceUpdating, 21,
        GuardStatusKind.MaintenanceFileWaiting, 22,
        GuardStatusKind.MaintenanceStabilizing, 23,
        GuardStatusKind.MaintenanceRecovering, 24,
        GuardStatusKind.SafeStartWait, 30,
        GuardStatusKind.WaitingObservation, 31,
        GuardStatusKind.StartCountdown, 32,
        GuardStatusKind.Starting, 33,
        GuardStatusKind.Verifying, 34,
        GuardStatusKind.Initializing, 35,
        GuardStatusKind.Paused, 40,
        GuardStatusKind.Running, 50)
    return priorities.Has(statusKind)
        ? priorities[statusKind] : priorities[GuardStatusKind.Unknown]
}

GetMainStatusSortKey(stateObj, sequence, descending := false) {
    statusKind := GetMainStatusVisualKind(stateObj)
    try sequence := Min(0x7FFFFFFF, Max(0, Integer(sequence)))
    catch
        sequence := 0
    ; SortDesc 会反转整个键，因此降序时先反转序号部分，使同一状态组内
    ; 仍按用户保存的自定义顺序排列。
    stableSequence := descending ? 0x7FFFFFFF - sequence : sequence
    return Format("{:02}|{}",
        GetMainStatusSemanticPriority(statusKind), stableSequence)
}

IsMainStatusSortDescending() {
    return Main.HasOwnProp("listHeader") && IsObject(Main.listHeader)
        && Main.listHeader.HasActiveSort()
        && Main.listHeader.GetSortColumn() == 5
        && Main.listHeader.SortDescending
}

SetMainStatusSortKey(row, stateObj := "", descending := "") {
    if (row < 1 || row > Main.lv.GetCount())
        return false
    if !IsObject(stateObj) {
        try {
            path := NormalizeTargetPath(Main.lv.GetText(row, 3))
            if App.appStates.Has(path)
                stateObj := App.appStates[path]
        }
    }
    if descending == ""
        descending := IsMainStatusSortDescending()
    sequence := Main.lv.GetText(row, 4)
    Main.lv.Modify(row, "Col5", GetMainStatusSortKey(stateObj, sequence,
        descending))
    ScheduleMainListNativeSurfaceRefresh()
    return true
}

RefreshMainStatusSortKeys(descending := "", scheduleSort := true) {
    if !Main.lv
        return 0
    if descending == ""
        descending := IsMainStatusSortDescending()
    refreshed := 0
    Loop Main.lv.GetCount() {
        if SetMainStatusSortKey(A_Index, "", descending)
            refreshed++
    }
    if refreshed && scheduleSort
        ScheduleMainListTemporarySortRefresh(5)
    ScheduleMainListNativeSurfaceRefresh()
    return refreshed
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
    updated := SendMessage(Win32.LVM_SETITEMW, 0,
        listItem.Ptr, Main.lv.Hwnd) != 0
    if updated
        ScheduleMainListNativeSurfaceRefresh()
    return updated
}

SetMainListStatus(row, statusText) {
    if (row < 1 || row > Main.lv.GetCount())
        return
    Main.lv.Modify(row, "Col2", FormatMainStatusLabel(statusText))
    stateObj := ""
    try {
        path := NormalizeTargetPath(Main.lv.GetText(row, 3))
        if App.appStates.Has(path)
            stateObj := App.appStates[path]
    }
    statusKind := GetMainStatusVisualKind(stateObj)
    iconIndex := Main.HasOwnProp("statusIconIndices")
        && Main.statusIconIndices.Has(statusKind)
        ? Main.statusIconIndices[statusKind]
        : 0
    SetMainListSubItemIcon(row, iconIndex)
    SetMainStatusSortKey(row, stateObj)
    ScheduleMainListTemporarySortRefresh(5)
}

ApplyDarkListViewTheme(hLV) {
    ; 通过 SetWindowTheme 和 AllowDarkModeForWindow 将 ListView 及其滚动条
    ; 设定为当前明暗样式；同时显式设置颜色，避免系统主题切换后出现白色闪烁。
    if !DllCall("user32\IsWindow", "Ptr", hLV, "Int")
        return
    dark := UiThemeService.IsDark()
    themeName := UiThemeService.GetListThemeName()
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        UiThemeService.AllowDarkModeForWindow(hLV, dark)
        try DllCall("uxtheme\SetWindowTheme", "Ptr", hLV, "Str", themeName, "Ptr", 0)
        hHeader := SendMessage(Win32.LVM_GETHEADER, 0, 0, hLV)
        if (hHeader) {
            UiThemeService.AllowDarkModeForWindow(hHeader, dark)
            try DllCall("uxtheme\SetWindowTheme", "Ptr", hHeader, "Str",
                dark ? "DarkMode_ItemsView" : "Explorer", "Ptr", 0)
            try DllCall("user32\InvalidateRect", "Ptr", hHeader, "Ptr", 0, "Int", 1)
        }
    }
    ; ListView 的 COLORREF 按 BGR 传递；AHK 颜色字符串是 RGB。
    SendMessage(0x1001, 0, ColorRefFromHex(UiThemeService.Color("Surface")),,
        hLV)
    SendMessage(0x1024, 0, ColorRefFromHex(UiThemeService.Color("Text")),,
        hLV)
    SendMessage(0x1026, 0,
        ColorRefFromHex(UiThemeService.Color("Surface")),, hLV)
    try DllCall("user32\InvalidateRect", "Ptr", hLV, "Ptr", 0, "Int", 1)
}

ApplyDarkControlTheme(hCtrl, themeName := "") {
    if !hCtrl || !DllCall("user32\IsWindow", "Ptr", hCtrl, "Int")
        return false
    if (VerCompare(A_OSVersion, "10.0.17763") < 0)
        return false
    dark := UiThemeService.IsDark()
    themeName := InStr(themeName, "CFD", false)
        ? UiThemeService.GetComboThemeName()
        : UiThemeService.GetExplorerThemeName()

    UiThemeService.AllowDarkModeForWindow(hCtrl, dark)
    themeApplied := false
    try themeApplied := DllCall("uxtheme\SetWindowTheme", "Ptr", hCtrl,
        "Str", themeName, "Ptr", 0, "Int") == 0
    ; 主题切换会影响边框、箭头和滚动条；一次性重绘整个控件树，避免局部残留亮色。
    try DllCall("user32\RedrawWindow", "Ptr", hCtrl, "Ptr", 0,
        "Ptr", 0, "UInt", 0x485, "Int")
    return themeApplied
}

ColorRefFromHex(color) {
    value := ParseButtonColorValue(color)
    if value < 0
        return 0
    return ((value & 0xFF) << 16) | (value & 0xFF00) | ((value >> 16) & 0xFF)
}

GetComboBoxThemeHandles(hCombo) {
    handles := {Combo: hCombo, Item: 0, List: 0}
    if !hCombo || !DllCall("user32\IsWindow", "Ptr", hCombo, "Int")
        return handles

    ; COMBOBOXINFO 的三个 HWND 从偏移 40 开始，x64 会自然按 8 字节对齐。
    comboInfo := Buffer(40 + 3 * A_PtrSize, 0)
    NumPut("UInt", comboInfo.Size, comboInfo, 0)
    if !DllCall("user32\GetComboBoxInfo", "Ptr", hCombo,
            "Ptr", comboInfo, "Int")
        return handles
    comboHandle := NumGet(comboInfo, 40, "Ptr")
    handles.Combo := comboHandle ? comboHandle : hCombo
    handles.Item := NumGet(comboInfo, 40 + A_PtrSize, "Ptr")
    handles.List := NumGet(comboInfo, 40 + 2 * A_PtrSize, "Ptr")
    return handles
}

GetComboBoxDisplayPadding() {
    ; 原生 DropDownList 没有水平内边距消息。显示标签两端使用一个 en space，
    ; 既能在收起区和弹出列表中形成稳定留白，也不会改动按索引保存的真实配置值。
    static padding := Chr(0x2002)
    return padding
}

AddComboBoxDisplayPadding(items) {
    paddedItems := []
    padding := GetComboBoxDisplayPadding()
    for item in items
        paddedItems.Push(padding String(item) padding)
    return paddedItems
}

class DarkComboBoxListThemeRegistry {
    static ListHandles := Map()
    static MessageRegistered := false
    static BackgroundColorRef := 0x262525
    static TextColorRef := 0xFFFFFF

    static Register(hList, hCombo) {
        if !hList || !hCombo
            || !DllCall("user32\IsWindow", "Ptr", hList, "Int")
            || !DllCall("user32\IsWindow", "Ptr", hCombo, "Int")
            return false
        this.ListHandles[hList] := hCombo
        if !this.MessageRegistered {
            OnMessage(0x0134, ObjBindMethod(this, "HandleListColor"))
            this.MessageRegistered := true
        }
        return true
    }

    static Unregister(hList) {
        if hList && this.ListHandles.Has(hList)
            this.ListHandles.Delete(hList)
    }

    static IsRegistered(hList) {
        return hList && this.ListHandles.Has(hList)
    }

    static HandleListColor(deviceContext, listHwnd, *) {
        if !this.ListHandles.Has(listHwnd)
            return
        comboHwnd := this.ListHandles[listHwnd]
        currentHandles := GetComboBoxThemeHandles(comboHwnd)
        if !DllCall("user32\IsWindow", "Ptr", listHwnd, "Int")
                || currentHandles.List != listHwnd {
            this.ListHandles.Delete(listHwnd)
            return
        }
        this.BackgroundColorRef := ColorRefFromHex(
            UiThemeService.Color("Surface"))
        this.TextColorRef := ColorRefFromHex(UiThemeService.Color("Text"))
        DllCall("gdi32\SetTextColor", "Ptr", deviceContext,
            "UInt", this.TextColorRef)
        DllCall("gdi32\SetBkColor", "Ptr", deviceContext,
            "UInt", this.BackgroundColorRef)
        ; DC_BRUSH 是系统共享画刷，不需要创建或销毁，也不会引入 GDI 资源泄漏。
        DllCall("gdi32\SetDCBrushColor", "Ptr", deviceContext,
            "UInt", this.BackgroundColorRef)
        return DllCall("gdi32\GetStockObject", "Int", 18, "Ptr")
    }
}

ApplyDarkComboBoxTheme(hCombo) {
    handles := GetComboBoxThemeHandles(hCombo)
    if !handles.Combo || !DllCall("user32\IsWindow", "Ptr",
            handles.Combo, "Int")
        return false

    ; 设置主题可能重新计算非客户区，之后再次清除边框样式，保证首次显示、
    ; 字体列表刷新和主题热切换都维持相同的无边框外观。
    applied := ApplyDarkControlTheme(handles.Combo, UiThemeService.GetComboThemeName())
    RemoveComboBoxBorder(handles.Combo)
    if handles.Item
        ApplyDarkControlTheme(handles.Item, UiThemeService.GetComboThemeName())
    if handles.List {
        DarkComboBoxListThemeRegistry.Register(handles.List, handles.Combo)
        ApplyDarkControlTheme(handles.List, UiThemeService.GetExplorerThemeName())
    }
    return applied
}

RemoveComboBoxBorder(hCombo) {
    if !hCombo || !DllCall("user32\IsWindow", "Ptr", hCombo, "Int")
        return false
    static GWL_STYLE := -16
    static GWL_EXSTYLE := -20
    static WS_BORDER := 0x00800000
    static WS_EX_DLGMODALFRAME := 0x00000001
    static WS_EX_CLIENTEDGE := 0x00000200
    static WS_EX_STATICEDGE := 0x00020000
    style := DllCall("user32\GetWindowLongPtrW", "Ptr", hCombo,
        "Int", GWL_STYLE, "Ptr")
    exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", hCombo,
        "Int", GWL_EXSTYLE, "Ptr")
    borderlessStyle := style & ~WS_BORDER
    borderlessExStyle := exStyle & ~(WS_EX_DLGMODALFRAME
        | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE)
    if borderlessStyle != style
        DllCall("user32\SetWindowLongPtrW", "Ptr", hCombo,
            "Int", GWL_STYLE, "Ptr", borderlessStyle, "Ptr")
    if borderlessExStyle != exStyle
        DllCall("user32\SetWindowLongPtrW", "Ptr", hCombo,
            "Int", GWL_EXSTYLE, "Ptr", borderlessExStyle, "Ptr")
    ; SWP_FRAMECHANGED 让已创建控件立即按新样式重算边缘，不改变位置和层级。
    DllCall("user32\SetWindowPos", "Ptr", hCombo, "Ptr", 0,
        "Int", 0, "Int", 0, "Int", 0, "Int", 0,
        "UInt", 0x0237, "Int")
    return true
}

UnregisterDarkComboBoxTheme(hCombo) {
    handles := GetComboBoxThemeHandles(hCombo)
    DarkComboBoxListThemeRegistry.Unregister(handles.List)
}

SetDarkControl(hCtrl) {
    return ApplyDarkControlTheme(hCtrl, UiThemeService.GetExplorerThemeName())
}

MoveAndRefreshResizableText(control, x := "", y := "", width := "",
    height := "") {
    ; Windows STATIC 控件扩大后不一定会重绘先前位于裁剪区外的文本，
    ; BackgroundTrans 会进一步放大这个问题。只在尺寸扩张时同步刷新新控件区域，
    ; 避免窗口拖动期间反复重绘整个客户区。
    if !IsObject(control)
        return false
    try controlHwnd := control.Hwnd
    catch
        return false
    if !controlHwnd || !DllCall("user32\IsWindow", "Ptr", controlHwnd,
        "Int") {
        return false
    }
    try control.GetPos(,, &oldWidth, &oldHeight)
    catch
        return false
    try control.Move(x, y, width, height)
    catch
        return false
    try control.GetPos(,, &newWidth, &newHeight)
    catch
        return false
    if newWidth <= oldWidth && newHeight <= oldHeight
        return true

    ; 控件已使用与父窗口一致的实色背景，可直接让自身整个客户区失效。
    ; 父窗口局部重绘不会可靠地向 STATIC 子控件派发 WM_PAINT；直接同步重绘
    ; 才能保证新扩出的右侧区域重新排版文字，同时不牵连列表和命令栏。
    return DllCall("user32\RedrawWindow", "Ptr", controlHwnd, "Ptr", 0,
        "Ptr", 0, "UInt", Win32.RDW_CONTROL_REFRESH, "Int") != 0
}

SetSingleLineEditHorizontalMargins(hEdit, leftDip := 6, rightDip := 6) {
    if !hEdit || !DllCall("user32\IsWindow", "Ptr", hEdit, "Int")
        return false
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", hEdit, "UInt")
    if !dpi
        dpi := 96
    leftPixels := Max(4, Round(leftDip * dpi / 96))
    rightPixels := Max(4, Round(rightDip * dpi / 96))
    packedMargins := (rightPixels << 16) | (leftPixels & 0xFFFF)
    try SendMessage(Win32.EM_SETMARGINS,
        Win32.EC_LEFTMARGIN | Win32.EC_RIGHTMARGIN,
        packedMargins, hEdit)
    catch
        return false
    return true
}

AddCenteredSingleLineEdit(guiObj, x, y, width, outerHeight, value := "", extraOptions := "", backgroundColor := "") {
    if backgroundColor == ""
        backgroundColor := UiThemeService.Color("Input")
    innerHeight := Max(18, outerHeight - 6)
    innerY := y + Floor((outerHeight - innerHeight) / 2)
    background := guiObj.Add("Text", "x" x " y" y " w" width " h" outerHeight " Background" backgroundColor)
    editOptions := "x" x " y" innerY " w" width " h" innerHeight " Background" backgroundColor " c" UiThemeService.Color("Text") " -E0x200"
    if extraOptions
        editOptions .= " " extraOptions
    inputEditControl := guiObj.Add("Edit", editOptions, value)
    SetSingleLineEditHorizontalMargins(inputEditControl.Hwnd)
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

; Shell 图标查询的最后回退路径只返回真实图标句柄，句柄所有权随返回值交给调用方。

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
    flags := 0x100 ; SHGFI_ICON：要求 Shell 返回图标句柄。
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

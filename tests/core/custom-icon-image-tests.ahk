#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证自定义图标对常见图片、SVG 和原生图标资源的解码与缩放质量。
; 通过像素、透明通道和资源计数检查黑底、偏移、锯齿以及 GDI 句柄泄漏回归。

try {
    RunCustomIconImageTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertCustomIcon(value, message) {
    if !value
        throw Error(message)
}

CreateRasterIconFixture(filePath, encoderClsid) {
    if !RoundedButtonRenderer.EnsureStarted()
        throw Error("无法初始化测试图像编码器")
    width := 96
    height := 48
    stride := width * 4
    pixels := Buffer(stride * height, 0)
    Loop width * height
        NumPut("UInt", 0xFFFF1493, pixels, (A_Index - 1) * 4)

    image := 0
    try {
        ; PixelFormat32bppPARGB：32 位、预乘 Alpha、GDI 兼容。
        if DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", width,
            "Int", height, "Int", stride, "Int", 0x000E200B,
            "Ptr", pixels, "Ptr*", &image, "UInt") || !image
            throw Error("无法创建测试位图：" filePath)
        encoder := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString", "WStr", encoderClsid,
            "Ptr", encoder, "Int") < 0
            throw Error("测试图像编码器 CLSID 无效：" encoderClsid)
        if DllCall("gdiplus\GdipSaveImageToFile", "Ptr", image,
            "WStr", filePath, "Ptr", encoder, "Ptr", 0, "UInt")
            throw Error("无法写入测试图像：" filePath)
    } finally {
        if image
            try DllCall("gdiplus\GdipDisposeImage", "Ptr", image)
    }
}

CreateWhiteMatteBmpFixture(filePath) {
    if !RoundedButtonRenderer.EnsureStarted()
        throw Error("无法初始化白底 BMP 测试图像编码器")
    width := 64
    height := 64
    stride := width * 4
    pixels := Buffer(stride * height, 0)
    Loop width * height
        NumPut("UInt", 0xFFFFFFFF, pixels, (A_Index - 1) * 4)
    Loop 44 {
        y := A_Index + 9
        Loop 44 {
            x := A_Index + 9
            if ((x - 31.5) ** 2 + (y - 31.5) ** 2 <= 22 ** 2)
                NumPut("UInt", 0xFF2060D0, pixels, (y * width + x) * 4)
        }
    }
    image := 0
    try {
        if DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", width,
            "Int", height, "Int", stride, "Int", 0x000E200B,
            "Ptr", pixels, "Ptr*", &image, "UInt") || !image
            throw Error("无法创建白底 BMP 测试图像")
        encoder := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString",
            "WStr", "{557CF400-1A04-11D3-9A73-0000F81EF32E}",
            "Ptr", encoder, "Int") < 0
            throw Error("BMP 测试编码器 CLSID 无效")
        if DllCall("gdiplus\GdipSaveImageToFile", "Ptr", image,
            "WStr", filePath, "Ptr", encoder, "Ptr", 0, "UInt")
            throw Error("无法写入白底 BMP 测试图像")
    } finally {
        if image
            try DllCall("gdiplus\GdipDisposeImage", "Ptr", image)
    }
}

CreateSingleFrameIcoFixture(sourcePath, filePath, frameSize) {
    source := FileRead(sourcePath, "RAW")
    entryCount := NumGet(source, 4, "UShort")
    selectedOffset := -1
    Loop entryCount {
        entryOffset := 6 + (A_Index - 1) * 16
        width := NumGet(source, entryOffset, "UChar")
        width := width ? width : 256
        if width == frameSize
            && NumGet(source, entryOffset + 6, "UShort") >= 24 {
            selectedOffset := entryOffset
            break
        }
    }
    if selectedOffset < 0
        throw Error("测试 ICO 缺少指定的真彩色帧：" frameSize)
    dataSize := NumGet(source, selectedOffset + 8, "UInt")
    dataOffset := NumGet(source, selectedOffset + 12, "UInt")
    output := Buffer(22 + dataSize, 0)
    NumPut("UShort", 0, output, 0)
    NumPut("UShort", 1, output, 2)
    NumPut("UShort", 1, output, 4)
    DllCall("ntdll\RtlMoveMemory", "Ptr", output.Ptr + 6,
        "Ptr", source.Ptr + selectedOffset, "UPtr", 12)
    NumPut("UInt", 22, output, 18)
    DllCall("ntdll\RtlMoveMemory", "Ptr", output.Ptr + 22,
        "Ptr", source.Ptr + dataOffset, "UPtr", dataSize)
    outputFile := FileOpen(filePath, "w")
    if !outputFile
        throw Error("无法创建单帧 ICO 测试文件")
    outputFile.RawWrite(output)
    outputFile.Close()
}

ReadIconPixelSnapshot(iconHandle) {
    iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
    if !DllCall("user32\GetIconInfo", "Ptr", iconHandle, "Ptr", iconInfo)
        throw Error("无法读取生成图标的信息")
    bitmapOffset := A_PtrSize == 8 ? 16 : 12
    maskBitmap := NumGet(iconInfo, bitmapOffset, "Ptr")
    colorBitmap := NumGet(iconInfo, bitmapOffset + A_PtrSize, "Ptr")
    screenDC := 0
    try {
        if !colorBitmap
            throw Error("生成图标没有 32 位颜色位图")
        bitmapObject := Buffer(A_PtrSize == 8 ? 32 : 24, 0)
        if !DllCall("gdi32\GetObjectW", "Ptr", colorBitmap,
            "Int", bitmapObject.Size, "Ptr", bitmapObject)
            throw Error("无法读取生成图标的位图尺寸")
        width := NumGet(bitmapObject, 4, "Int")
        height := Abs(NumGet(bitmapObject, 8, "Int"))
        bitmapInfo := Buffer(40, 0)
        NumPut("UInt", 40, bitmapInfo, 0)
        NumPut("Int", width, bitmapInfo, 4)
        NumPut("Int", -height, bitmapInfo, 8)
        NumPut("UShort", 1, bitmapInfo, 12)
        NumPut("UShort", 32, bitmapInfo, 14)
        pixels := Buffer(width * height * 4, 0)
        screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
        if !screenDC || !DllCall("gdi32\GetDIBits", "Ptr", screenDC,
            "Ptr", colorBitmap, "UInt", 0, "UInt", height, "Ptr", pixels,
            "Ptr", bitmapInfo, "UInt", 0)
            throw Error("无法读取生成图标的像素")
        return {Width: width, Height: height, Pixels: pixels}
    } finally {
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
        if maskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
        if colorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", colorBitmap)
    }
}

GetOpaqueIconBounds(snapshot) {
    left := snapshot.Width
    top := snapshot.Height
    right := -1
    bottom := -1
    Loop snapshot.Height {
        y := A_Index - 1
        Loop snapshot.Width {
            x := A_Index - 1
            alpha := NumGet(snapshot.Pixels,
                (y * snapshot.Width + x) * 4 + 3, "UChar")
            if alpha <= 8
                continue
            left := Min(left, x)
            top := Min(top, y)
            right := Max(right, x)
            bottom := Max(bottom, y)
        }
    }
    return right >= left && bottom >= top
        ? {Width: right - left + 1, Height: bottom - top + 1}
        : {Width: 0, Height: 0}
}

AssertStatusIconStrokeColor(snapshot, statusKind, expectedRgb) {
    expectedRed := (expectedRgb >> 16) & 0xFF
    expectedGreen := (expectedRgb >> 8) & 0xFF
    expectedBlue := expectedRgb & 0xFF
    visiblePixels := 0
    opaqueStrokePixels := 0
    Loop snapshot.Width * snapshot.Height {
        offset := (A_Index - 1) * 4
        alpha := NumGet(snapshot.Pixels, offset + 3, "UChar")
        if alpha <= 8
            continue
        visiblePixels++
        blue := Round(NumGet(snapshot.Pixels, offset, "UChar") * 255 / alpha)
        green := Round(NumGet(snapshot.Pixels,
            offset + 1, "UChar") * 255 / alpha)
        red := Round(NumGet(snapshot.Pixels,
            offset + 2, "UChar") * 255 / alpha)
        ; resvg 返回预乘 BGRA。低 Alpha 边缘会有量化误差，因此仅要求
        ; 高不透明度描边严格匹配资源颜色；透明边缘由像素数量单独覆盖。
        if alpha < 200
            continue
        AssertCustomIcon(Abs(red - expectedRed) <= 8
            && Abs(green - expectedGreen) <= 8
            && Abs(blue - expectedBlue) <= 8,
            "状态 SVG 的描边颜色与资源规格不一致：" statusKind
                "（实际 RGB=" red "," green "," blue
                "；预期 RGB=" expectedRed "," expectedGreen ","
                expectedBlue "）")
        opaqueStrokePixels++
    }
    AssertCustomIcon(visiblePixels >= 16 && opaqueStrokePixels >= 4,
        "状态 SVG 缺少清晰的单色描边：" statusKind)
}

GetOpaqueIconRectangle(snapshot) {
    left := snapshot.Width
    top := snapshot.Height
    right := -1
    bottom := -1
    Loop snapshot.Height {
        y := A_Index - 1
        Loop snapshot.Width {
            x := A_Index - 1
            if NumGet(snapshot.Pixels,
                (y * snapshot.Width + x) * 4 + 3, "UChar") <= 8
                continue
            left := Min(left, x)
            top := Min(top, y)
            right := Max(right, x)
            bottom := Max(bottom, y)
        }
    }
    return {Left: left, Top: top, Right: right, Bottom: bottom}
}

AssertWindowsAdminShieldColors(snapshot, dpi) {
    bluePixels := 0
    yellowPixels := 0
    Loop snapshot.Width * snapshot.Height {
        offset := (A_Index - 1) * 4
        alpha := NumGet(snapshot.Pixels, offset + 3, "UChar")
        if alpha < 128
            continue
        blue := Round(NumGet(snapshot.Pixels, offset, "UChar") * 255 / alpha)
        green := Round(NumGet(snapshot.Pixels,
            offset + 1, "UChar") * 255 / alpha)
        red := Round(NumGet(snapshot.Pixels,
            offset + 2, "UChar") * 255 / alpha)
        if blue >= 110 && blue >= green + 10 && blue >= red + 25
            bluePixels++
        if red >= 150 && green >= 105 && blue <= 155
            && red >= blue + 35
            yellowPixels++
    }
    AssertCustomIcon(bluePixels >= 2 && yellowPixels >= 2,
        "Windows 原生管理员盾牌缺少清晰的蓝黄象限：DPI=" dpi
            "（蓝色像素=" bluePixels "，黄色像素=" yellowPixels "）")
}

AssertPaddedCustomIcon(filePath, expectWideContent := true,
    expectTransparentContentCorner := false) {
    iconHandle := CreateCustomImagePaddedIcon(filePath, 28, 36)
    AssertCustomIcon(iconHandle, "无法解码自定义图标：" filePath)
    try {
        snapshot := ReadIconPixelSnapshot(iconHandle)
        AssertCustomIcon(snapshot.Width == 36 && snapshot.Height == 36,
            "自定义图标没有填入 36×36 的主列表单元格：" filePath)
        cornerOffsets := [0, (snapshot.Width - 1) * 4,
            (snapshot.Height - 1) * snapshot.Width * 4,
            (snapshot.Width * snapshot.Height - 1) * 4]
        for offset in cornerOffsets
            AssertCustomIcon(NumGet(snapshot.Pixels, offset + 3, "UChar") == 0,
                "自定义图标外层留白不是透明的：" filePath)
        bounds := GetOpaqueIconBounds(snapshot)
        AssertCustomIcon(bounds.Width > 0 && bounds.Height > 0
            && bounds.Width <= 28 && bounds.Height <= 28,
            "自定义图标内容越界或为空：" filePath)
        if expectWideContent
            AssertCustomIcon(bounds.Width >= bounds.Height * 1.7,
                "横向图像没有保持原始纵横比（实际内容 " bounds.Width
                    "×" bounds.Height "）：" filePath)
        if expectTransparentContentCorner {
            contentLeft := Floor((snapshot.Width - 28) / 2)
            contentTop := Floor((snapshot.Height - 14) / 2)
            contentCornerAlpha := NumGet(snapshot.Pixels,
                (contentTop * snapshot.Width + contentLeft) * 4 + 3,
                "UChar")
            AssertCustomIcon(contentCornerAlpha <= 8,
                "SVG 的 Shell 合成底色没有恢复为透明（Alpha "
                    contentCornerAlpha "）：" filePath)
        }
    } finally {
        try DllCall("user32\DestroyIcon", "Ptr", iconHandle)
    }
}

AssertBmpMatteRemoved(filePath) {
    iconHandle := CreateCustomImagePaddedIcon(filePath, 28, 36)
    AssertCustomIcon(iconHandle, "无法解码白底 BMP：" filePath)
    try {
        snapshot := ReadIconPixelSnapshot(iconHandle)
        sourceCorner := Floor((snapshot.Width - 28) / 2)
        cornerAlpha := NumGet(snapshot.Pixels,
            (sourceCorner * snapshot.Width + sourceCorner) * 4 + 3,
            "UChar")
        centerAlpha := NumGet(snapshot.Pixels,
            (Floor(snapshot.Height / 2) * snapshot.Width
                + Floor(snapshot.Width / 2)) * 4 + 3, "UChar")
        AssertCustomIcon(cornerAlpha <= 8,
            "BMP 的连通白底没有转为透明（Alpha " cornerAlpha "）")
        AssertCustomIcon(centerAlpha >= 240,
            "BMP 前景被白底清理逻辑误删（Alpha " centerAlpha "）")
    } finally {
        try DllCall("user32\DestroyIcon", "Ptr", iconHandle)
    }
}

AssertIndexedIconResourceSelection(singleFrameIcoPath) {
    AssertCustomIcon(SelectHighQualityMainIconSourceSize(28) == 128
        && SelectHighQualityMainIconSourceSize(42) == 256
        && SelectHighQualityMainIconSourceSize(56) == 256
        && SelectHighQualityMainIconSourceSize(84) == 256,
        "主列表图标没有按 DPI 选择四倍尺寸上限的高清源资源")
    candidateIndex := FindPreferredIconCandidateIndex([
        {Width: 256, Height: 256, BitsPerPixel: 8, DataSize: 7000},
        {Width: 128, Height: 128, BitsPerPixel: 32, DataSize: 68000},
        {Width: 256, Height: 256, BitsPerPixel: 32, DataSize: 40000}
    ], 224)
    AssertCustomIcon(candidateIndex == 3
        && FindPreferredIconCandidateIndex([
            {Width: 256, Height: 256, BitsPerPixel: 8, DataSize: 7000},
            {Width: 128, Height: 128, BitsPerPixel: 32, DataSize: 68000},
            {Width: 256, Height: 256, BitsPerPixel: 32, DataSize: 40000}
        ], 96) == 2,
        "真实图标帧没有优先选择真彩色和最接近的足够尺寸")

    icoPath := A_ScriptDir "\..\..\assets\app\watchdog.ico"
    exactIcoHandle := CreateExactIconFromIco(icoPath, 224)
    AssertCustomIcon(exactIcoHandle, "无法从 ICO 精确提取原生高清帧")
    try {
        exactIcoSnapshot := ReadIconPixelSnapshot(exactIcoHandle)
        AssertCustomIcon(exactIcoSnapshot.Width == 256
            && exactIcoSnapshot.Height == 256,
            "ICO 的 256px 原生帧被系统隐式缩放替代")
    } finally DllCall("user32\DestroyIcon", "Ptr", exactIcoHandle)

    lowResolutionHandle := CreateExactIconFromIco(singleFrameIcoPath, 256)
    AssertCustomIcon(lowResolutionHandle,
        "无法从低分辨率 ICO 提取唯一的原生帧")
    try {
        lowResolutionSnapshot := ReadIconPixelSnapshot(lowResolutionHandle)
        AssertCustomIcon(lowResolutionSnapshot.Width == 32
            && lowResolutionSnapshot.Height == 32,
            "低分辨率 ICO 被系统预先放大，仍会产生二次采样")
        paddedHandle := CreateHighQualityPaddedIcon(lowResolutionHandle,
            56, 72)
        AssertCustomIcon(paddedHandle,
            "低分辨率原生帧无法通过 WIC 单次放大")
        try {
            paddedSnapshot := ReadIconPixelSnapshot(paddedHandle)
            paddedBounds := GetOpaqueIconBounds(paddedSnapshot)
            AssertCustomIcon(paddedSnapshot.Width == 72
                && paddedSnapshot.Height == 72
                && paddedBounds.Width <= 56 && paddedBounds.Height <= 56,
                "低分辨率图标放大后没有保持主列表透明边距")
        } finally DllCall("user32\DestroyIcon", "Ptr", paddedHandle)
    } finally DllCall("user32\DestroyIcon", "Ptr", lowResolutionHandle)

    resourcePath := A_WinDir "\System32\shell32.dll"
    indexedSource := FormatCustomIconSource(resourcePath, 44, true)
    parsedSource := ParseCustomIconSource(indexedSource)
    AssertCustomIcon(parsedSource.HasIndex && parsedSource.Index == 44
        && PathsEquivalent(parsedSource.Path, resourcePath),
        "DLL 图标资源索引没有被正确解析")
    quotedSource := ParseCustomIconSource('"' resourcePath '",44')
    AssertCustomIcon(quotedSource.HasIndex && quotedSource.Index == 44
        && PathsEquivalent(quotedSource.Path, resourcePath),
        "带引号 DLL 路径的图标资源索引没有被正确解析")
    AssertCustomIcon(CustomIconSourceExists(indexedSource)
        && IsSupportedCustomIconSource(indexedSource)
        && GetCustomIconSourceExtension(indexedSource) == "dll",
        "带资源索引的 DLL 图标来源没有通过验证")

    useHighQuality := false
    iconHandle := GetPreferredMainIcon(indexedSource, &useHighQuality)
    AssertCustomIcon(iconHandle && useHighQuality,
        "无法提取指定索引的 DLL 图标资源")
    try {
        snapshot := ReadIconPixelSnapshot(iconHandle)
        bounds := GetOpaqueIconBounds(snapshot)
        AssertCustomIcon(snapshot.Width >= App.iconResources.MainIconPixelSize
            && snapshot.Height == snapshot.Width,
            "原生资源没有按真实的高清帧尺寸提取")
        AssertCustomIcon(bounds.Width > 0 && bounds.Height > 0,
            "指定索引的 DLL 图标资源渲染为空")
    } finally {
        if iconHandle
            try DllCall("user32\DestroyIcon", "Ptr", iconHandle)
    }
}

AssertNativeSvgRasterization(filePath, expectedAspectRatio := 0) {
    AssertCustomIcon(App.svgRenderer.IsAvailable(),
        "项目附带的 resvg.dll 无法加载")
    snapshot := App.svgRenderer.RenderFile(filePath, 96, 128)
    AssertCustomIcon(IsObject(snapshot) && snapshot.Width > 0
        && snapshot.Height > 0 && snapshot.Pixels.Size
            == snapshot.Width * snapshot.Height * 4,
        "resvg 没有返回完整的 SVG 像素：" filePath)
    AssertCustomIcon(Max(snapshot.Width, snapshot.Height) == 128,
        "resvg 没有使用请求的最长边尺寸：" filePath)
    if expectedAspectRatio > 0 {
        actualAspectRatio := snapshot.Width / snapshot.Height
        AssertCustomIcon(Abs(actualAspectRatio - expectedAspectRatio) <= 0.05,
            "resvg 改变了 SVG 纵横比（实际 " Round(actualAspectRatio, 3)
                "，预期 " expectedAspectRatio "）：" filePath)
    }

    visiblePixels := 0
    transparentPixels := 0
    Loop snapshot.Width * snapshot.Height {
        offset := (A_Index - 1) * 4
        alpha := NumGet(snapshot.Pixels, offset + 3, "UChar")
        if alpha
            visiblePixels++
        else
            transparentPixels++
        AssertCustomIcon(NumGet(snapshot.Pixels, offset, "UChar") <= alpha
            && NumGet(snapshot.Pixels, offset + 1, "UChar") <= alpha
            && NumGet(snapshot.Pixels, offset + 2, "UChar") <= alpha,
            "resvg 像素不是预乘 BGRA：" filePath)
    }
    AssertCustomIcon(visiblePixels > 0,
        "resvg 把 SVG 渲染成了全透明图像：" filePath)
    AssertCustomIcon(transparentPixels > 0,
        "resvg 丢失了 SVG 的透明区域：" filePath)
    iconHandle := CreatePixelSnapshotPaddedIcon(snapshot, 28, 36)
    AssertCustomIcon(iconHandle, "内置 SVG 像素无法转换为主列表图标")
    try {
        iconSnapshot := ReadIconPixelSnapshot(iconHandle)
        bounds := GetOpaqueIconBounds(iconSnapshot)
        AssertCustomIcon(bounds.Width > 0 && bounds.Height > 0
            && bounds.Width <= 28 && bounds.Height <= 28,
            "内置 SVG 图标内容为空或越界")
    } finally DllCall("user32\DestroyIcon", "Ptr", iconHandle)
}

AssertStatusIconResources() {
    originalTheme := UiThemeService.GetRequestedTheme()
    UiThemeService.Configure("dark")
    specs := Map(
        GuardStatusKind.Initializing,
            {Color: 0x0F7EE7, File: "loader-circle.svg"},
        GuardStatusKind.Running,
            {Color: 0x03C078, File: "circle-check-big.svg"},
        GuardStatusKind.PermissionMismatch,
            {Color: 0xA16207, File: "shield-alert.svg"},
        GuardStatusKind.Paused,
            {Color: 0xF4A71D, File: "circle-pause.svg"},
        GuardStatusKind.SuspectedStop,
            {Color: 0xEF4444, File: "triangle-alert-red.svg",
                Group: "Failure"},
        GuardStatusKind.WaitingObservation,
            {Color: 0xA0B7FF, File: "timer.svg", Group: "TimedWait"},
        GuardStatusKind.StartCountdown,
            {Color: 0xA0B7FF, File: "timer.svg", Group: "TimedWait"},
        GuardStatusKind.RetryCountdown,
            {Color: 0xA0B7FF, File: "timer.svg", Group: "TimedWait"},
        GuardStatusKind.CoolingDown,
            {Color: 0xA0B7FF, File: "timer.svg", Group: "TimedWait"},
        GuardStatusKind.Starting,
            {Color: 0xB4875A, File: "rocket.svg"},
        GuardStatusKind.Verifying,
            {Color: 0xE9C08C, File: "scan-search.svg", Group: "Query"},
        GuardStatusKind.TargetMissing,
            {Color: 0xEF4444, File: "circle-x.svg", Group: "Failure"},
        GuardStatusKind.ProgramMissing,
            {Color: 0xEF4444, File: "file-x-2.svg", Group: "Failure"},
        GuardStatusKind.ScriptMissing,
            {Color: 0xEF4444, File: "file-code-2.svg", Group: "Failure"},
        GuardStatusKind.RelocationPending,
            {Color: 0x5DD4E8, File: "repeat-2.svg"},
        GuardStatusKind.SafeStartWait,
            {Color: 0x5F9B0D, File: "shield-ellipsis.svg"},
        GuardStatusKind.LaunchRetry,
            {Color: 0xEF4444, File: "rotate-ccw.svg", Group: "Failure"},
        GuardStatusKind.MaintenanceArbitrating,
            {Color: 0xE9C08C, File: "scan-search.svg", Group: "Query"},
        GuardStatusKind.MaintenanceUpdating,
            {Color: 0x878DF9, File: "refresh-cw.svg"},
        GuardStatusKind.MaintenanceFileWaiting,
            {Color: 0xA0B7FF, File: "file-clock.svg", Group: "TimedWait"},
        GuardStatusKind.MaintenanceStabilizing,
            {Color: 0xA0B7FF, File: "file-clock.svg", Group: "TimedWait"},
        GuardStatusKind.MaintenanceRecovering,
            {Color: 0xA0B7FF, File: "timer.svg", Group: "TimedWait"},
        GuardStatusKind.MaintenanceTimedOut,
            {Color: 0xEF4444, File: "triangle-alert-timeout.svg",
                Group: "Failure"},
        GuardStatusKind.Unknown,
            {Color: 0x858585, File: "circle-info-unknown.svg"})
    resourceFiles := StatusIconResourceFiles()
    colorRoles := StatusIconColorRoles()
    AssertCustomIcon(resourceFiles.Count == specs.Count,
        "状态图标资源映射数量不完整")
    AssertCustomIcon(colorRoles.Count == specs.Count,
        "状态图标语义色映射数量不完整")
    usedColors := Map()
    usedFiles := Map()
    for statusKind, spec in specs {
        semanticGroup := spec.HasOwnProp("Group")
            ? spec.Group : statusKind
        AssertCustomIcon(resourceFiles.Has(statusKind)
            && resourceFiles[statusKind] == spec.File,
            "状态图标资源映射错误：" statusKind)
        AssertCustomIcon(colorRoles.Has(statusKind)
            && GetStatusIconColor(statusKind)
                == Format("{:06X}", spec.Color),
            "深色主题没有保留状态 SVG 的原有语义色：" statusKind)
        AssertCustomIcon(StatusIconVisualScale(statusKind) == 1.00,
            "主列表状态图标没有使用统一 Lucide 视觉比例：" statusKind)
        AssertCustomIcon(!usedColors.Has(spec.Color)
                || usedColors[spec.Color] == semanticGroup,
            "无关状态错误使用了完全相同的颜色：" statusKind " 与 "
                (usedColors.Has(spec.Color)
                    ? usedColors[spec.Color] : ""))
        usedColors[spec.Color] := semanticGroup
        AssertCustomIcon(!usedFiles.Has(spec.File)
                || usedFiles[spec.File] == semanticGroup,
            "无关状态错误复用了同一 SVG 资源：" statusKind " 与 "
                (usedFiles.Has(spec.File) ? usedFiles[spec.File] : ""))
        usedFiles[spec.File] := semanticGroup
        resourcePath := GetStatusIconResourcePath(statusKind)
        normalizedResourcePath := StrReplace(resourcePath, "/", "\")
        AssertCustomIcon(FileExist(resourcePath)
            && InStr(normalizedResourcePath,
                "\assets\ui-icons\lucide\" spec.File),
            "状态 SVG 没有复用 Lucide 界面资源：" resourcePath)
        svgText := FileRead(resourcePath, "UTF-8")
        expectedStroke := 'stroke="#' Format("{:06X}", spec.Color) '"'
        AssertCustomIcon(InStr(svgText, "<!-- Lucide ")
            && InStr(svgText, 'viewBox="0 0 24 24"')
            && InStr(svgText, 'fill="none"')
            && InStr(svgText, expectedStroke)
            && InStr(svgText, 'stroke-width="2"'),
            "状态 SVG 缺少 Lucide 标记、透明背景或预期描边："
                statusKind)

        visualSize := 20
        iconHandle := CreateStatusResourceIcon(statusKind, visualSize, 36)
        AssertCustomIcon(iconHandle, "无法从 SVG 创建状态图标：" statusKind)
        try {
            snapshot := ReadIconPixelSnapshot(iconHandle)
            bounds := GetOpaqueIconBounds(snapshot)
            AssertStatusIconStrokeColor(snapshot, statusKind, spec.Color)
            AssertCustomIcon(Min(bounds.Width, bounds.Height) >= 8
                && Max(bounds.Width, bounds.Height) >= 16
                && bounds.Width <= visualSize && bounds.Height <= visualSize,
                "状态 SVG 的透明描边尺寸不在预期范围内：" statusKind)
            cornerOffsets := [0, (snapshot.Width - 1) * 4,
                (snapshot.Height - 1) * snapshot.Width * 4,
                (snapshot.Width * snapshot.Height - 1) * 4]
            for offset in cornerOffsets
                AssertCustomIcon(NumGet(snapshot.Pixels,
                    offset + 3, "UChar") == 0,
                    "状态图标单元格外角不透明：" statusKind)
        } finally {
            try DllCall("user32\DestroyIcon", "Ptr", iconHandle)
        }
    }

    ; 主列表统计栏与命令栏复用同一套语义色约束，避免之后替换资源时
    ; 又把停止类拆成多种红色，或让设置、帮助图标退回旧配色。
    semanticIconColors := Map(
        "ban.svg", "#EF4444",
        "settings.svg", "#BABABC",
        "circle-question-mark.svg", "#23A9F2",
        "refresh-cw-action.svg", "#878DF9")
    for resourceName, expectedColor in semanticIconColors {
        resourcePath := GetApplicationAssetPath(
            "ui-icons\lucide\" resourceName)
        AssertCustomIcon(FileExist(resourcePath)
            && InStr(FileRead(resourcePath, "UTF-8"),
                'stroke="' expectedColor '"'),
            "界面 SVG 的语义颜色不正确：" resourceName)
    }

    AssertCustomIcon(resourceFiles[GuardStatusKind.Initializing]
            == "loader-circle.svg"
        && resourceFiles[GuardStatusKind.MaintenanceRecovering]
            == "timer.svg"
        && resourceFiles[GuardStatusKind.Initializing]
            != resourceFiles[GuardStatusKind.MaintenanceRecovering],
        "初始化仍错误复用了只代表恢复过程的沙漏")
    AssertCustomIcon(resourceFiles[GuardStatusKind.Running]
            == "circle-check-big.svg"
        && resourceFiles[GuardStatusKind.Paused] == "circle-pause.svg"
        && resourceFiles[GuardStatusKind.MaintenanceUpdating]
            == "refresh-cw.svg",
        "与底部统计栏同义的运行、暂停或升级状态没有复用同一 SVG")
    stopwatchFile := resourceFiles[GuardStatusKind.StartCountdown]
    for stopwatchStatus in [GuardStatusKind.WaitingObservation,
            GuardStatusKind.StartCountdown, GuardStatusKind.RetryCountdown,
            GuardStatusKind.CoolingDown,
            GuardStatusKind.MaintenanceRecovering] {
        AssertCustomIcon(resourceFiles[stopwatchStatus] == stopwatchFile,
            "等待、倒计时或升级恢复状态没有共用蓝色秒表："
                stopwatchStatus)
    }
    AssertCustomIcon(stopwatchFile == "timer.svg"
        && resourceFiles[GuardStatusKind.MaintenanceFileWaiting]
            == "file-clock.svg"
        && resourceFiles[GuardStatusKind.MaintenanceStabilizing]
            == "file-clock.svg"
        && resourceFiles[GuardStatusKind.Verifying]
            == "scan-search.svg"
        && resourceFiles[GuardStatusKind.MaintenanceArbitrating]
            == "scan-search.svg",
        "时间、升级文件或查询语义没有使用指定的共享 SVG")

    stateObj := TargetSupervisor({Enabled: true,
        StatusKind: GuardStatusKind.Initializing})
    for statusKind in specs {
        stateObj.StatusKind := statusKind
        AssertCustomIcon(GetMainStatusVisualKind(stateObj) == statusKind,
            "细粒度状态视觉键被重新压缩为统计类别：" statusKind)
    }
    stateObj.Enabled := false
    AssertCustomIcon(GetMainStatusVisualKind(stateObj)
            == GuardStatusKind.Paused,
        "暂停硬状态没有覆盖过期视觉键")
    stateObj.Enabled := true
    stateObj.MissingSinceTicks := 1
    stateObj.StatusKind := GuardStatusKind.Initializing
    AssertCustomIcon(GetMainStatusVisualKind(stateObj)
            == GuardStatusKind.TargetMissing,
        "缺失硬状态没有覆盖过期视觉键")

    visualSource := FileRead(A_ScriptDir
        "\..\..\app\UI\MainVisualPipeline.ahk", "UTF-8")
    AssertCustomIcon(InStr(visualSource,
        "CreateSvgPaddedIcon(resourcePath, glyphSize, cellSize, true,"),
        "状态图标没有启用独立的高质量超采样渲染")
    for retiredFunction in ["StatusPointNearSegment", "StatusShapeContains",
        "StatusGlyphContains", "CreateStatusGlyphSnapshot",
        "CreateStatusGlyphIcon"] {
        AssertCustomIcon(!InStr(visualSource, retiredFunction "("),
            "状态图标仍依赖运行时自绘函数：" retiredFunction)
    }

    UiThemeService.Configure("light")
    for statusKind in specs {
        lightColor := GetStatusIconColor(statusKind)
        AssertCustomIcon(GetButtonColorContrastRatio(lightColor,
                UiThemeService.Color("Surface")) >= 3,
            "浅色主题状态图标未达到 3:1 非文本对比度：" statusKind)
    }
    AssertCustomIcon(GetStatusIconColor(GuardStatusKind.PermissionMismatch)
            == "A16207"
        && GetStatusIconColor(GuardStatusKind.SafeStartWait) == "5F9B0D",
        "深浅背景均清晰的状态颜色被无意义替换")
    AssertCustomIcon(GetStatusIconColor(GuardStatusKind.Running) == "157A50"
        && GetStatusIconColor(GuardStatusKind.Paused) == "B45309"
        && GetStatusIconColor(GuardStatusKind.WaitingObservation) == "1D4ED8",
        "浅色主题没有替换低对比度状态颜色")
    UiThemeService.Configure(originalTheme)
}

AssertThemeAwareIconPalette() {
    originalTheme := UiThemeService.GetRequestedTheme()
    darkSourceColors := Map(
        "SettingsIcon", "BABABC", "HelpIcon", "23A9F2",
        "AboutIcon", "B9A3FF", "SearchIcon", "1EA596",
        "BrowseIcon", "93A8EA", "UpdateIcon", "878DF9",
        "DonationIcon", "F78FB3", "LogsIcon", "5DD4E8",
        "AutomationIcon", "B9A3FF", "DisplayIcon", "4EA1FF",
        "LanguageIcon", "4EA1FF", "FontIcon", "43C97B",
        "ThemeIcon", "F0A020", "StartupIcon", "B4875A",
        "MonitoringIcon", "69D19A", "SuccessIcon", "03C078",
        "DangerIcon", "EF4444", "StrongDangerIcon", "FF9A9A",
        "WarningIcon", "FBBF24", "PauseIcon", "F4A71D",
        "WaitingIcon", "A0B7FF", "QueryIcon", "E9C08C",
        "RelocationIcon", "5DD4E8", "UnknownIcon", "858585",
        "InitializingIcon", "0F7EE7")
    try {
        UiThemeService.Configure("dark")
        for role, sourceColor in darkSourceColors {
            AssertCustomIcon(UiThemeService.Color(role) == sourceColor,
                "深色主题无意义地改写了原有清晰图标颜色：" role)
            AssertCustomIcon(GetButtonColorContrastRatio(
                    UiThemeService.Color(role),
                    UiThemeService.Color("Toolbar")) >= 3,
                "深色主题图标与工具栏对比不足：" role)
        }

        UiThemeService.Configure("light")
        for role in darkSourceColors {
            AssertCustomIcon(GetButtonColorContrastRatio(
                    UiThemeService.Color(role),
                    UiThemeService.Color("Toolbar")) >= 3,
                "浅色主题图标与工具栏对比不足：" role)
        }

        sourcePixels := Buffer(4, 0)
        NumPut("UChar", 0x17, sourcePixels, 0)
        NumPut("UChar", 0x31, sourcePixels, 1)
        NumPut("UChar", 0x53, sourcePixels, 2)
        NumPut("UChar", 0x80, sourcePixels, 3)
        sourceSnapshot := {Width: 1, Height: 1, Pixels: sourcePixels}
        iconState := {
            normal: UiThemeService.Color("Toolbar"),
            textColor: UiThemeService.Color("ToolbarText"),
            buttonImage: {
                sourceSnapshot: sourceSnapshot,
                tintMode: "theme",
                tintRole: "SettingsIcon",
                resolvedTint: "source",
                Width: 1,
                Height: 1,
                Pixels: sourcePixels
            }
        }
        AssertCustomIcon(RefreshButtonImageTint(iconState)
            && iconState.buttonImage.resolvedTint
                == UiThemeService.Color("SettingsIcon")
            && iconState.buttonImage.Pixels != sourcePixels,
            "浅色主题没有生成独立的语义色像素")
        UiThemeService.Configure("dark")
        AssertCustomIcon(RefreshButtonImageTint(iconState)
            && iconState.buttonImage.resolvedTint == "source"
            && iconState.buttonImage.Pixels == sourcePixels
            && NumGet(iconState.buttonImage.Pixels, 0, "UInt")
                == NumGet(sourcePixels, 0, "UInt"),
            "切回深色主题后没有逐字节恢复 SVG 原始像素")

        sourcePixels := Buffer(8, 0)
        NumPut("UChar", 255, sourcePixels, 0)
        NumPut("UChar", 255, sourcePixels, 1)
        NumPut("UChar", 255, sourcePixels, 2)
        NumPut("UChar", 255, sourcePixels, 3)
        NumPut("UChar", 128, sourcePixels, 4)
        NumPut("UChar", 128, sourcePixels, 5)
        NumPut("UChar", 128, sourcePixels, 6)
        NumPut("UChar", 128, sourcePixels, 7)
        tinted := TintButtonIconSnapshot(
            {Width: 2, Height: 1, Pixels: sourcePixels}, "112233")
        AssertCustomIcon(tinted
            && NumGet(tinted.Pixels, 0, "UChar") == 0x33
            && NumGet(tinted.Pixels, 1, "UChar") == 0x22
            && NumGet(tinted.Pixels, 2, "UChar") == 0x11
            && NumGet(tinted.Pixels, 3, "UChar") == 0xFF
            && Abs(NumGet(tinted.Pixels, 4, "UChar") - 0x1A) <= 1
            && NumGet(tinted.Pixels, 7, "UChar") == 0x80,
            "主题着色没有保持 SVG 快照的预乘 BGRA 与半透明边缘")
    } finally UiThemeService.Configure(originalTheme)
}

AssertAdminOverlayIcon() {
    previousMetrics := App.iconResources.GetMainIconMetrics()
    try {
        for dpi in [96, 288] {
            App.iconResources.UpdateMainIconMetrics(dpi)
            cellSize := App.iconResources.MainIconCellPixelSize
            badgeSize := Max(12, Round(14 * dpi / 96))
            badgeMargin := Max(1, Round(dpi / 96))
            expectedOffset := cellSize - badgeSize - badgeMargin
            imageList := IL_Create(2, 2, 1)
            iconHandle := 0
            try {
                DllCall("comctl32\ImageList_SetIconSize", "Ptr", imageList,
                    "Int", cellSize, "Int", cellSize)
                AssertCustomIcon(AddMainAdminOverlayIcon(imageList),
                    "Windows 管理员盾牌没有注册为图像列表 overlay：DPI=" dpi)
                imageCount := DllCall("comctl32\ImageList_GetImageCount",
                    "Ptr", imageList, "Int")
                AssertCustomIcon(imageCount == 1,
                    "管理员 overlay 添加了意外的图像数量：DPI=" dpi)
                iconHandle := DllCall("comctl32\ImageList_GetIcon",
                    "Ptr", imageList, "Int", 0,
                    "UInt", Win32.ILD_TRANSPARENT, "Ptr")
                AssertCustomIcon(iconHandle,
                    "无法读取管理员 overlay 图标：DPI=" dpi)
                snapshot := ReadIconPixelSnapshot(iconHandle)
                bounds := GetOpaqueIconRectangle(snapshot)
                AssertCustomIcon(bounds.Right >= bounds.Left
                    && bounds.Bottom >= bounds.Top
                    && bounds.Left >= expectedOffset
                    && bounds.Top >= expectedOffset
                    && bounds.Right < cellSize && bounds.Bottom < cellSize,
                    "Windows 管理员盾牌没有稳定定位在应用图标右下角：DPI=" dpi)
                AssertWindowsAdminShieldColors(snapshot, dpi)
            } finally {
                if iconHandle
                    try DllCall("user32\DestroyIcon", "Ptr", iconHandle)
                if imageList
                    try IL_Destroy(imageList)
            }
        }
        visualSource := FileRead(A_ScriptDir
            "\..\..\app\UI\MainVisualPipeline.ahk", "UTF-8")
        AssertCustomIcon(InStr(visualSource, "SHGetStockIconInfo")
            && InStr(visualSource, "Win32.SIID_SHIELD")
            && InStr(visualSource, "Win32.SHIL_JUMBO"),
            "管理员盾牌没有从 Windows 高分辨率库存图标取得")
    } finally App.iconResources.RestoreMainIconMetrics(previousMetrics)
}

AssertCompleteMainImageList() {
    global Main
    testGui := Gui()
    testList := testGui.Add("ListView", "w480 h220 Report", ["守护对象", "状态"])
    imageList := 0
    Main := {
        gui: testGui,
        lv: testList,
        appIcons: 0,
        statusIconIndices: Map()
    }
    try {
        imageList := CreateMainImageList(Main.statusIconIndices)
        AssertCustomIcon(imageList,
            "完整主图像列表创建失败，ListView 会丢失全部应用和状态图标")
        Main.appIcons := imageList
        testList.SetImageList(imageList, 1)
        testList.IL := imageList
        attachedImageList := SendMessage(Win32.LVM_GETIMAGELIST,
            1, 0, testList.Hwnd)
        AssertCustomIcon(attachedImageList == imageList,
            "主图像列表没有绑定到 ListView 的小图标槽")

        verifiedStatusIndices := Map()
        for statusKind in StatusIconResourceFiles() {
            AssertCustomIcon(Main.statusIconIndices.Has(statusKind)
                && Main.statusIconIndices[statusKind] > 0,
                "状态图标没有进入完整主图像列表：" statusKind)
            statusIconIndex := Main.statusIconIndices[statusKind]
            if verifiedStatusIndices.Has(statusIconIndex)
                continue
            verifiedStatusIndices[statusIconIndex] := true
            statusIconHandle := DllCall("comctl32\ImageList_GetIcon",
                "Ptr", imageList, "Int", statusIconIndex - 1,
                "UInt", Win32.ILD_TRANSPARENT, "Ptr")
            try {
                AssertCustomIcon(statusIconHandle,
                    "无法从完整主图像列表读取状态图标：" statusKind)
                statusSnapshot := ReadIconPixelSnapshot(statusIconHandle)
                statusBounds := GetOpaqueIconRectangle(statusSnapshot)
                AssertCustomIcon(statusBounds.Right >= statusBounds.Left
                    && statusBounds.Bottom >= statusBounds.Top,
                    "完整主图像列表中的状态图标内容为空：" statusKind)
            } finally {
                if statusIconHandle
                    try DllCall("user32\DestroyIcon", "Ptr",
                        statusIconHandle)
            }
        }

        appIconIndex := GetMainListIconIndex(
            A_WinDir "\System32\notepad.exe", "", imageList)
        AssertCustomIcon(appIconIndex > 0,
            "完整主图像列表无法继续加入应用程序图标")
        appIconHandle := DllCall("comctl32\ImageList_GetIcon",
            "Ptr", imageList, "Int", appIconIndex - 1,
            "UInt", Win32.ILD_TRANSPARENT, "Ptr")
        try {
            AssertCustomIcon(appIconHandle,
                "无法从完整主图像列表读取应用程序图标")
            appSnapshot := ReadIconPixelSnapshot(appIconHandle)
            appBounds := GetOpaqueIconRectangle(appSnapshot)
            AssertCustomIcon(appBounds.Right >= appBounds.Left
                && appBounds.Bottom >= appBounds.Top,
                "完整主图像列表中的应用程序图标内容为空")
        } finally {
            if appIconHandle
                try DllCall("user32\DestroyIcon", "Ptr", appIconHandle)
        }
        row := testList.Add("Icon" appIconIndex, "Notepad", "运行中")
        AssertCustomIcon(row > 0
            && SetMainListSubItemIcon(row,
                Main.statusIconIndices[GuardStatusKind.Running])
            && SendMessage(Win32.LVM_GETIMAGELIST,
                1, 0, testList.Hwnd) == imageList,
            "写入应用和状态图标后，ListView 丢失了主图像列表绑定")
        testList.SetImageList(0, 1)
        AssertCustomIcon(SendMessage(Win32.LVM_GETIMAGELIST,
                1, 0, testList.Hwnd) == 0
            && RefreshMainStatusIconAlignment()
            && SendMessage(Win32.LVM_GETIMAGELIST,
                1, 0, testList.Hwnd) == imageList,
            "状态图标刷新没有修复意外丢失的主图像列表绑定")
    } finally {
        try testList.SetImageList(0, 1)
        try testList.IL := 0
        Main.appIcons := 0
        if imageList {
            ClearImageListIconCache(imageList)
            try IL_Destroy(imageList)
        }
        try testGui.Destroy()
    }
}

RunCustomIconImageTests() {
    global App
    App := ApplicationState()
    App.svgRenderer := SvgRenderLibrary(
        A_ScriptDir "\..\..\third_party\resvg\resvg.dll")
    processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    fixtureDirectory := A_Temp "\watchdog-custom-icon-tests-" processId
    DirCreate(fixtureDirectory)
    pngPath := fixtureDirectory "\wide.png"
    jpgPath := fixtureDirectory "\wide.jpg"
    jpegPath := fixtureDirectory "\wide.jpeg"
    bmpPath := fixtureDirectory "\wide.bmp"
    matteBmpPath := fixtureDirectory "\white-matte.bmp"
    svgPath := fixtureDirectory "\wide.svg"
    complexSvgPath := fixtureDirectory "\complex.svg"
    singleFrameIcoPath := fixtureDirectory "\single-32.ico"
    try {
        CreateRasterIconFixture(pngPath,
            "{557CF406-1A04-11D3-9A73-0000F81EF32E}")
        CreateRasterIconFixture(jpgPath,
            "{557CF401-1A04-11D3-9A73-0000F81EF32E}")
        FileCopy(jpgPath, jpegPath, true)
        CreateRasterIconFixture(bmpPath,
            "{557CF400-1A04-11D3-9A73-0000F81EF32E}")
        CreateWhiteMatteBmpFixture(matteBmpPath)
        FileAppend('<svg xmlns="http://www.w3.org/2000/svg" width="96" '
            . 'height="48" viewBox="0 0 96 48">'
            . '<rect x="12" y="8" width="72" height="32" rx="8" '
            . 'fill="#ff1493"/>'
            . '<circle cx="30" cy="24" r="10" fill="#00ddff"/>'
            . '</svg>', svgPath, "UTF-8-RAW")
        FileAppend('<svg xmlns="http://www.w3.org/2000/svg" width="120" '
            . 'height="80" viewBox="0 0 120 80"><defs>'
            . '<linearGradient id="g"><stop stop-color="#ff1744"/>'
            . '<stop offset="1" stop-color="#2979ff"/></linearGradient>'
            . '<mask id="m"><rect width="120" height="80" fill="black"/>'
            . '<circle cx="60" cy="40" r="32" fill="white"/></mask>'
            . '</defs><rect x="8" y="8" width="104" height="64" '
            . 'fill="url(#g)" mask="url(#m)"/>'
            . '<image x="52" y="32" width="16" height="16" '
            . 'href="data:image/png;base64,'
            . 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQ'
            . 'IHWP4z8DwHwAFgAI/ScL1AAAAABJRU5ErkJggg=="/>'
            . '</svg>', complexSvgPath, "UTF-8-RAW")
        CreateSingleFrameIcoFixture(A_ScriptDir
            "\..\..\assets\app\watchdog.ico", singleFrameIcoPath, 32)

        missingRenderer := SvgRenderLibrary(
            fixtureDirectory "\missing-resvg.dll")
        AssertCustomIcon(!missingRenderer.IsAvailable()
            && !missingRenderer.RenderFile(svgPath, 96, 128),
            "resvg.dll 缺失时没有安全返回降级信号")

        for filePath in [pngPath, jpgPath, jpegPath, bmpPath]
            AssertPaddedCustomIcon(filePath)
        AssertBmpMatteRemoved(matteBmpPath)
        AssertPaddedCustomIcon(svgPath, true, true)
        AssertNativeSvgRasterization(svgPath, 2.0)
        AssertNativeSvgRasterization(complexSvgPath, 1.5)
        externalSvgPath := EnvGet("WATCHDOG_EXTERNAL_SVG_TEST")
        if externalSvgPath != "" && FileExist(externalSvgPath) {
            AssertPaddedCustomIcon(externalSvgPath, false)
            AssertNativeSvgRasterization(externalSvgPath)
        }
        AssertIndexedIconResourceSelection(singleFrameIcoPath)
        AssertThemeAwareIconPalette()
        AssertStatusIconResources()
        AssertAdminOverlayIcon()
        AssertCompleteMainImageList()

        genericPixels := Buffer(8 * 8 * 4, 0)
        Loop 8 * 8
            NumPut("UInt", 0xFFFFFFFF, genericPixels,
                (A_Index - 1) * 4)
        genericSnapshot := {Width: 8, Height: 8, Pixels: genericPixels}
        AssertCustomIcon(!RecoverSvgPixelsFromBackdrops(genericSnapshot,
            genericSnapshot),
            "内容无差异的 Shell 白页图标被误认为 SVG 渲染结果")

        animatedCursorPath := A_WinDir "\Cursors\aero_busy.ani"
        if FileExist(animatedCursorPath)
            AssertPaddedCustomIcon(animatedCursorPath, false)

        for supportedPath in ["sample.PNG", "sample.jpg", "sample.JPEG",
            "sample.bmp", "sample.svg", "sample.ani", "sample.ico",
            "sample.exe", "sample.dll", "sample.cpl", "sample.lnk"]
            AssertCustomIcon(IsSupportedCustomIconSource(supportedPath),
                "受支持的自定义图标扩展名被拒绝：" supportedPath)
        AssertCustomIcon(!IsSupportedCustomIconSource("sample.txt")
            && !IsSupportedCustomIconSource("sample.svg.exe.txt"),
            "不受支持的扩展名被误判为图标来源")
    } finally {
        try App.svgRenderer.Shutdown()
        ShutdownIconResampler()
        ; 主脚本的统一退出协调器负责关闭共享 GDI+ 令牌。
        try DirDelete(fixtureDirectory, true)
    }
}

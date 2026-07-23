#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

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

AssertStatusIconColor(snapshot, statusKind, expectedRgb) {
    expectedRed := (expectedRgb >> 16) & 0xFF
    expectedGreen := (expectedRgb >> 8) & 0xFF
    expectedBlue := expectedRgb & 0xFF
    opaqueColorPixels := 0
    opaqueWhitePixels := 0
    brightGlyphPixels := 0
    brightestMinimumChannel := 0
    outerLeft := snapshot.Width
    outerTop := snapshot.Height
    outerRight := -1
    outerBottom := -1
    glyphLeft := snapshot.Width
    glyphTop := snapshot.Height
    glyphRight := -1
    glyphBottom := -1
    Loop snapshot.Width * snapshot.Height {
        offset := (A_Index - 1) * 4
        alpha := NumGet(snapshot.Pixels, offset + 3, "UChar")
        x := Mod(A_Index - 1, snapshot.Width)
        y := Floor((A_Index - 1) / snapshot.Width)
        if alpha >= 32 {
            outerLeft := Min(outerLeft, x)
            outerTop := Min(outerTop, y)
            outerRight := Max(outerRight, x)
            outerBottom := Max(outerBottom, y)
        }
        if alpha < 240
            continue
        blue := Round(NumGet(snapshot.Pixels, offset, "UChar") * 255 / alpha)
        green := Round(NumGet(snapshot.Pixels,
            offset + 1, "UChar") * 255 / alpha)
        red := Round(NumGet(snapshot.Pixels,
            offset + 2, "UChar") * 255 / alpha)
        isBaseColor := Abs(red - expectedRed) <= 8
            && Abs(green - expectedGreen) <= 8
            && Abs(blue - expectedBlue) <= 8
        ; 20px WIC 缩小会把细白色笔画与彩色底层混合；238 以上在
        ; sRGB 中仍属于视觉白色，同时资源源码另行断言为 #FFFFFF。
        isWhite := red >= 238 && green >= 238 && blue >= 238
        brightestMinimumChannel := Max(brightestMinimumChannel,
            Min(red, green, blue))
        isAntialiasedBlend := red >= expectedRed - 8
            && green >= expectedGreen - 8 && blue >= expectedBlue - 8
        AssertCustomIcon(isBaseColor || isWhite || isAntialiasedBlend,
            "状态 SVG 的颜色与资源规格不一致：" statusKind
                "（实际 RGB=" red "," green "," blue
                "；预期 RGB=" expectedRed "," expectedGreen ","
                expectedBlue "）")
        if isBaseColor
            opaqueColorPixels++
        if isWhite
            opaqueWhitePixels++
        if Min(red, green, blue) >= 200 {
            brightGlyphPixels++
            glyphLeft := Min(glyphLeft, x)
            glyphTop := Min(glyphTop, y)
            glyphRight := Max(glyphRight, x)
            glyphBottom := Max(glyphBottom, y)
        }
    }
    AssertCustomIcon(opaqueColorPixels >= 12,
        "状态 SVG 缺少清晰的彩色主体：" statusKind)
    AssertCustomIcon(opaqueWhitePixels >= 1 && brightGlyphPixels >= 4,
        "状态 SVG 的语义符号没有使用不透明白色：" statusKind
            "（纯白像素=" opaqueWhitePixels "，高亮像素="
            brightGlyphPixels "，最高最低通道=" brightestMinimumChannel "）")
    AssertCustomIcon(glyphRight >= glyphLeft
        && glyphLeft > outerLeft && glyphTop > outerTop
        && glyphRight < outerRight && glyphBottom < outerBottom,
        "状态 SVG 的彩色容器没有完整包裹白色语义符号：" statusKind)
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

AssertIndexedIconResourceSelection() {
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
    circularStatuses := Map(
        "Paused", true,
        "Error", true,
        "Pending", true,
        "Countdown", true,
        "Updating", true,
        "Idle", true)
    specs := Map(
        "Running", {Color: 0x2FBF71, File: "running.svg", Scale: 1.00},
        "Paused", {Color: 0xC9902E, File: "paused.svg", Scale: 1.10},
        "Warning", {Color: 0xE5B73B, File: "warning.svg", Scale: 1.10},
        "SuspectedStop", {Color: 0xF07A3E, File: "suspected-stop.svg", Scale: 1.16},
        "Error", {Color: 0xDC5666, File: "error.svg", Scale: 1.10},
        "Pending", {Color: 0x3D8FE3, File: "pending.svg", Scale: 1.10},
        "Countdown", {Color: 0x20A7B9, File: "countdown.svg", Scale: 1.10},
        "Updating", {Color: 0x8D6AD8, File: "updating.svg", Scale: 1.10},
        "Idle", {Color: 0x718096, File: "idle.svg", Scale: 1.10})
    resourceFiles := StatusIconResourceFiles()
    AssertCustomIcon(resourceFiles.Count == specs.Count,
        "状态图标资源映射数量不完整")
    seenColors := Map()
    for statusKind, spec in specs {
        colorKey := Format("{:06X}", spec.Color)
        AssertCustomIcon(!seenColors.Has(colorKey),
            "不同状态重复使用了相同颜色：" statusKind)
        seenColors[colorKey] := statusKind
        AssertCustomIcon(resourceFiles.Has(statusKind)
            && resourceFiles[statusKind] == spec.File,
            "状态图标资源映射错误：" statusKind)
        AssertCustomIcon(StatusIconVisualScale(statusKind) == spec.Scale,
            "状态图标视觉面积补偿错误：" statusKind)
        resourcePath := GetStatusIconResourcePath(statusKind)
        AssertCustomIcon(FileExist(resourcePath),
            "状态 SVG 资源不存在：" resourcePath)
        svgText := FileRead(resourcePath, "UTF-8")
        expectedFill := 'fill="#' Format("{:06X}", spec.Color) '"'
        AssertCustomIcon(InStr(svgText, 'data-design="watchdog-status-v2"')
            && InStr(svgText, expectedFill)
            && (InStr(svgText, 'fill="#FFFFFF"')
                || InStr(svgText, 'stroke="#FFFFFF"'))
            && (InStr(svgText, "<path ") || InStr(svgText, "<circle ")
                || InStr(svgText, "<rect ")),
            "状态 SVG 缺少重绘版标记、矢量图元或预期颜色：" statusKind)
        if circularStatuses.Has(statusKind)
            AssertCustomIcon(InStr(svgText,
                '<circle cx="32" cy="32" r="29" fill="'
                    SubStr(expectedFill, 7)),
                "圆形状态没有使用精确 SVG 圆形图元：" statusKind)

        visualSize := Round(20 * spec.Scale)
        iconHandle := CreateStatusResourceIcon(statusKind, visualSize, 36)
        AssertCustomIcon(iconHandle, "无法从 SVG 创建状态图标：" statusKind)
        try {
            snapshot := ReadIconPixelSnapshot(iconHandle)
            bounds := GetOpaqueIconBounds(snapshot)
            AssertStatusIconColor(snapshot, statusKind, spec.Color)
            minimumVisibleEdge := statusKind == "SuspectedStop" ? 17 : 18
            minimumMaximumEdge := statusKind == "Running" ? 18 : 20
            AssertCustomIcon(bounds.Width >= minimumVisibleEdge
                && bounds.Height >= minimumVisibleEdge
                && Max(bounds.Width, bounds.Height) >= minimumMaximumEdge
                && bounds.Width <= visualSize && bounds.Height <= visualSize,
                "状态 SVG 的视觉补偿尺寸不在预期范围内：" statusKind)
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

    visualSource := FileRead(A_ScriptDir
        "\..\..\app\UI\MainVisualPipeline.ahk", "UTF-8")
    AssertCustomIcon(InStr(visualSource,
        "CreateSvgPaddedIcon(resourcePath, glyphSize, cellSize, true)"),
        "状态图标没有启用独立的高质量超采样渲染")
    for retiredFunction in ["StatusPointNearSegment", "StatusShapeContains",
        "StatusGlyphContains", "CreateStatusGlyphSnapshot",
        "CreateStatusGlyphIcon"] {
        AssertCustomIcon(!InStr(visualSource, retiredFunction "("),
            "状态图标仍依赖运行时自绘函数：" retiredFunction)
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
        AssertIndexedIconResourceSelection()
        AssertStatusIconResources()

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

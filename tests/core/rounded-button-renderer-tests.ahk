#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证圆角按钮绘制器在常态、悬浮、按下和不可用状态下的资源与颜色契约。
; 测试聚焦无边框绘制和句柄清理，不依赖人工观察屏幕截图。

try {
    RunRoundedButtonRendererTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertRoundedButtonRenderer(condition, message) {
    if !condition
        throw Error(message)
}

AssertRoundedButtonSurfaceColor(color) {
    testGui := Gui("+ToolWindow")
    button := testGui.Add("Text", "w80 h30")
    state := {
        ctrl: button,
        normal: color,
        current: color,
        textColor: UiThemeService.Color("DisabledButtonText"),
        textAlign: "center",
        textInsetDip: 4
    }
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    targetDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", screenDc, "Ptr") : 0
    targetBitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
        "Ptr", screenDc, "Int", 80, "Int", 30, "Ptr") : 0
    previousBitmap := 0
    try {
        AssertRoundedButtonRenderer(screenDc && targetDc && targetBitmap,
            "无法创建按钮像素验证画布")
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
            "Ptr", targetBitmap, "Ptr")
        AssertRoundedButtonRenderer(
            RoundedButtonRenderer.Draw(targetDc, 80, 30, state),
            "无法绘制浅色主题不可用按钮")
        actualColor := DllCall("gdi32\GetPixel", "Ptr", targetDc,
            "Int", 40, "Int", 15, "UInt")
        expectedColor := RoundedButtonRenderer.ColorToBgr(color)
        AssertRoundedButtonRenderer(actualColor == expectedColor,
            "圆角按钮实际表面颜色与不可用状态色不一致：" color)
    } finally {
        if previousBitmap
            try DllCall("gdi32\SelectObject", "Ptr", targetDc,
                "Ptr", previousBitmap)
        if targetBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", targetBitmap)
        if targetDc
            try DllCall("gdi32\DeleteDC", "Ptr", targetDc)
        if screenDc
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
        try testGui.Destroy()
    }
}

AssertRoundedSelectionMask() {
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    targetDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", screenDc, "Ptr") : 0
    targetBitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
        "Ptr", screenDc, "Int", 120, "Int", 40, "Ptr") : 0
    previousBitmap := 0
    selectionBrush := 0
    try {
        AssertRoundedButtonRenderer(screenDc && targetDc && targetBitmap,
            "无法创建圆角选中态像素验证画布")
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
            "Ptr", targetBitmap, "Ptr")
        selectionColor := "264F78"
        surfaceColor := UiThemeService.Color("Surface")
        selectionBrush := DllCall("gdi32\CreateSolidBrush", "UInt",
            RoundedButtonRenderer.ColorToBgr(selectionColor), "Ptr")
        canvasRect := Buffer(16, 0)
        NumPut("Int", 120, canvasRect, 8)
        NumPut("Int", 40, canvasRect, 12)
        DllCall("user32\FillRect", "Ptr", targetDc, "Ptr", canvasRect,
            "Ptr", selectionBrush)
        AssertRoundedButtonRenderer(
            RoundedButtonRenderer.MaskOutsideRoundedRectangle(targetDc,
                0, 0, 120, 40, 4, 2, 116, 38, surfaceColor, 7),
            "无法绘制 ListView 圆角选中态遮罩")
        cornerColor := DllCall("gdi32\GetPixel", "Ptr", targetDc,
            "Int", 1, "Int", 1, "UInt")
        centerColor := DllCall("gdi32\GetPixel", "Ptr", targetDc,
            "Int", 60, "Int", 20, "UInt")
        AssertRoundedButtonRenderer(cornerColor
                == RoundedButtonRenderer.ColorToBgr(surfaceColor)
            && centerColor
                == RoundedButtonRenderer.ColorToBgr(selectionColor),
            "圆角遮罩没有擦除方形选中态的角落，或覆盖了中央内容区域")
    } finally {
        if selectionBrush
            DllCall("gdi32\DeleteObject", "Ptr", selectionBrush)
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", targetDc,
                "Ptr", previousBitmap)
        if targetBitmap
            DllCall("gdi32\DeleteObject", "Ptr", targetBitmap)
        if targetDc
            DllCall("gdi32\DeleteDC", "Ptr", targetDc)
        if screenDc
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
    }
}

AssertRoundedButtonSvgImage() {
    svgPath := GetApplicationAssetPath("ui-icons\external-link.svg")
    renderer := SvgRenderLibrary(A_ScriptDir
        "\..\..\third_party\resvg\resvg.dll")
    testGui := Gui("+ToolWindow")
    button := testGui.Add("Text", "w96 h40", "")
    screenDc := 0
    targetDc := 0
    targetBitmap := 0
    previousBitmap := 0
    try {
        snapshot := renderer.RenderFile(svgPath, 96, 128)
        AssertRoundedButtonRenderer(IsObject(snapshot)
            && snapshot.Width == 128 && snapshot.Height == 128,
            "外链 SVG 未生成正方形透明像素快照")
        cachedSnapshot := renderer.RenderFile(svgPath, 96, 128)
        AssertRoundedButtonRenderer(IsObject(cachedSnapshot)
            && cachedSnapshot.Pixels.Ptr == snapshot.Pixels.Ptr
            && renderer.RenderCache.Count == 1,
            "相同 SVG／DPI／尺寸没有复用像素快照缓存")
        state := {
            ctrl: button,
            normal: UiThemeService.Color("Toolbar"),
            current: UiThemeService.Color("Toolbar"),
            textColor: UiThemeService.Color("ToolbarText"),
            textAlign: "center",
            textInsetDip: 4,
            buttonImage: {
                Width: snapshot.Width,
                Height: snapshot.Height,
                Pixels: snapshot.Pixels,
                sizeDip: 14,
                gapDip: 7
            }
        }
        screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
        targetDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
            "Ptr", screenDc, "Ptr") : 0
        targetBitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
            "Ptr", screenDc, "Int", 96, "Int", 40, "Ptr") : 0
        AssertRoundedButtonRenderer(screenDc && targetDc && targetBitmap,
            "无法创建 SVG 按钮像素验证画布")
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
            "Ptr", targetBitmap, "Ptr")
        AssertRoundedButtonRenderer(
            RoundedButtonRenderer.Draw(targetDc, 96, 40, state),
            "无法绘制带 SVG 图标的圆角按钮")

        backgroundColor := RoundedButtonRenderer.ColorToBgr(
            UiThemeService.Color("Toolbar"))
        AssertRoundedButtonRenderer(DllCall("gdi32\GetPixel", "Ptr", targetDc,
            "Int", 24, "Int", 20, "UInt") == backgroundColor,
            "SVG 透明区域覆盖了按钮原有背景")
        changedPixelCount := 0
        blackPixelCount := 0
        Loop 14 {
            y := 13 + A_Index - 1
            Loop 14 {
                x := 41 + A_Index - 1
                pixelColor := DllCall("gdi32\GetPixel", "Ptr", targetDc,
                    "Int", x, "Int", y, "UInt")
                if pixelColor != backgroundColor
                    changedPixelCount++
                if pixelColor == 0
                    blackPixelCount++
            }
        }
        AssertRoundedButtonRenderer(changedPixelCount >= 24,
            "SVG 外链图形没有实际绘制到按钮表面")
        AssertRoundedButtonRenderer(blackPixelCount == 0,
            "SVG 透明合成在按钮上产生了黑色背景或黑边")
    } finally {
        if previousBitmap
            try DllCall("gdi32\SelectObject", "Ptr", targetDc,
                "Ptr", previousBitmap)
        if targetBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", targetBitmap)
        if targetDc
            try DllCall("gdi32\DeleteDC", "Ptr", targetDc)
        if screenDc
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
        renderer.Shutdown()
        try testGui.Destroy()
    }
}

AssertVisualTextCenter(fontName, pointSize, fontWeight, dpi, text) {
    width := Max(160, Round(160 * dpi / 96))
    height := Max(40, Round(40 * dpi / 96))
    pixelHeight := Max(1, Round(pointSize * dpi / 72))
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    targetDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", screenDc, "Ptr") : 0
    targetBitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
        "Ptr", screenDc, "Int", width, "Int", height, "Ptr") : 0
    fontHandle := DllCall("gdi32\CreateFontW",
        "Int", -pixelHeight, "Int", 0, "Int", 0, "Int", 0,
        "Int", fontWeight, "UInt", 0, "UInt", 0, "UInt", 0,
        "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0,
        "UInt", 0, "Str", fontName, "Ptr")
    previousBitmap := 0
    previousFont := 0
    try {
        AssertRoundedButtonRenderer(screenDc && targetDc && targetBitmap
            && fontHandle, "无法创建字形视觉中心验证画布")
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
            "Ptr", targetBitmap, "Ptr")
        previousFont := DllCall("gdi32\SelectObject", "Ptr", targetDc,
            "Ptr", fontHandle, "Ptr")
        DllCall("gdi32\PatBlt", "Ptr", targetDc, "Int", 0, "Int", 0,
            "Int", width, "Int", height, "UInt", 0x00000042, "Int")
        DllCall("gdi32\SetBkMode", "Ptr", targetDc, "Int", 1)
        DllCall("gdi32\SetTextColor", "Ptr", targetDc,
            "UInt", 0x00FFFFFF)
        textRect := TextVisualAlignment.CreateCenteredTextRect(targetDc,
            text, 0, 0, width, height)
        DllCall("user32\DrawTextW", "Ptr", targetDc, "Str", text,
            "Int", -1, "Ptr", textRect, "UInt", 0x00000825, "Int")

        minimumY := height
        maximumY := -1
        Loop height {
            y := A_Index - 1
            Loop width {
                x := A_Index - 1
                if DllCall("gdi32\GetPixel", "Ptr", targetDc,
                        "Int", x, "Int", y, "UInt") != 0 {
                    minimumY := Min(minimumY, y)
                    maximumY := Max(maximumY, y)
                }
            }
        }
        AssertRoundedButtonRenderer(maximumY >= minimumY,
            "视觉中心验证没有绘制出文字像素：" text)
        visibleCenter := (minimumY + maximumY + 1) / 2
        AssertRoundedButtonRenderer(Abs(visibleCenter - height / 2) <= 1,
            "文字可见墨迹未居中：DPI=" dpi "，偏差="
                Round(visibleCenter - height / 2, 2))
    } finally {
        if previousFont
            DllCall("gdi32\SelectObject", "Ptr", targetDc,
                "Ptr", previousFont)
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", targetDc,
                "Ptr", previousBitmap)
        if fontHandle
            DllCall("gdi32\DeleteObject", "Ptr", fontHandle)
        if targetBitmap
            DllCall("gdi32\DeleteObject", "Ptr", targetBitmap)
        if targetDc
            DllCall("gdi32\DeleteDC", "Ptr", targetDc)
        if screenDc
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
    }
}

AssertTextVisualAlignment() {
    TextVisualAlignment.InkBoundsCache.Clear()
    systemFont := LocalizationService.GetLanguageSystemUiFontName()
    AssertVisualTextCenter(systemFont, 10, 700, 96, Tr("帮助信息"))
    AssertVisualTextCenter(systemFont, 10, 700, 288, Tr("帮助信息"))
    AssertVisualTextCenter("Segoe UI", 10, 700, 96, "Settings")
    cachedCount := TextVisualAlignment.InkBoundsCache.Count
    delta := TextVisualAlignment.MeasureFontInkCenterDelta(
        systemFont, 12, 400, 96,
        Trim(StrReplace(Tr("✅ 运行中"), "✅", "")))
    AssertRoundedButtonRenderer(IsNumber(delta),
        "ListView 状态图标未获得有效的字体视觉中心偏移")
    AssertRoundedButtonRenderer(cachedCount > 0
        && TextVisualAlignment.InkBoundsCache.Count >= cachedCount,
        "字形视觉中心缓存没有复用已测量字体与文本")
}

AssertLucideSvgAssets() {
    renderer := SvgRenderLibrary(A_ScriptDir
        "\..\..\third_party\resvg\resvg.dll")
    iconDirectory := GetApplicationAssetPath("ui-icons\lucide")
    expectedFiles := [
        "activity.svg", "ban.svg", "book-open.svg", "circle-check-big.svg",
        "circle-info-unknown.svg", "circle-info.svg",
        "circle-pause.svg", "circle-question-mark.svg", "circle-x.svg",
        "file-clock.svg", "file-code-2.svg", "file-x-2.svg",
        "folder-open.svg", "heart.svg", "hourglass.svg",
        "loader-circle.svg", "logs.svg", "message-square-text.svg",
        "octagon-x.svg", "package-open.svg", "play.svg",
        "power.svg",
        "refresh-cw-action.svg", "refresh-cw.svg",
        "repeat-2.svg", "rocket.svg",
        "rotate-ccw.svg",
        "scan-search.svg", "search.svg",
        "settings.svg", "shield-alert.svg", "shield-ellipsis.svg",
        "sliders-horizontal.svg", "square-plus.svg",
        "target.svg", "timer.svg", "trash-2.svg",
        "triangle-alert-red.svg", "triangle-alert-timeout.svg",
        "triangle-alert.svg", "undo-2.svg", "wand-sparkles.svg"
    ]
    try {
        for fileName in expectedFiles {
            filePath := iconDirectory "\" fileName
            AssertRoundedButtonRenderer(FileExist(filePath)
                && !DirExist(filePath), "Lucide SVG 资源缺失：" fileName)
            for probe in [{Dpi: 96, Size: 64}, {Dpi: 288, Size: 192}] {
                snapshot := renderer.RenderFile(filePath, probe.Dpi,
                    probe.Size)
                AssertRoundedButtonRenderer(IsObject(snapshot)
                    && snapshot.Width == probe.Size
                    && snapshot.Height == probe.Size
                    && snapshot.Pixels.Size
                        == probe.Size * probe.Size * 4,
                    fileName " 未在 DPI=" probe.Dpi
                        " 探针中生成完整透明像素")
                visiblePixels := 0
                transparentPixels := 0
                Loop snapshot.Width * snapshot.Height {
                    alpha := NumGet(snapshot.Pixels,
                        (A_Index - 1) * 4 + 3, "UChar")
                    if alpha
                        visiblePixels++
                    else
                        transparentPixels++
                }
                AssertRoundedButtonRenderer(visiblePixels > 0
                    && transparentPixels > 0,
                    fileName " 缺少可见描边或透明背景")
            }
        }
    } finally renderer.Shutdown()
}

RunRoundedButtonRendererTests() {
    AssertRoundedButtonRenderer(RoundedButtonRenderer.EnsureStarted(),
        "GDI+ 按钮渲染器无法初始化")
    AssertRoundedButtonRenderer(RoundedButtonRenderer.token != 0,
        "GDI+ 初始化后没有保存令牌")
    AssertRoundedButtonRenderer(RoundedButtonRenderer.moduleHandle != 0,
        "GDI+ 初始化期间没有持有模块引用")
    RoundedButtonRenderer.Shutdown()
    AssertRoundedButtonRenderer(RoundedButtonRenderer.token == 0,
        "GDI+ 按钮渲染器关闭后没有清空令牌")
    AssertRoundedButtonRenderer(RoundedButtonRenderer.moduleHandle == 0,
        "GDI+ 按钮渲染器关闭后没有释放模块引用")
    AssertRoundedButtonRenderer(RoundedButtonRenderer.EnsureStarted(),
        "GDI+ 按钮渲染器关闭后无法重新初始化")
    UiThemeService.Configure("light")
    AssertRoundedButtonSurfaceColor(UiThemeService.Color("DeleteDisabled"))
    AssertRoundedButtonSurfaceColor(UiThemeService.Color("PauseDisabled"))
    AssertRoundedSelectionMask()
    AssertRoundedButtonSvgImage()
    AssertTextVisualAlignment()
    AssertLucideSvgAssets()
    RoundedButtonRenderer.Shutdown()
}

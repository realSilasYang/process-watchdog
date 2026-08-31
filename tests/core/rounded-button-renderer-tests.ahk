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

AssertCenteredClearMark() {
    width := 24
    height := 24
    testGui := Gui("+ToolWindow")
    button := testGui.Add("Text", "w24 h24", "✕")
    state := {
        ctrl: button,
        normal: "000000",
        current: "000000",
        parentColor: "000000",
        textColor: "FFFFFF",
        textAlign: "center",
        textInsetDip: 0,
        clearMarkSizeDip: 16,
        clearMarkStrokeDip: 2
    }
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    targetDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", screenDc, "Ptr") : 0
    targetBitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
        "Ptr", screenDc, "Int", width, "Int", height, "Ptr") : 0
    previousBitmap := 0
    try {
        AssertRoundedButtonRenderer(screenDc && targetDc && targetBitmap,
            "无法创建清除标记像素验证画布")
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
            "Ptr", targetBitmap, "Ptr")
        AssertRoundedButtonRenderer(
            RoundedButtonRenderer.Draw(targetDc, width, height, state),
            "无法绘制清除标记")

        minimumX := width
        minimumY := height
        maximumX := -1
        maximumY := -1
        visiblePixels := 0
        Loop height {
            y := A_Index - 1
            Loop width {
                x := A_Index - 1
                if DllCall("gdi32\GetPixel", "Ptr", targetDc,
                        "Int", x, "Int", y, "UInt") == 0
                    continue
                minimumX := Min(minimumX, x)
                minimumY := Min(minimumY, y)
                maximumX := Max(maximumX, x)
                maximumY := Max(maximumY, y)
                visiblePixels++
            }
        }
        centerX := (minimumX + maximumX) / 2
        centerY := (minimumY + maximumY) / 2
        AssertRoundedButtonRenderer(visiblePixels > 0
                && Abs(centerX - width / 2) <= 1
                && Abs(centerY - height / 2) <= 1,
            "清除标记的可见边界没有与按钮几何中心对齐")
        AssertRoundedButtonRenderer(minimumX >= 2 && minimumY >= 2
                && maximumX <= width - 3 && maximumY <= height - 3,
            "清除标记没有保留稳定的四周留白")
    } finally {
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", targetDc,
                "Ptr", previousBitmap)
        if targetBitmap
            DllCall("gdi32\DeleteObject", "Ptr", targetBitmap)
        if targetDc
            DllCall("gdi32\DeleteDC", "Ptr", targetDc)
        if screenDc
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
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

MeasureLeadingCommandSymbolPixels(symbol) {
    width := 40
    height := 30
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    targetDc := screenDc ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", screenDc, "Ptr") : 0
    targetBitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
        "Ptr", screenDc, "Int", width, "Int", height, "Ptr") : 0
    previousBitmap := 0
    backgroundBrush := 0
    try {
        AssertRoundedButtonRenderer(screenDc && targetDc && targetBitmap,
            "无法创建状态按钮符号像素画布")
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
            "Ptr", targetBitmap, "Ptr")
        backgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", 0,
            "Ptr")
        canvasRect := Buffer(16, 0)
        NumPut("Int", width, canvasRect, 8)
        NumPut("Int", height, canvasRect, 12)
        DllCall("user32\FillRect", "Ptr", targetDc, "Ptr", canvasRect,
            "Ptr", backgroundBrush)
        AssertRoundedButtonRenderer(
            RoundedButtonRenderer.DrawLeadingCommandSymbol(targetDc, symbol,
                10, 0, 30, height, "FFFFFF", 10),
            "无法绘制状态按钮符号：" symbol)

        minimumX := width
        minimumY := height
        maximumX := -1
        maximumY := -1
        visiblePixels := 0
        Loop height {
            y := A_Index - 1
            Loop width {
                x := A_Index - 1
                if DllCall("gdi32\GetPixel", "Ptr", targetDc,
                        "Int", x, "Int", y, "UInt") == 0
                    continue
                minimumX := Min(minimumX, x)
                minimumY := Min(minimumY, y)
                maximumX := Max(maximumX, x)
                maximumY := Max(maximumY, y)
                visiblePixels++
            }
        }
        AssertRoundedButtonRenderer(visiblePixels > 0,
            "状态按钮符号没有可见像素：" symbol)
        return {
            Left: minimumX,
            Top: minimumY,
            Right: maximumX,
            Bottom: maximumY,
            Width: maximumX - minimumX + 1,
            Height: maximumY - minimumY + 1,
            CenterX: (minimumX + maximumX) / 2,
            CenterY: (minimumY + maximumY) / 2,
            PixelCount: visiblePixels
        }
    } finally {
        if backgroundBrush
            DllCall("gdi32\DeleteObject", "Ptr", backgroundBrush)
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

AssertLeadingCommandSymbolGeometry() {
    referenceBounds := MeasureLeadingCommandSymbolPixels("▶")
    for symbol in ["⏸", "▶"] {
        bounds := symbol == "▶" ? referenceBounds
            : MeasureLeadingCommandSymbolPixels(symbol)
        weightRatio := bounds.PixelCount / referenceBounds.PixelCount
        AssertRoundedButtonRenderer(
            Abs(bounds.Width - referenceBounds.Width) <= 1
                && Abs(bounds.Height - referenceBounds.Height) <= 1,
            "主命令按钮符号的外接尺寸不一致：" symbol)
        AssertRoundedButtonRenderer(
            Abs(bounds.CenterX - referenceBounds.CenterX) <= 0.5
                && Abs(bounds.CenterY - referenceBounds.CenterY) <= 0.5,
            "主命令按钮符号的可见中心不一致：" symbol)
        AssertRoundedButtonRenderer(weightRatio >= 0.7
                && weightRatio <= 1.4,
            "主命令按钮符号的视觉重量差异过大：" symbol "／"
                weightRatio)
    }
}

AssertVisualTextCenter(fontName, pointSize, fontWeight, dpi, text,
    useRasterMeasurement := false) {
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
        textRect := useRasterMeasurement
            ? TextVisualAlignment.CreateRasterCenteredTextRect(targetDc,
                text, 0, 0, width, height)
            : TextVisualAlignment.CreateCenteredTextRect(targetDc,
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
    TextVisualAlignment.RasterInkBoundsCache.Clear()
    systemFont := LocalizationService.GetLanguageSystemUiFontName()
    AssertVisualTextCenter(systemFont, 10, 700, 96, Tr("帮助"))
    AssertVisualTextCenter(systemFont, 10, 700, 288, Tr("帮助"))
    AssertVisualTextCenter("Segoe UI", 10, 700, 96, "Settings")
    AssertVisualTextCenter(systemFont, 10, 700, 96, "➕", true)
    AssertVisualTextCenter(systemFont, 10, 700, 288, "🗑️", true)
    rasterCachedCount := TextVisualAlignment.RasterInkBoundsCache.Count
    AssertVisualTextCenter(systemFont, 10, 700, 288, "🗑️", true)
    cachedCount := TextVisualAlignment.InkBoundsCache.Count
    delta := TextVisualAlignment.MeasureFontInkCenterDelta(
        systemFont, 12, 400, 96,
        Trim(StrReplace(Tr("✅ 运行中"), "✅", "")))
    AssertRoundedButtonRenderer(IsNumber(delta),
        "ListView 状态图标未获得有效的字体视觉中心偏移")
    AssertRoundedButtonRenderer(cachedCount > 0
        && TextVisualAlignment.InkBoundsCache.Count >= cachedCount,
        "字形视觉中心缓存没有复用已测量字体与文本")
    AssertRoundedButtonRenderer(rasterCachedCount >= 2
        && TextVisualAlignment.RasterInkBoundsCache.Count
            == rasterCachedCount,
        "回退字符图标的栅格墨迹缓存没有复用已测量字体与文本")
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
        "triangle-alert-red.svg",
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

ReadAccessibleButtonProperties(hwnd) {
    accessibleIid := ControlAccessibilityService.CreateGuid(
        "{618736E0-3C3D-11CF-810C-00AA00389B71}")
    accessible := 0
    if DllCall("oleacc\AccessibleObjectFromWindow", "Ptr", hwnd,
        "UInt", ControlAccessibilityService.ObjectIdClient, "Ptr",
        accessibleIid, "Ptr*", &accessible, "Int") < 0 || !accessible
        throw Error("无法读取按钮的 Windows 辅助功能对象")
    childVariant := ControlAccessibilityService.CreateIntegerVariant(0)
    name := 0
    action := 0
    roleVariant := Buffer(24, 0)
    try {
        nameResult := ComCall(10, accessible, "Ptr", childVariant,
            "Ptr*", &name, "Int")
        roleResult := ComCall(13, accessible, "Ptr", childVariant,
            "Ptr", roleVariant, "Int")
        actionResult := ComCall(20, accessible, "Ptr", childVariant,
            "Ptr*", &action, "Int")
        return {
            NameResult: nameResult,
            Name: name ? StrGet(name, "UTF-16") : "",
            RoleResult: roleResult,
            RoleVariantType: NumGet(roleVariant, 0, "UShort"),
            Role: NumGet(roleVariant, 8, "Int"),
            ActionResult: actionResult,
            DefaultAction: action ? StrGet(action, "UTF-16") : ""
        }
    } finally {
        if name
            DllCall("oleaut32\SysFreeString", "Ptr", name)
        if action
            DllCall("oleaut32\SysFreeString", "Ptr", action)
        ObjRelease(accessible)
    }
}

AccessibilityTestButtonClick(*) {
    global accessibilityTestClickCount
    accessibilityTestClickCount++
}

AssertRoundedButtonAccessibility() {
    global App, accessibilityTestClickCount
    App := {uiInteractions: UiInteractionRegistry()}
    LocalizationService.Configure("zh-CN")
    UiThemeService.Configure("light")
    testGui := Gui("+ToolWindow", "Accessibility test")
    firstButton := testGui.Add("Text", "x12 y12 w130 h34 +0x100",
        "初始按钮名称")
    secondButton := testGui.Add("Text", "x12 y54 w130 h34 +0x100",
        "第二个按钮")
    accessibilityTestClickCount := 0
    try {
        RegisterHoverButton(firstButton, UiThemeService.Color("Primary"))
        RegisterHoverButton(secondButton, UiThemeService.Color("Toolbar"))
        RegisterButtonClick(firstButton, AccessibilityTestButtonClick)
        testGui.Show("w156 h104")

        initialProperties := ReadAccessibleButtonProperties(firstButton.Hwnd)
        AssertRoundedButtonRenderer(initialProperties.NameResult >= 0
            && initialProperties.Name == "初始按钮名称"
            && initialProperties.RoleResult >= 0
            && initialProperties.RoleVariantType == 3
            && initialProperties.Role == ControlAccessibilityService.RolePushButton
            && initialProperties.ActionResult >= 0
            && initialProperties.DefaultAction == Tr("按下"),
            "自绘按钮没有公开正确的名称、按钮角色或默认操作")

        firstButton.Text := "更新后的按钮名称"
        updatedProperties := ReadAccessibleButtonProperties(firstButton.Hwnd)
        AssertRoundedButtonRenderer(updatedProperties.Name == "更新后的按钮名称",
            "辅助功能名称没有随按钮当前文字更新")

        ; 键盘消息会进入全局按键钩子；这里直接调用钩子，避免核心测试向当前
        ; 桌面投递真实按键而干扰正在使用电脑的用户。
        ControlFocus(firstButton)
        Global_KeyDown(13, 0, Win32.WM_KEYDOWN, firstButton.Hwnd)
        Global_KeyDown(32, 0, Win32.WM_KEYDOWN, firstButton.Hwnd)
        AssertRoundedButtonRenderer(accessibilityTestClickCount == 2,
            "Enter 或 Space 没有触发已注册的圆角按钮")

        ; 真实 Tab 导航由 Windows 对带 WS_TABSTOP 的控件完成；低层样式断言保证
        ; 自绘转换没有丢失该系统导航契约，完整键盘路径由 Windows GUI 冒烟测试覆盖。
        firstStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            firstButton.Hwnd, "Int", Win32.GWL_STYLE, "Ptr")
        secondStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            secondButton.Hwnd, "Int", Win32.GWL_STYLE, "Ptr")
        AssertRoundedButtonRenderer((firstStyle & 0x10000) != 0
                && (secondStyle & 0x10000) != 0,
            "自绘按钮没有保留 Tab 焦点导航所需的 WS_TABSTOP")

        AssertRoundedButtonRenderer(
            ControlAccessibilityService.ClearButton(firstButton.Hwnd),
            "自绘按钮的辅助功能属性无法清理")
        clearedProperties := ReadAccessibleButtonProperties(firstButton.Hwnd)
        AssertRoundedButtonRenderer(
            clearedProperties.Role != ControlAccessibilityService.RolePushButton,
            "辅助功能属性清理后仍遗留按钮角色")
    } finally {
        try UnregisterGuiControls(testGui.Hwnd)
        try testGui.Destroy()
        ControlAccessibilityService.Shutdown()
    }
}

AssertStatusBarGapLayout() {
    testGui := Gui("+ToolWindow")
    statusText := testGui.Add("Text", "w1000 h20")
    presenter := SvgStatusBarPresenter(statusText)
    try {
        presenter.SetItems([
            {Text: "运行中: 13", IconPath: ""},
            {Text: "已暂停: 0", IconPath: ""},
            {Text: "已停止: 0", IconPath: ""}
        ])
        measuredWidth := presenter.GetMinimumWidthDip()
        AssertRoundedButtonRenderer(measuredWidth > 20,
            "状态栏没有根据实际控件字体测量最小宽度")

        evenLayout := presenter.CalculateGapLayout(1000, 500, 6)
        AssertRoundedButtonRenderer(evenLayout.BaseGap == 100
                && evenLayout.ExtraGaps == 0,
            "状态栏没有平均分配可用宽度")

        remainderLayout := presenter.CalculateGapLayout(1003, 500, 6)
        AssertRoundedButtonRenderer(remainderLayout.BaseGap == 100
                && remainderLayout.ExtraGaps == 3
                && remainderLayout.BaseGap * 5
                    + remainderLayout.ExtraGaps == 503,
            "状态栏没有完整分配剩余像素")

        overflowLayout := presenter.CalculateGapLayout(400, 500, 6)
        AssertRoundedButtonRenderer(overflowLayout.BaseGap == 0
                && overflowLayout.ExtraGaps == 0,
            "状态栏内容超宽时仍增加了额外间距")

        singleLayout := presenter.CalculateGapLayout(1000, 120, 1)
        AssertRoundedButtonRenderer(singleLayout.BaseGap == 0
                && singleLayout.ExtraGaps == 0,
            "单项说明标签生成了无效间距")
    } finally {
        presenter.Dispose()
        try testGui.Destroy()
    }
}

AssertScaledChoiceButtonTextRendering() {
    previousScale := UiScaleService.GetRequested()
    previousTheme := UiThemeService.GetRequestedTheme()
    testGui := Gui("+ToolWindow", "Choice button text rendering")
    button := ""
    buttonDc := 0
    try {
        UiScaleService.Configure(200)
        UiThemeService.Configure("dark")
        testGui.BackColor := UiThemeService.Color("Window")
        testGui.SetFont("s10 c" UiThemeService.Color("Text"))
        button := testGui.Add("Text", "x20 y20 w100 h30 Center 0x200 Background"
            UiThemeService.Color("Primary") " c"
            UiThemeService.Color("ButtonText"), "立即恢复")
        RegisterHoverButton(button, UiThemeService.Color("Primary"))
        testGui.Show(ScaleApplicationShowOptions("w140 h70"))
        ApplyApplicationWindowScale(testGui)
        AssertRoundedButtonRenderer(RefreshDarkChoiceButtons([button],
            testGui.Hwnd), "缩放后恢复选择按钮没有提交重绘")
        SetTimer(RefreshDarkChoiceButtons.Bind([button], testGui.Hwnd), -1)
        SetTimer(RefreshDarkChoiceButtons.Bind([button], testGui.Hwnd), -25)
        Sleep(75)
        buttonDc := DllCall("user32\GetDC", "Ptr", button.Hwnd, "Ptr")
        clientRect := Buffer(16, 0)
        AssertRoundedButtonRenderer(buttonDc
            && DllCall("user32\GetClientRect", "Ptr", button.Hwnd,
                "Ptr", clientRect, "Int"),
            "无法读取缩放后恢复选择按钮的客户区")
        width := NumGet(clientRect, 8, "Int")
        height := NumGet(clientRect, 12, "Int")
        lightPixelCount := 0
        Loop height {
            y := A_Index - 1
            Loop width {
                x := A_Index - 1
                pixel := DllCall("gdi32\GetPixel", "Ptr", buttonDc,
                    "Int", x, "Int", y, "UInt")
                if ((pixel & 0xFF) >= 220
                    && ((pixel >> 8) & 0xFF) >= 220
                    && ((pixel >> 16) & 0xFF) >= 220)
                    lightPixelCount++
            }
        }
        AssertRoundedButtonRenderer(lightPixelCount > 20,
            "200% 缩放下恢复选择按钮没有绘制可见文字")
    } finally {
        if buttonDc
            DllCall("user32\ReleaseDC", "Ptr", button.Hwnd,
                "Ptr", buttonDc)
        try UnregisterGuiControls(testGui.Hwnd)
        try testGui.Destroy()
        UiScaleService.Configure(previousScale)
        UiThemeService.Configure(previousTheme)
    }
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
    AssertCenteredClearMark()
    AssertRoundedSelectionMask()
    AssertRoundedButtonSvgImage()
    AssertLeadingCommandSymbolGeometry()
    AssertTextVisualAlignment()
    AssertLucideSvgAssets()
    AssertRoundedButtonAccessibility()
    AssertStatusBarGapLayout()
    AssertScaledChoiceButtonTextRendering()
    RoundedButtonRenderer.Shutdown()
}

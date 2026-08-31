; 原生弹出菜单的 DPI 感知测量与绘制器。
; Windows 仍负责弹出定位、鼠标捕获、键盘导航、Esc 关闭和命令分发；本模块
; 只接管每个菜单项的尺寸与像素绘制，让字号、行距和深浅色外观可由应用统一控制。

class ContextMenuPresenter {
    static FontSizePt := 11
    static ItemHeightDip := 32
    static SeparatorHeightDip := 10
    static OuterVerticalPaddingDip := 5
    static HorizontalPaddingDip := 12
    static ShortcutGapDip := 32
    static SelectionHorizontalInsetDip := 4
    static SelectionVerticalInsetDip := 2
    static SelectionRadiusDip := 6
    static WindowRadiusDip := 9
    static Menus := Map()
    static ItemsById := Map()
    static Fonts := Map()
    static FontSignature := ""
    static winEventHook := 0
    static winEventCallback := 0

    static Attach(menuObj, ownerHwnd) {
        if !(menuObj is Menu) || !menuObj.Handle
            return false
        menuHandle := menuObj.Handle
        ; 重复注册同一批条目时先恢复原生类型，再重新读取文本和分隔项语义；
        ; 若调用方要清空重建条目，必须像主菜单一样在 Delete 前主动分离。
        this.Detach(menuHandle)
        fontName := LocalizationService.GetLanguageSystemUiFontName()
        this.RefreshFontConfiguration(fontName)
        itemCount := DllCall("user32\GetMenuItemCount", "Ptr", menuHandle,
            "Int")
        if itemCount <= 0
            return false

        record := {Handle: menuHandle, OwnerHwnd: ownerHwnd, Items: []}
        Loop itemCount {
            position := A_Index - 1
            itemInfo := this.ReadItemInfo(menuHandle, position)
            if !itemInfo {
                this.RestoreRecord(record)
                return false
            }
            model := {
                Id: itemInfo.Id,
                Position: position,
                OriginalType: itemInfo.Type,
                Separator: (itemInfo.Type & Win32.MFT_SEPARATOR) != 0,
                First: position == 0,
                Last: position == itemCount - 1,
                Text: this.ReadItemText(menuHandle, position),
                OwnerHwnd: ownerHwnd,
                FontName: fontName
            }
            if !this.SetOwnerDraw(menuHandle, position, itemInfo.Type) {
                this.RestoreRecord(record)
                return false
            }
            record.Items.Push(model)
        }
        this.Menus[menuHandle] := record
        for model in record.Items
            this.ItemsById[model.Id] := model
        this.EnsurePopupWindowHook()
        return true
    }

    static Detach(menuHandle, restore := true) {
        if !menuHandle || !this.Menus.Has(menuHandle)
            return
        record := this.Menus[menuHandle]
        this.Menus.Delete(menuHandle)
        for model in record.Items {
            if this.ItemsById.Has(model.Id)
                && this.ItemsById[model.Id] == model
                this.ItemsById.Delete(model.Id)
        }
        if restore
            this.RestoreRecord(record)
    }

    static Shutdown(*) {
        this.StopPopupWindowHook()
        menuHandles := []
        for menuHandle in this.Menus
            menuHandles.Push(menuHandle)
        for menuHandle in menuHandles
            this.Detach(menuHandle)
        this.ReleaseFonts()
        this.ItemsById.Clear()
        this.FontSignature := ""
    }

    static EnsurePopupWindowHook() {
        if this.winEventHook
            return true
        if !this.winEventCallback {
            try this.winEventCallback := CallbackCreate(
                ObjBindMethod(this, "HandleWinEvent"),, 7)
            catch
                this.winEventCallback := 0
        }
        if !this.winEventCallback
            return false
        currentProcessId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        this.winEventHook := DllCall("user32\SetWinEventHook",
            "UInt", Win32.EVENT_OBJECT_SHOW,
            "UInt", Win32.EVENT_OBJECT_SHOW,
            "Ptr", 0, "Ptr", this.winEventCallback,
            "UInt", currentProcessId, "UInt", 0, "UInt", 0, "Ptr")
        return this.winEventHook != 0
    }

    static StopPopupWindowHook() {
        hook := this.winEventHook
        callback := this.winEventCallback
        this.winEventHook := 0
        this.winEventCallback := 0
        if hook
            try DllCall("user32\UnhookWinEvent", "Ptr", hook, "Int")
        if callback
            try CallbackFree(callback)
    }

    static HandleWinEvent(hook, event, hwnd, idObject, idChild,
        eventThread, eventTime) {
        if event != Win32.EVENT_OBJECT_SHOW || !hwnd
            return
        if !this.IsOwnPopupMenuWindow(hwnd)
            return
        ; EVENT_OBJECT_SHOW 通常已取得最终尺寸；再排一个同线程的一次性回调，
        ; 兼容系统在可见通知后补做阴影或 DPI 尺寸调整的情况。
        this.ApplyRoundedPopupWindow(hwnd)
        try SetTimer(ObjBindMethod(this, "ApplyRoundedPopupWindow", hwnd),
            -1)
    }

    static IsOwnPopupMenuWindow(hwnd) {
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        processId := 0
        DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd,
            "UInt*", &processId, "UInt")
        if processId != DllCall("kernel32\GetCurrentProcessId", "UInt")
            return false
        classNameBuffer := Buffer(128, 0)
        classNameLength := DllCall("user32\GetClassNameW", "Ptr", hwnd,
            "Ptr", classNameBuffer, "Int", 64, "Int")
        return classNameLength
            && StrGet(classNameBuffer.Ptr, classNameLength, "UTF-16")
                == "#32768"
    }

    static RoundVisiblePopupWindows(*) {
        candidates := []
        captureHwnd := DllCall("user32\GetCapture", "Ptr")
        if captureHwnd
            candidates.Push(captureHwnd)
        popupHwnd := 0
        Loop {
            popupHwnd := DllCall("user32\FindWindowExW", "Ptr", 0,
                "Ptr", popupHwnd, "Str", "#32768", "Ptr", 0, "Ptr")
            if !popupHwnd
                break
            candidates.Push(popupHwnd)
        }
        for candidateHwnd in candidates {
            if this.IsOwnPopupMenuWindow(candidateHwnd)
                this.ApplyRoundedPopupWindow(candidateHwnd)
        }
    }

    static Show(menuObj, coordinates*) {
        if !(menuObj is Menu)
            return false
        this.EnsurePopupWindowHook()
        ; Menu.Show 在不同 AHK／系统组合上可能阻塞到菜单关闭，也可能很快
        ; 返回；前后各排一次单次扫描，两条路径都能在窗口可见后补齐圆角。
        SetTimer(ObjBindMethod(this, "RoundVisiblePopupWindows"), -1)
        try menuObj.Show(coordinates*)
        finally SetTimer(ObjBindMethod(this, "RoundVisiblePopupWindows"), -1)
        return true
    }

    static CreateRoundedWindowRegion(width, height, dpi) {
        if width <= 0 || height <= 0
            return 0
        radius := Max(4, Round(this.WindowRadiusDip
            * (dpi ? dpi : 96) / 96))
        diameter := radius * 2
        return DllCall("gdi32\CreateRoundRectRgn",
            "Int", 0, "Int", 0, "Int", width + 1, "Int", height + 1,
            "Int", diameter, "Int", diameter, "Ptr")
    }

    static ApplyRoundedPopupWindow(hwnd, *) {
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        ; Windows 11 保留 DWM 阴影与抗锯齿圆角；窗口区域同时作为旧版
        ; Windows 和经典菜单渲染路径的确定性回退。
        if (VerCompare(A_OSVersion, "10.0.22000") >= 0)
            try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd,
                "Int", 33, "Int*", 2, "Int", 4)
        windowRect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", hwnd,
                "Ptr", windowRect, "Int")
            return false
        width := NumGet(windowRect, 8, "Int")
            - NumGet(windowRect, 0, "Int")
        height := NumGet(windowRect, 12, "Int")
            - NumGet(windowRect, 4, "Int")
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
        region := this.CreateRoundedWindowRegion(width, height, dpi)
        if !region
            return false
        if DllCall("user32\SetWindowRgn", "Ptr", hwnd, "Ptr", region,
                "Int", true, "Int")
            return true
        DllCall("gdi32\DeleteObject", "Ptr", region)
        return false
    }

    static ReadItemInfo(menuHandle, position) {
        structureSize := A_PtrSize == 8 ? 80 : 48
        itemInfo := Buffer(structureSize, 0)
        NumPut("UInt", structureSize, itemInfo, 0)
        NumPut("UInt", Win32.MIIM_FTYPE, itemInfo, 4)
        if !DllCall("user32\GetMenuItemInfoW", "Ptr", menuHandle,
                "UInt", position, "Int", true, "Ptr", itemInfo, "Int")
            return false
        itemId := DllCall("user32\GetMenuItemID", "Ptr", menuHandle,
            "Int", position, "UInt")
        return {Id: itemId, Type: NumGet(itemInfo, 8, "UInt")}
    }

    static ReadItemText(menuHandle, position) {
        textBuffer := Buffer(4096, 0)
        copied := DllCall("user32\GetMenuStringW", "Ptr", menuHandle,
            "UInt", position, "Ptr", textBuffer, "Int", 2048,
            "UInt", 0x0400, "Int") ; MF_BYPOSITION：按菜单位置读取
        return copied > 0 ? StrGet(textBuffer, copied, "UTF-16") : ""
    }

    static SetOwnerDraw(menuHandle, position, originalType) {
        structureSize := A_PtrSize == 8 ? 80 : 48
        itemInfo := Buffer(structureSize, 0)
        NumPut("UInt", structureSize, itemInfo, 0)
        NumPut("UInt", Win32.MIIM_FTYPE, itemInfo, 4)
        ; OWNERDRAW、STRING、BITMAP 和 SEPARATOR 是互斥的主类型；保留其余
        ; 修饰位，分隔项的语义由模型保存并在 WM_DRAWITEM 中自行绘制。
        ownerDrawType := (originalType & ~(Win32.MFT_BITMAP
            | Win32.MFT_SEPARATOR | Win32.MFT_OWNERDRAW))
            | Win32.MFT_OWNERDRAW
        NumPut("UInt", ownerDrawType, itemInfo, 8)
        return DllCall("user32\SetMenuItemInfoW", "Ptr", menuHandle,
            "UInt", position, "Int", true, "Ptr", itemInfo, "Int") != 0
    }

    static RestoreRecord(record) {
        if !IsObject(record) || !record.Handle
            return
        if !DllCall("user32\IsMenu", "Ptr", record.Handle, "Int")
            return
        for model in record.Items {
            structureSize := A_PtrSize == 8 ? 80 : 48
            itemInfo := Buffer(structureSize, 0)
            NumPut("UInt", structureSize, itemInfo, 0)
            NumPut("UInt", Win32.MIIM_FTYPE, itemInfo, 4)
            NumPut("UInt", model.OriginalType, itemInfo, 8)
            DllCall("user32\SetMenuItemInfoW", "Ptr", record.Handle,
                "UInt", model.Position, "Int", true, "Ptr", itemInfo,
                "Int")
        }
    }

    static RefreshFontConfiguration(fontName) {
        signature := StrLower(String(fontName)) "|" this.FontSizePt
        if signature == this.FontSignature
            return
        this.ReleaseFonts()
        this.FontSignature := signature
    }

    static ReleaseFonts() {
        for _, fontHandle in this.Fonts {
            if fontHandle
                DllCall("gdi32\DeleteObject", "Ptr", fontHandle)
        }
        this.Fonts.Clear()
    }

    static GetDpi(model) {
        dpi := 0
        if model.OwnerHwnd
            try dpi := DllCall("user32\GetDpiForWindow", "Ptr",
                model.OwnerHwnd, "UInt")
        if !dpi
            try dpi := DllCall("user32\GetDpiForSystem", "UInt")
        return dpi ? dpi : 96
    }

    static GetFont(model, dpi) {
        cacheKey := dpi "|" StrLower(model.FontName)
        if this.Fonts.Has(cacheKey)
            return this.Fonts[cacheKey]
        pixelHeight := Max(1, Round(this.FontSizePt * dpi / 72))
        fontHandle := DllCall("gdi32\CreateFontW",
            "Int", -pixelHeight, "Int", 0, "Int", 0, "Int", 0,
            "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0,
            "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 5,
            "UInt", 0, "Str", model.FontName, "Ptr")
        if fontHandle
            this.Fonts[cacheKey] := fontHandle
        return fontHandle ? fontHandle
            : DllCall("gdi32\GetStockObject", "Int", 17, "Ptr")
    }

    static SplitText(text) {
        tabPosition := InStr(text, "`t")
        if !tabPosition
            return {Main: text, Shortcut: ""}
        return {
            Main: SubStr(text, 1, tabPosition - 1),
            Shortcut: SubStr(text, tabPosition + 1)
        }
    }

    static MeasureText(hdc, text) {
        if text == ""
            return {Width: 0, Height: 0}
        extent := Buffer(8, 0)
        if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr", hdc,
                "Str", text, "Int", StrLen(text), "Ptr", extent, "Int")
            return {Width: 0, Height: 0}
        return {Width: NumGet(extent, 0, "Int"),
            Height: NumGet(extent, 4, "Int")}
    }

    static Measure(model) {
        dpi := this.GetDpi(model)
        outerPadding := Max(1, Round(
            this.OuterVerticalPaddingDip * dpi / 96))
        outerHeight := (model.First ? outerPadding : 0)
            + (model.Last ? outerPadding : 0)
        if model.Separator
            return {Width: Max(1, Round(20 * dpi / 96)),
                Height: Max(1, Round(this.SeparatorHeightDip * dpi / 96))
                    + outerHeight,
                Dpi: dpi}
        hdc := DllCall("user32\GetDC", "Ptr", model.OwnerHwnd, "Ptr")
        if !hdc
            return {Width: Round(200 * dpi / 96),
                Height: Round(this.ItemHeightDip * dpi / 96)
                    + outerHeight, Dpi: dpi}
        fontHandle := this.GetFont(model, dpi)
        previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
            hdc, "Ptr", fontHandle, "Ptr") : 0
        try {
            parts := this.SplitText(model.Text)
            mainExtent := this.MeasureText(hdc, parts.Main)
            shortcutExtent := this.MeasureText(hdc, parts.Shortcut)
            padding := Max(1, Round(this.HorizontalPaddingDip * dpi / 96))
            shortcutGap := parts.Shortcut == "" ? 0
                : Max(1, Round(this.ShortcutGapDip * dpi / 96))
            width := padding * 2 + mainExtent.Width + shortcutGap
                + shortcutExtent.Width
            minimumHeight := Round(this.ItemHeightDip * dpi / 96)
            textPadding := Max(2, Round(10 * dpi / 96))
            height := Max(minimumHeight,
                Max(mainExtent.Height, shortcutExtent.Height) + textPadding)
                + outerHeight
            return {Width: width, Height: height, Dpi: dpi}
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", model.OwnerHwnd,
                "Ptr", hdc)
        }
    }

    static HandleMeasure(lParam) {
        if !lParam || NumGet(lParam, 0, "UInt") != Win32.ODT_MENU
            return ""
        itemId := NumGet(lParam, 8, "UInt")
        if !this.ItemsById.Has(itemId)
            return ""
        measurement := this.Measure(this.ItemsById[itemId])
        NumPut("UInt", measurement.Width, lParam, 12)
        NumPut("UInt", measurement.Height, lParam, 16)
        return 1
    }

    static Fill(hdc, left, top, right, bottom, color) {
        brush := DllCall("gdi32\CreateSolidBrush", "UInt",
            RoundedButtonRenderer.ColorToBgr(color), "Ptr")
        if !brush
            return false
        rect := Buffer(16, 0)
        NumPut("Int", left, "Int", top, "Int", right, "Int", bottom,
            rect)
        try return DllCall("user32\FillRect", "Ptr", hdc, "Ptr", rect,
            "Ptr", brush, "Int") != 0
        finally DllCall("gdi32\DeleteObject", "Ptr", brush)
    }

    static DrawSeparator(hdc, left, top, right, bottom, dpi) {
        this.Fill(hdc, left, top, right, bottom, UiThemeService.Color("Menu"))
        inset := Max(4, Round(9 * dpi / 96))
        lineHeight := Max(1, Round(dpi / 96))
        lineY := Floor((top + bottom - lineHeight) / 2)
        this.Fill(hdc, left + inset, lineY, right - inset,
            lineY + lineHeight, UiThemeService.Color("Divider"))
    }

    static DrawTextPart(hdc, text, left, top, right, bottom,
        rightAligned := false) {
        if text == "" || right <= left
            return
        rect := Buffer(16, 0)
        NumPut("Int", left, "Int", top, "Int", right, "Int", bottom,
            rect)
        flags := 0x00000824 ; DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX：单行居中且不解析快捷键
        if rightAligned
            flags |= 0x00000002 ; DT_RIGHT：右对齐快捷键与勾选标记
        DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
            "Int", -1, "Ptr", rect, "UInt", flags, "Int")
    }

    static HandleDraw(lParam) {
        if !lParam || NumGet(lParam, 0, "UInt") != Win32.ODT_MENU
            return ""
        itemId := NumGet(lParam, 8, "UInt")
        if !this.ItemsById.Has(itemId)
            return ""
        model := this.ItemsById[itemId]
        itemHwndOffset := A_PtrSize == 8 ? 24 : 20
        hdcOffset := itemHwndOffset + A_PtrSize
        rectOffset := hdcOffset + A_PtrSize
        hdc := NumGet(lParam, hdcOffset, "Ptr")
        left := NumGet(lParam, rectOffset, "Int")
        top := NumGet(lParam, rectOffset + 4, "Int")
        right := NumGet(lParam, rectOffset + 8, "Int")
        bottom := NumGet(lParam, rectOffset + 12, "Int")
        dpi := this.GetDpi(model)
        outerPadding := Max(1, Round(
            this.OuterVerticalPaddingDip * dpi / 96))
        contentTop := top + (model.First ? outerPadding : 0)
        contentBottom := bottom - (model.Last ? outerPadding : 0)
        if model.Separator {
            this.Fill(hdc, left, top, right, bottom,
                UiThemeService.Color("Menu"))
            this.DrawSeparator(hdc, left, contentTop, right, contentBottom,
                dpi)
            return 1
        }

        itemState := NumGet(lParam, 16, "UInt")
        selected := (itemState & Win32.ODS_SELECTED) != 0
        disabled := (itemState & (Win32.ODS_GRAYED
            | Win32.ODS_MENU_DISABLED)) != 0
        this.Fill(hdc, left, top, right, bottom,
            UiThemeService.Color("Menu"))
        if selected {
            horizontalInset := Max(2, Round(
                this.SelectionHorizontalInsetDip * dpi / 96))
            verticalInset := Max(1, Round(
                this.SelectionVerticalInsetDip * dpi / 96))
            radius := Max(3, Round(this.SelectionRadiusDip * dpi / 96))
            if !RoundedButtonRenderer.FillRoundedRectangle(hdc,
                    left + horizontalInset, contentTop + verticalInset,
                    right - horizontalInset, contentBottom - verticalInset,
                    UiThemeService.Color("MenuHover"), radius)
                this.Fill(hdc, left + horizontalInset,
                    contentTop + verticalInset, right - horizontalInset,
                    contentBottom - verticalInset,
                    UiThemeService.Color("MenuHover"))
        }

        fontHandle := this.GetFont(model, dpi)
        previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
            hdc, "Ptr", fontHandle, "Ptr") : 0
        previousMode := DllCall("gdi32\SetBkMode", "Ptr", hdc,
            "Int", 1, "Int") ; TRANSPARENT：文字背景保持透明
        textColor := UiThemeService.Color(disabled ? "DisabledText" : "Text")
        previousTextColor := DllCall("gdi32\SetTextColor", "Ptr", hdc,
            "UInt", RoundedButtonRenderer.ColorToBgr(textColor), "UInt")
        try {
            parts := this.SplitText(model.Text)
            padding := Max(1, Round(this.HorizontalPaddingDip * dpi / 96))
            shortcutExtent := this.MeasureText(hdc, parts.Shortcut)
            shortcutRight := right - padding
            shortcutLeft := parts.Shortcut == "" ? shortcutRight
                : shortcutRight - shortcutExtent.Width
            this.DrawTextPart(hdc, parts.Main, left + padding, contentTop,
                parts.Shortcut == "" ? shortcutRight
                    : shortcutLeft - Max(1,
                        Round(this.ShortcutGapDip * dpi / 96)),
                contentBottom)
            this.DrawTextPart(hdc, parts.Shortcut, shortcutLeft, contentTop,
                shortcutRight, contentBottom, true)
        } finally {
            DllCall("gdi32\SetTextColor", "Ptr", hdc,
                "UInt", previousTextColor)
            DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", previousMode)
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc,
                    "Ptr", previousFont, "Ptr")
        }
        return 1
    }
}

OnMeasureApplicationControl(wParam, lParam, msg, hwnd) {
    return ContextMenuPresenter.HandleMeasure(lParam)
}

ShutdownContextMenuPresenter(*) {
    ContextMenuPresenter.Shutdown()
}

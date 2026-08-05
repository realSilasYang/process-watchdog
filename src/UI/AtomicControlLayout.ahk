; 可见同级控件的无闪烁原子布局事务；统一处理 DPI、批量定位和局部表面收尾。
; 调用方提供 96-DPI 逻辑坐标；进入 Win32 调用前统一转换为物理像素。

class AtomicControlLayoutEraseGuard {
    static SubclassId := 0x43454744
    static BlockedEraseCount := 0
    static CallbackPointer := 0
    static AttachedHwnds := Map()
    static ActiveHwndCounts := Map()

    static Begin(controls) {
        transaction := {Hwnds: []}
        if Type(controls) != "Array"
            return transaction
        if !this.EnsureCallback()
            throw Error("Unable to create child erase guard")
        try {
            for controlObj in controls {
                try hwnd := controlObj.Hwnd
                catch
                    continue
                if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                    continue
                if !this.AttachedHwnds.Has(hwnd) {
                    if !DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd,
                            "Ptr", this.CallbackPointer, "UPtr",
                            this.SubclassId, "UPtr", 0, "Int")
                        throw Error("Unable to install child erase guard")
                    this.AttachedHwnds[hwnd] := true
                }
                activeCount := this.ActiveHwndCounts.Has(hwnd)
                    ? this.ActiveHwndCounts[hwnd] : 0
                this.ActiveHwndCounts[hwnd] := activeCount + 1
                transaction.Hwnds.Push(hwnd)
            }
        } catch as installError {
            this.End(transaction)
            throw installError
        }
        return transaction
    }

    static End(transaction) {
        if !IsObject(transaction) || !transaction.HasOwnProp("Hwnds")
            return false
        for hwnd in transaction.Hwnds {
            if !this.ActiveHwndCounts.Has(hwnd)
                continue
            activeCount := this.ActiveHwndCounts[hwnd] - 1
            if activeCount > 0
                this.ActiveHwndCounts[hwnd] := activeCount
            else
                this.ActiveHwndCounts.Delete(hwnd)
        }
        return true
    }

    static EnsureCallback() {
        if this.CallbackPointer
            return true
        this.CallbackPointer := CallbackCreate(ObjBindMethod(this,
            "WindowProc"),, 6)
        return this.CallbackPointer != 0
    }

    static WindowProc(hwnd, message, wParam, lParam, subclassId,
        referenceData) {
        if message == 0x0082 {
            if this.AttachedHwnds.Has(hwnd)
                this.AttachedHwnds.Delete(hwnd)
            if this.ActiveHwndCounts.Has(hwnd)
                this.ActiveHwndCounts.Delete(hwnd)
        }
        if message == 0x0014 && this.ActiveHwndCounts.Has(hwnd) {
            this.BlockedEraseCount++
            return 1
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }
}

class AtomicControlLayout {
    static Unchanged := "Unchanged"
    static Applied := "Applied"
    static Unavailable := "Unavailable"
    static Failed := "Failed"
    static ModeDeferred := "Deferred"
    static ModeDirect := "Direct"
    static ModeFallback := "Fallback"
    static SwpFlags := 0x031C
    static DcxClipChildren := 0x000A
    static RdwRefreshNoErase := 0x01A1

    static Apply(parentGui, entries, options := "") {
        result := {Status: this.Failed, Mode: "None", Changed: false,
            Repainted: false, Reason: ""}
        parentHwnd := this.GetHwnd(parentGui)
        if !parentHwnd || !DllCall("user32\IsWindow", "Ptr", parentHwnd, "Int") {
            result.Status := this.Unavailable
            result.Reason := "Parent window is unavailable"
            return result
        }
        normalized := this.NormalizeEntries(entries)
        if !normalized.Ok {
            result.Reason := normalized.Reason
            return result
        }
        parentColor := this.GetOption(options, "ParentColor", "")
        if parentColor == "" {
            try parentColor := parentGui.BackColor
            catch
                parentColor := ""
        }
        if parentColor == "" {
            result.Reason := "ParentColor is required"
            return result
        }
        clearMargin := this.GetOption(options, "ClearMargin", 0)
        try clearMargin := Max(0, Number(clearMargin))
        catch {
            result.Reason := "ClearMargin is invalid"
            return result
        }

        scale := this.GetDpiScale(parentHwnd)
        physicalEntries := []
        oldBounds := false
        changed := false
        for item in normalized.Entries {
            rect := this.GetControlBounds(item.Control, parentHwnd)
            if !rect {
                result.Status := this.Unavailable
                result.Reason := "A child window is unavailable"
                return result
            }
            oldBounds := this.UnionBounds(oldBounds, rect)
            target := {Control: item.Control,
                X: Round(item.X * scale), Y: Round(item.Y * scale),
                Width: Round(item.Width * scale),
                Height: Round(item.Height * scale)}
            physicalEntries.Push(target)
            if rect.Left != target.X || rect.Top != target.Y
                    || rect.Right - rect.Left != target.Width
                    || rect.Bottom - rect.Top != target.Height
                changed := true
        }
        result.OldBounds := oldBounds
        if !changed {
            result.Status := this.Unchanged
            return result
        }
        result.Changed := true

        if !DllCall("user32\IsWindowVisible", "Ptr", parentHwnd, "Int")
            return this.ApplyDirect(parentHwnd, normalized.Entries,
                physicalEntries, oldBounds, parentColor,
                Round(clearMargin * scale), result, this.ModeDirect)

        controls := []
        for item in normalized.Entries
            controls.Push(item.Control)
        eraseGuard := ""
        try {
            eraseGuard := AtomicControlLayoutEraseGuard.Begin(controls)
            if this.TryApplyDeferred(physicalEntries) {
                result.Mode := this.ModeDeferred
            } else {
                this.MoveDirect(normalized.Entries)
                result.Mode := this.ModeFallback
            }
            if !this.TargetsMatch(physicalEntries, parentHwnd)
                throw Error("Applied child geometry does not match targets")
            newBounds := this.GetControlsBounds(normalized.Entries,
                parentHwnd)
            result.NewBounds := newBounds
            result.Repainted := this.Repaint(parentHwnd, oldBounds, newBounds,
                parentColor, Round(clearMargin * scale))
            if !result.Repainted
                throw Error("Unable to reconcile the parent surface")
            result.Status := this.Applied
            return result
        } catch as layoutError {
            result.Reason := layoutError.Message
            try {
                this.MoveDirect(normalized.Entries)
                result.Mode := this.ModeFallback
                if !this.TargetsMatch(physicalEntries, parentHwnd)
                    throw Error("Fallback child geometry does not match targets")
                result.NewBounds := this.GetControlsBounds(
                    normalized.Entries, parentHwnd)
                result.Repainted := this.Repaint(parentHwnd, oldBounds,
                    result.NewBounds, parentColor, Round(clearMargin * scale))
                if !result.Repainted
                    throw Error("Fallback surface reconciliation failed")
                result.Status := this.Applied
            } catch as fallbackError {
                result.Reason := layoutError.Message "; fallback: "
                    fallbackError.Message
            }
            return result
        } finally {
            if IsObject(eraseGuard)
                AtomicControlLayoutEraseGuard.End(eraseGuard)
        }
    }

    static GetHwnd(guiObj) {
        try return guiObj.Hwnd
        catch
            return 0
    }

    static GetOption(options, name, defaultValue) {
        return IsObject(options) && options.HasOwnProp(name)
            ? options.%name% : defaultValue
    }

    static NormalizeEntries(entries) {
        if Type(entries) != "Array" || !entries.Length
            return {Ok: false, Reason: "At least one layout entry is required"}
        normalized := []
        for spec in entries {
            if !IsObject(spec)
                return {Ok: false, Reason: "Layout entry is not an object"}
            try {
                control := spec.Control
                x := Number(spec.X)
                y := Number(spec.Y)
                width := Number(spec.Width)
                height := Number(spec.Height)
            } catch {
                return {Ok: false, Reason: "Layout entry is incomplete"}
            }
            if !control || width < 0 || height < 0
                return {Ok: false, Reason: "Layout entry has invalid geometry"}
            normalized.Push({Control: control, X: x, Y: y,
                Width: width, Height: height})
        }
        return {Ok: true, Entries: normalized}
    }

    static GetDpiScale(parentHwnd) {
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", parentHwnd,
            "UInt")
        return (windowDpi ? windowDpi : 96) / 96
    }

    static TryApplyDeferred(entries) {
        deferred := DllCall("user32\BeginDeferWindowPos", "Int",
            entries.Length, "Ptr")
        if !deferred
            return false
        for item in entries {
            deferred := DllCall("user32\DeferWindowPos", "Ptr", deferred,
                "Ptr", item.Control.Hwnd, "Ptr", 0,
                "Int", item.X, "Int", item.Y,
                "Int", item.Width, "Int", item.Height,
                "UInt", this.SwpFlags, "Ptr")
            if !deferred
                return false
        }
        return DllCall("user32\EndDeferWindowPos", "Ptr", deferred, "Int")
            != 0
    }

    static ApplyDirect(parentHwnd, entries, physicalEntries, oldBounds,
        parentColor, margin, result, mode) {
        try {
            this.MoveDirect(entries)
            if !this.TargetsMatch(physicalEntries, parentHwnd)
                throw Error("Direct child geometry does not match targets")
            result.NewBounds := this.GetControlsBounds(entries, parentHwnd)
            result.Repainted := !DllCall("user32\IsWindowVisible",
                "Ptr", parentHwnd, "Int") || this.Repaint(parentHwnd,
                    oldBounds, result.NewBounds, parentColor, margin)
            if !result.Repainted
                throw Error("Direct surface reconciliation failed")
            result.Status := this.Applied
            result.Mode := mode
        } catch as moveError {
            result.Reason := moveError.Message
        }
        return result
    }

    static MoveDirect(entries) {
        for item in entries
            item.Control.Move(item.X, item.Y, item.Width, item.Height)
    }

    static TargetsMatch(entries, parentHwnd) {
        for item in entries {
            rect := this.GetControlBounds(item.Control, parentHwnd)
            if !rect || rect.Left != item.X || rect.Top != item.Y
                    || rect.Right - rect.Left != item.Width
                    || rect.Bottom - rect.Top != item.Height
                return false
        }
        return true
    }

    static GetControlsBounds(entries, parentHwnd) {
        bounds := false
        for item in entries
            bounds := this.UnionBounds(bounds,
                this.GetControlBounds(item.Control, parentHwnd))
        return bounds
    }

    static GetControlBounds(control, parentHwnd) {
        try hwnd := control.Hwnd
        catch
            return false
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        rect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int")
            return false
        DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr", parentHwnd,
            "Ptr", rect, "UInt", 2, "Int")
        return {Left: NumGet(rect, 0, "Int"), Top: NumGet(rect, 4, "Int"),
            Right: NumGet(rect, 8, "Int"), Bottom: NumGet(rect, 12, "Int")}
    }

    static UnionBounds(left, right) {
        if !IsObject(right)
            return left
        if !IsObject(left)
            return {Left: right.Left, Top: right.Top,
                Right: right.Right, Bottom: right.Bottom}
        return {Left: Min(left.Left, right.Left), Top: Min(left.Top, right.Top),
            Right: Max(left.Right, right.Right),
            Bottom: Max(left.Bottom, right.Bottom)}
    }

    static Repaint(parentHwnd, oldBounds, newBounds, color, margin) {
        if !oldBounds && !newBounds
            return false
        backgroundPainted := !oldBounds
            || this.PaintParentClientBackground(parentHwnd, oldBounds, color,
                margin)
        bounds := this.UnionBounds(oldBounds, newBounds)
        rect := Buffer(16, 0)
        NumPut("Int", Max(0, bounds.Left - margin), rect, 0)
        NumPut("Int", Max(0, bounds.Top - margin), rect, 4)
        NumPut("Int", bounds.Right + margin, rect, 8)
        NumPut("Int", bounds.Bottom + margin, rect, 12)
        redrawn := DllCall("user32\RedrawWindow", "Ptr", parentHwnd,
            "Ptr", rect, "Ptr", 0, "UInt", this.RdwRefreshNoErase,
            "Int") != 0
        return backgroundPainted && redrawn
    }

    static PaintParentClientBackground(parentHwnd, bounds, color,
        margin := 0) {
        if !parentHwnd || !IsObject(bounds)
            return false
        try colorValue := Integer("0x" RegExReplace(String(color), "^#"))
        catch
            return false
        rect := Buffer(16, 0)
        NumPut("Int", Max(0, bounds.Left - margin), rect, 0)
        NumPut("Int", Max(0, bounds.Top - margin), rect, 4)
        NumPut("Int", bounds.Right + margin, rect, 8)
        NumPut("Int", bounds.Bottom + margin, rect, 12)
        hdc := DllCall("user32\GetDCEx", "Ptr", parentHwnd, "Ptr", 0,
            "UInt", this.DcxClipChildren, "Ptr")
        brush := DllCall("gdi32\CreateSolidBrush", "UInt",
            ((colorValue & 0xFF) << 16) | (colorValue & 0x00FF00)
                | ((colorValue >> 16) & 0xFF), "Ptr")
        if !hdc || !brush {
            if brush
                DllCall("gdi32\DeleteObject", "Ptr", brush)
            if hdc
                DllCall("user32\ReleaseDC", "Ptr", parentHwnd, "Ptr", hdc)
            return false
        }
        try {
            painted := DllCall("user32\FillRect", "Ptr", hdc, "Ptr", rect,
                "Ptr", brush, "Int") != 0
            if painted
                DllCall("gdi32\GdiFlush", "Int")
            return painted
        } finally {
            DllCall("gdi32\DeleteObject", "Ptr", brush)
            DllCall("user32\ReleaseDC", "Ptr", parentHwnd, "Ptr", hdc)
        }
    }
}

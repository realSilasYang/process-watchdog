; 全应用控件交互状态注册表。
; 按 HWND 记录按钮悬浮、文本输入命中和系统光标缓存，窗口销毁后统一剪除失效项；
; 注册表只保存交互元数据，不拥有 GUI 控件本身，也不执行具体按钮功能。

class UiCursorKind {
    static Hand := "hand"
    static Arrow := "arrow"
    static Text := "text"
}

class UiInteractionRegistry {
    __New(cursorLoader := "") {
        this.Buttons := Map()
        this.TextInputs := Map()
        this.Cursors := Map()
        this.HoveredButton := 0
        this.PressedButton := 0
        this.LastButtonPruneTick := 0
        this.ButtonPruneInitialized := false
        this.CursorLoader := IsObject(cursorLoader)
            ? cursorLoader : ObjBindMethod(this, "LoadSystemCursor")
    }

    RegisterButton(hwnd, state) {
        if !hwnd || !IsObject(state)
            return false
        this.Buttons[hwnd] := state
        return true
    }

    HasButton(hwnd) {
        return hwnd && this.Buttons.Has(hwnd)
    }

    GetButton(hwnd) {
        return this.HasButton(hwnd) ? this.Buttons[hwnd] : ""
    }

    RemoveButton(hwnd) {
        if !this.HasButton(hwnd)
            return ""
        state := this.Buttons[hwnd]
        this.Buttons.Delete(hwnd)
        this.ClearPressedButton(hwnd)
        this.ClearHoveredButton(hwnd)
        return state
    }

    SetPressedButton(hwnd) {
        if hwnd && !this.HasButton(hwnd)
            return 0
        this.PressedButton := hwnd ? hwnd : 0
        return this.PressedButton
    }

    ClearPressedButton(expectedHwnd := 0) {
        if expectedHwnd && this.PressedButton != expectedHwnd
            return false
        changed := this.PressedButton != 0
        this.PressedButton := 0
        return changed
    }

    SetHoveredButton(hwnd) {
        if hwnd && !this.HasButton(hwnd)
            return 0
        this.HoveredButton := hwnd ? hwnd : 0
        return this.HoveredButton
    }

    ClearHoveredButton(expectedHwnd := 0) {
        if expectedHwnd && this.HoveredButton != expectedHwnd
            return false
        changed := this.HoveredButton != 0
        this.HoveredButton := 0
        return changed
    }

    ShouldPruneButtons(nowTicks, intervalMs := 1000) {
        try {
            nowTicks := Integer(nowTicks)
            intervalMs := Integer(intervalMs)
        } catch {
            return false
        }
        if (nowTicks < 0 || intervalMs < 1)
            return false
        elapsed := nowTicks - this.LastButtonPruneTick
        if !this.ButtonPruneInitialized || elapsed < 0
            || elapsed >= intervalMs {
            this.LastButtonPruneTick := nowTicks
            this.ButtonPruneInitialized := true
            return true
        }
        return false
    }

    RegisterTextInput(targetHwnd, state) {
        if !targetHwnd || !IsObject(state) || !state.HasOwnProp("editHwnd")
            || !state.editHwnd
            return false
        this.TextInputs[targetHwnd] := state
        return true
    }

    HasTextInput(targetHwnd) {
        return targetHwnd && this.TextInputs.Has(targetHwnd)
    }

    GetTextInput(targetHwnd) {
        return this.HasTextInput(targetHwnd) ? this.TextInputs[targetHwnd] : ""
    }

    RemoveTextInput(targetHwnd) {
        if !this.HasTextInput(targetHwnd)
            return false
        this.TextInputs.Delete(targetHwnd)
        return true
    }

    GetCursor(kind, cursorId) {
        key := StrLower(Trim(String(kind)))
        if (key == "" || !cursorId)
            return 0
        if this.Cursors.Has(key)
            return this.Cursors[key]
        try cursorHandle := this.CursorLoader.Call(cursorId)
        catch
            return 0
        if !cursorHandle
            return 0
        this.Cursors[key] := cursorHandle
        return cursorHandle
    }

    LoadSystemCursor(cursorId) {
        return DllCall("user32\LoadCursor", "Ptr", 0,
            "Ptr", cursorId, "Ptr")
    }
}

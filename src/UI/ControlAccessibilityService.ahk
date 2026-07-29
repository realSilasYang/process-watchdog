; 自绘控件的 MSAA 语义服务。
; 圆角按钮为保证视觉一致性会改用 owner-draw 的 Static/Button 控件；这会让辅助
; 技术只看到静态文本或失去默认操作。这里用 Windows IAccPropServices 仅补充
; “按钮角色”和“按下”操作，名称继续由原生 WM_GETTEXT 动态提供，因此按钮文字
; 在运行中切换（例如“正在检查更新”）时无需同步两套状态。

class ControlAccessibilityService {
    static ObjectIdClient := -4
    static RolePushButton := 0x2B
    static PropertyRole := "{CB905FF2-7BD1-4C05-B3C8-E6C241364D70}"
    static PropertyDefaultAction := "{180C072B-C27F-43C7-9922-F63562A4632B}"
    static Service := ""
    static RoleGuid := ""
    static DefaultActionGuid := ""
    static ActiveButtons := Map()

    static RegisterButton(hwnd, defaultAction) {
        if !this.IsWindow(hwnd)
            return false
        service := this.GetService()
        if !service
            return false
        try {
            roleValue := this.CreateIntegerVariant(this.RolePushButton)
            if ComCall(6, service, "Ptr", hwnd, "Int", this.ObjectIdClient,
                "Int", 0, "Ptr", this.GetRoleGuid(), "Ptr", roleValue,
                "Int") < 0
                return false
            if ComCall(7, service, "Ptr", hwnd, "Int", this.ObjectIdClient,
                "Int", 0, "Ptr", this.GetDefaultActionGuid(), "WStr",
                String(defaultAction), "Int") < 0 {
                this.ClearButton(hwnd)
                return false
            }
            this.ActiveButtons[hwnd] := true
            return true
        } catch {
            return false
        }
    }

    static ClearButton(hwnd) {
        if !hwnd {
            return false
        }
        wasRegistered := this.ActiveButtons.Has(hwnd)
        if wasRegistered
            this.ActiveButtons.Delete(hwnd)
        if !wasRegistered
            return false
        service := this.GetService()
        if !service || !this.IsWindow(hwnd)
            return wasRegistered
        propertyList := Buffer(32, 0)
        DllCall("kernel32\RtlMoveMemory", "Ptr", propertyList, "Ptr",
            this.GetRoleGuid(), "UPtr", 16)
        DllCall("kernel32\RtlMoveMemory", "Ptr", propertyList.Ptr + 16,
            "Ptr", this.GetDefaultActionGuid(), "UPtr", 16)
        try return ComCall(9, service, "Ptr", hwnd, "Int", this.ObjectIdClient,
            "Int", 0, "Ptr", propertyList, "Int", 2, "Int") >= 0
        catch
            return false
    }

    static Shutdown() {
        buttonHandles := []
        for hwnd, _ in this.ActiveButtons
            buttonHandles.Push(hwnd)
        for hwnd in buttonHandles
            this.ClearButton(hwnd)
        this.ActiveButtons.Clear()
        this.Service := ""
        this.RoleGuid := ""
        this.DefaultActionGuid := ""
    }

    static GetService() {
        if IsObject(this.Service)
            return this.Service
        try this.Service := ComObject(
            "{B5F8350B-0548-48B1-A6EE-88BD00B4A5E7}",
            "{6E26E776-04F0-495D-80E4-3330352E3169}")
        catch
            this.Service := ""
        return this.Service
    }

    static GetRoleGuid() {
        if IsObject(this.RoleGuid)
            return this.RoleGuid
        this.RoleGuid := this.CreateGuid(this.PropertyRole)
        return this.RoleGuid
    }

    static GetDefaultActionGuid() {
        if IsObject(this.DefaultActionGuid)
            return this.DefaultActionGuid
        this.DefaultActionGuid := this.CreateGuid(this.PropertyDefaultAction)
        return this.DefaultActionGuid
    }

    static CreateGuid(value) {
        guid := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString", "WStr", value, "Ptr", guid,
                "Int") < 0
            throw Error("Invalid accessibility property identifier")
        return guid
    }

    static CreateIntegerVariant(value) {
        ; x64 下 VARIANT 按结构体指针传入 COM 调用；VT_I4 的值位于 union 偏移 8。
        variant := Buffer(24, 0)
        NumPut("UShort", 3, variant, 0)
        NumPut("Int", value, variant, 8)
        return variant
    }

    static IsWindow(hwnd) {
        return hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int") != 0
    }
}

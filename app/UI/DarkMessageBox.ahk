; 深色模态消息框的创建与所有者恢复边界。
; 弹窗使用项目统一按钮和窗口层级规则；无论用户点击按钮、关闭标题栏还是原生窗口
; 被外部销毁，都必须先恢复上级交互，再释放当前窗口控件与图标资源。
CloseDarkMsgBox(mb, ownerLease, &closed) {
    if closed
        return
    closed := true
    ; 先恢复所有者再销毁弹窗，避免 Windows 因所有者仍禁用而把前台切走。
    closeContext := WindowHierarchy.Release(ownerLease)
    try {
        try UnregisterGuiControls(mb.Hwnd)
        try ReleaseApplicationWindowScale(mb.Hwnd)
        mb.Destroy()
    }
    finally WindowHierarchy.CompleteClose(closeContext)
}

CalculateDarkDialogLayout(windowWidth, messageHeight, buttonWidths,
    buttonTopGap := 20) {
    contentTop := 20
    iconHeight := 30
    buttonHeight := 30
    buttonGap := 12
    rowHeight := Max(iconHeight, Max(1, Integer(messageHeight)))
    iconY := contentTop + Floor((rowHeight - iconHeight) / 2)
    messageY := contentTop + Floor((rowHeight - messageHeight) / 2)
    buttonY := contentTop + rowHeight + buttonTopGap
    groupWidth := 0
    for buttonWidth in buttonWidths
        groupWidth += buttonWidth
    if buttonWidths.Length > 1
        groupWidth += buttonGap * (buttonWidths.Length - 1)
    nextButtonX := Floor((windowWidth - groupWidth) / 2)
    buttonXs := []
    for buttonWidth in buttonWidths {
        buttonXs.Push(nextButtonX)
        nextButtonX += buttonWidth + buttonGap
    }
    return {
        IconY: iconY,
        MessageY: messageY,
        ButtonY: buttonY,
        ButtonXs: buttonXs,
        BottomY: buttonY + buttonHeight,
        WindowHeight: buttonY + buttonHeight + 15
    }
}

ShowDarkMsgBox(Message, Title := "", MsgType := "Info", ownerGui := "") {
    if Title == ""
        Title := Tr("提示")
    Message := NormalizeUserVisibleParentheses(Message)
    Title := NormalizeUserVisibleParentheses(Title)
    mb := Gui("-MinimizeBox -MaximizeBox", Title)

    try RestoreHoveredButton()
    if IsSet(GuiModules)
        try GuiModules.HideTransientWindows()
    ownerLease := ""
    closed := false
    ; 主窗口存在时先将其禁用，模拟原生模态弹窗的交互拦截效果。
    dialogOwner := ownerGui
    if !dialogOwner && IsSet(Main)
        dialogOwner := Main.gui
    if dialogOwner && Type(dialogOwner) == "Gui" {
        try {
            if WinExist(dialogOwner.Hwnd) {
                mb.Opt("+Owner" dialogOwner.Hwnd)
                ownerLease := WindowHierarchy.Acquire(dialogOwner, mb.Hwnd)
            }
        }
    }

    try {
    ; 标题栏、图标、客户区和正文默认字体共用应用窗口初始化边界。
    InitializeApplicationWindow(mb)

    ; 图标列保持固定宽度，正文根据消息长度计算高度并允许自然换行。
    iconStr := (MsgType == "Error") ? "❌" : "ℹ️" ; <--- 同步修改这里
    mb.SetFont("s18", "Segoe UI Emoji")
    iconControl := mb.Add("Text", "x20 y20 w30 h30 BackgroundTrans c"
        UiThemeService.Color("Text"), iconStr)

    mb.SetFont("s10 c" UiThemeService.Color("Text"),
        LocalizationService.GetUiFontName())
    messageControl := mb.Add("Text", "x60 y20 w220 BackgroundTrans", Message)
    messageControl.GetPos(, , , &messageHeight)
    layout := CalculateDarkDialogLayout(300, messageHeight, [70])
    iconControl.Move(, layout.IconY)
    messageControl.Move(, layout.MessageY)

    ; 确认按钮复用全应用圆角绘制、悬浮和抬起后执行规则。
    btnOk := mb.Add("Text",
        "x" layout.ButtonXs[1] " y" layout.ButtonY
            " w70 h30 Center 0x200 Background"
            UiThemeService.Color("Primary") " c"
            UiThemeService.Color("ButtonText"),
        Tr("确 定"))
    RegisterHoverButton(btnOk, UiThemeService.Color("Primary"))
    mb.Add("Text", "x10 y" layout.BottomY " w1 h15", "") ; 底部留白

    ; 所有关闭入口共享同一幂等收尾函数，避免重复恢复或激活错误窗口。
    closeAction := (*) => CloseDarkMsgBox(mb, ownerLease, &closed)

    RegisterButtonClick(btnOk, closeAction, ButtonFeedbackMode.Dismissive)
    mb.OnEvent("Close", closeAction)
    mb.OnEvent("Escape", closeAction)

    mbHwnd := mb.Hwnd
    mb.Show(ScaleApplicationShowOptions("w300 h" layout.WindowHeight))
    ApplyApplicationWindowScale(mb)
    WinWaitClose(mbHwnd) ; 挂起线程等待弹窗销毁，实现阻塞式的主线程停滞
    } catch as msgErr {
        CloseDarkMsgBox(mb, ownerLease, &closed)
        throw msgErr
    }
}

; 守护事务持有共享工作门时不能显示阻塞式模态窗口。
; 单次定时器会在当前事务返回并释放工作门后再创建消息框。
ShowDarkMsgBoxDeferred(Message, Title := "", MsgType := "Info",
    ownerGui := "") {
    try {
        SetTimer(ShowDarkMsgBox.Bind(Message, Title, MsgType, ownerGui), -1)
        return true
    } catch {
        return false
    }
}

; 需要用户明确选择的更新提示使用双按钮深色对话框，并沿用统一的所有者恢复顺序。
ShowDarkConfirmBox(Message, Title, confirmText, cancelText,
    ownerGui := "") {
    Message := NormalizeUserVisibleParentheses(Message)
    Title := NormalizeUserVisibleParentheses(Title)
    mb := Gui("-MinimizeBox -MaximizeBox", Title)
    try RestoreHoveredButton()
    if IsSet(GuiModules)
        try GuiModules.HideTransientWindows()
    dialogOwner := ownerGui
    if !dialogOwner && IsSet(Main)
        dialogOwner := Main.gui
    ownerLease := ""
    closed := false
    accepted := false
    if dialogOwner && Type(dialogOwner) == "Gui" {
        try {
            if WinExist(dialogOwner.Hwnd) {
                mb.Opt("+Owner" dialogOwner.Hwnd)
                ownerLease := WindowHierarchy.Acquire(dialogOwner, mb.Hwnd)
            }
        }
    }
    try {
        InitializeApplicationWindow(mb)
        mb.SetFont("s18", "Segoe UI Emoji")
        iconControl := mb.Add("Text", "x20 y20 w30 h30 BackgroundTrans c"
            UiThemeService.Color("Text"), "⬆️")
        mb.SetFont("s10 c" UiThemeService.Color("Text"),
            LocalizationService.GetUiFontName())
        messageControl := mb.Add("Text", "x60 y20 w280 BackgroundTrans", Message)
        messageControl.GetPos(, , , &messageHeight)
        layout := CalculateDarkDialogLayout(360, messageHeight,
            [100, 100], 22)
        iconControl.Move(, layout.IconY)
        messageControl.Move(, layout.MessageY)
        btnConfirm := mb.Add("Text",
            "x" layout.ButtonXs[1] " y" layout.ButtonY
                " w100 h30 Center 0x200 Background"
                UiThemeService.Color("Primary") " c"
                UiThemeService.Color("ButtonText"),
            confirmText)
        btnCancel := mb.Add("Text",
            "x" layout.ButtonXs[2] " y" layout.ButtonY
                " w100 h30 Center 0x200 Background"
                UiThemeService.Color("Toolbar") " c"
                UiThemeService.Color("ToolbarText"),
            cancelText)
        mb.Add("Text", "x10 y" layout.BottomY " w1 h15", "")
        RegisterHoverButton(btnConfirm, UiThemeService.Color("Primary"))
        RegisterHoverButton(btnCancel, UiThemeService.Color("Toolbar"))
        closeAction := (*) => CloseDarkMsgBox(mb, ownerLease, &closed)
        acceptAction := (*) => (accepted := true,
            CloseDarkMsgBox(mb, ownerLease, &closed))
        RegisterButtonClick(btnConfirm, acceptAction,
            ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(btnCancel, closeAction,
            ButtonFeedbackMode.Dismissive)
        mb.OnEvent("Close", closeAction)
        mb.OnEvent("Escape", closeAction)
        mbHwnd := mb.Hwnd
        mb.Show(ScaleApplicationShowOptions("w360 h" layout.WindowHeight))
        ApplyApplicationWindowScale(mb)
        WinWaitClose(mbHwnd)
        return accepted
    } catch as confirmError {
        CloseDarkMsgBox(mb, ownerLease, &closed)
        throw confirmError
    }
}

CreateDarkChoiceAction(mb, ownerLease, &closed, &selected, value) {
    return (*) => (selected := value,
        CloseDarkMsgBox(mb, ownerLease, &closed))
}

RefreshDarkChoiceButtons(buttons, mbHwnd, *) {
    if !mbHwnd || !DllCall("user32\IsWindow", "Ptr", mbHwnd, "Int")
        return false
    refreshedAny := false
    for _, button in buttons {
        try RedrawRoundedButton(button.Hwnd)
        catch
            continue
        refreshedAny := true
        try RenderRoundedButtonNow(button.Hwnd)
    }
    return refreshedAny
}

; 四选一深色对话框用于需要明确恢复策略的守护事件。关闭窗口按最后一个选项
; 处理，避免用户关闭提示后目标永远停留在等待选择状态。
ShowDarkChoiceBox(Message, Title, choices, ownerGui := "") {
    if !IsObject(choices) || !choices.Length
        return ""
    Message := NormalizeUserVisibleParentheses(Message)
    Title := NormalizeUserVisibleParentheses(Title)
    mb := Gui("-MinimizeBox -MaximizeBox", Title)
    try RestoreHoveredButton()
    if IsSet(GuiModules)
        try GuiModules.HideTransientWindows()
    dialogOwner := ownerGui
    if !dialogOwner && IsSet(Main)
        dialogOwner := Main.gui
    ownerLease := ""
    closed := false
    selected := choices[choices.Length].Value
    if dialogOwner && Type(dialogOwner) == "Gui" {
        try {
            if WinExist(dialogOwner.Hwnd) {
                mb.Opt("+Owner" dialogOwner.Hwnd)
                ownerLease := WindowHierarchy.Acquire(dialogOwner, mb.Hwnd)
            }
        }
    }
    try {
        InitializeApplicationWindow(mb)
        ; 使用符号字体配合主题警告色，确保警告图标不会被彩色 Emoji 字形覆盖颜色。
        mb.SetFont("s18", "Segoe UI Symbol")
        iconControl := mb.Add("Text", "x20 y20 w30 h30 BackgroundTrans c"
            UiThemeService.Color("WarningIcon"), "⚠")
        mb.SetFont("s10 c" UiThemeService.Color("Text"),
            LocalizationService.GetUiFontName())
        messageControl := mb.Add("Text", "x60 y20 w440 BackgroundTrans",
            Message)
        messageControl.GetPos(, , , &messageHeight)
        buttonWidths := []
        choiceButtons := []
        for choice in choices
            buttonWidths.Push(100)
        layout := CalculateDarkDialogLayout(520, messageHeight,
            buttonWidths, 22)
        iconControl.Move(, layout.IconY)
        messageControl.Move(, layout.MessageY)
        firstChoiceButton := ""
        for index, choice in choices {
            button := mb.Add("Text",
                "x" layout.ButtonXs[index] " y" layout.ButtonY
                    " w" buttonWidths[index] " h30 Center 0x200 Background"
                    (index == 1 ? UiThemeService.Color("Primary")
                        : UiThemeService.Color("Toolbar")) " c"
                    (index == 1 ? UiThemeService.Color("ButtonText")
                        : UiThemeService.Color("ToolbarText")),
                choice.Text)
            buttonValue := choice.Value
            RegisterHoverButton(button,
                index == 1 ? UiThemeService.Color("Primary")
                    : UiThemeService.Color("Toolbar"))
            RegisterButtonClick(button,
                CreateDarkChoiceAction(mb, ownerLease, &closed,
                    &selected, buttonValue), ButtonFeedbackMode.Dismissive)
            choiceButtons.Push(button)
            if index == 1
                firstChoiceButton := button
        }
        mb.Add("Text", "x10 y" layout.BottomY " w1 h15", "")
        closeAction := (*) => CloseDarkMsgBox(mb, ownerLease, &closed)
        mb.OnEvent("Close", closeAction)
        mb.OnEvent("Escape", closeAction)
        mbHwnd := mb.Hwnd
        mb.Show(ScaleApplicationShowOptions("w520 h" layout.WindowHeight))
        ApplyApplicationWindowScale(mb)
        ; 缩放会替换各控件字体并触发窗口重绘；立即和延迟各提交一次 owner-draw，
        ; 避免事件提醒首帧只有按钮表面而遗漏文字层。
        RefreshDarkChoiceButtons(choiceButtons, mbHwnd)
        SetTimer(RefreshDarkChoiceButtons.Bind(choiceButtons, mbHwnd), -1)
        SetTimer(RefreshDarkChoiceButtons.Bind(choiceButtons, mbHwnd), -25)
        ; 首个选项是默认恢复动作。显示后再设置焦点和鼠标位置，确保控件
        ; 已拥有屏幕坐标；窗口激活完成后再确认一次，避免前台切换覆盖定位。
        try firstChoiceButton.Focus()
        try MovePointerToControlCenter(firstChoiceButton)
        SetTimer(ConfirmDarkChoicePointer.Bind(firstChoiceButton, mbHwnd), -1)
        SetTimer(ConfirmDarkChoicePointer.Bind(firstChoiceButton, mbHwnd), -25)
        WinWaitClose(mbHwnd)
        return selected
    } catch as choiceError {
        CloseDarkMsgBox(mb, ownerLease, &closed)
        throw choiceError
    }
}

ConfirmDarkChoicePointer(button, mbHwnd, *) {
    if !mbHwnd || !DllCall("user32\IsWindow", "Ptr", mbHwnd, "Int")
        return
    try MovePointerToControlCenter(button)
}

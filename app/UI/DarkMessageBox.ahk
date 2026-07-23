; ==========================================
; 13. 深色自适应用户交互弹窗面板控制方法集合
; ==========================================
CloseDarkMsgBox(mb, ownerLease, &closed) {
    if closed
        return
    closed := true
    ; 先恢复所有者再销毁弹窗，避免 Windows 因所有者仍禁用而把前台切走。
    closeContext := WindowHierarchy.Release(ownerLease)
    try {
        try UnregisterGuiControls(mb.Hwnd)
        mb.Destroy()
    }
    finally WindowHierarchy.CompleteClose(closeContext)
}

ShowDarkMsgBox(Message, Title := "提示", MsgType := "Info", ownerGui := "") {
    Message := NormalizeUserVisibleParentheses(Message)
    Title := NormalizeUserVisibleParentheses(Title)
    mb := Gui("-MinimizeBox -MaximizeBox", Title)

    try RestoreHoveredButton()
    if IsSet(GuiModules)
        try GuiModules.HideTransientWindows()
    ownerLease := ""
    closed := false
    ; 检查主窗口是否存在，如果存在则将其禁用，模拟原生弹窗的“模态(Modal)”拦截效果
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
    ; 注入底层深色标题栏
    SetDarkTitleBar(mb.Hwnd)
    mb.BackColor := "1E1E1E"

    ; 图标与文字布局
    iconStr := (MsgType == "Error") ? "❌" : "ℹ️" ; <--- 同步修改这里
    mb.SetFont("s18", "Segoe UI Emoji")
    mb.Add("Text", "x20 y20 w30 h30 BackgroundTrans cWhite", iconStr)

    mb.SetFont("s10 cWhite", "Microsoft YaHei")
    mb.Add("Text", "x60 y25 w220 BackgroundTrans", Message)

    ; 扁平化深色按钮
    btnOk := mb.Add("Text", "x115 y+20 w70 h30 Center 0x200 Background0078D7 cWhite", "确 定")
    RegisterHoverButton(btnOk, "0078D7")
    mb.Add("Text", "x10 y+0 h15", "") ; 底部留白

    ; 销毁窗口并恢复主窗口交互
    closeAction := (*) => CloseDarkMsgBox(mb, ownerLease, &closed)

    RegisterButtonClick(btnOk, closeAction, ButtonFeedbackMode.Dismissive)
    mb.OnEvent("Close", closeAction)
    mb.OnEvent("Escape", closeAction)

    mb.Show("w300 AutoSize")
    WinWaitClose(mb.Hwnd) ; 挂起线程等待弹窗销毁，实现阻塞式的主线程停滞
    } catch as msgErr {
        CloseDarkMsgBox(mb, ownerLease, &closed)
        throw msgErr
    }
}

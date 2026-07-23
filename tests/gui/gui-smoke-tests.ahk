#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\UI\WindowHierarchy.ahk

AssertGuiSmoke(condition, message) {
    if !condition
        throw Error(message)
}

owner := ""
child := ""
try {
    owner := Gui("+Resize +MinSize420x260", "GUI smoke owner")
    owner.BackColor := "1E1E1E"
    owner.SetFont("s10 cFFFFFF", "Microsoft YaHei UI")
    owner.Add("Text", "x16 y14 w180 BackgroundTrans", "Process watchdog")
    owner.Add("Edit", "x16 y42 w260 h28 Background252526 cFFFFFF", "editable")
    list := owner.Add("ListView", "x16 y82 w380 h120 -Hdr Background202020 cFFFFFF",
        ["Name", "State"])
    list.Add("", "Smoke target", "Running")
    owner.Add("Button", "x16 y216 w88 h30", "Action")
    owner.Show("Hide w430 h270")

    AssertGuiSmoke(DllCall("user32\IsWindow", "Ptr", owner.Hwnd, "Int"),
        "Owner GUI handle was not created")
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", owner.Hwnd, "UInt")
    AssertGuiSmoke(dpi >= 96, "GUI DPI was not available")
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", owner.Hwnd,
        "Int", 20, "Int*", 1, "Int", 4)
    try DllCall("uxtheme\SetWindowTheme", "Ptr", list.Hwnd,
        "Str", "DarkMode_Explorer", "Ptr", 0)

    child := Gui("+Owner" owner.Hwnd " +Resize", "GUI smoke child")
    child.BackColor := "1E1E1E"
    child.Add("Text", "x12 y12 w180 cFFFFFF BackgroundTrans", "Child window")
    child.Show("Hide w260 h140")

    hierarchy := WindowHierarchyManager(WindowHierarchyPlatform())
    lease := hierarchy.Acquire(owner, child.Hwnd)
    AssertGuiSmoke(IsObject(lease), "Owner lease was not acquired")
    AssertGuiSmoke(!DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd, "Int"),
        "Owner GUI was not disabled while child lease was active")
    releasedContext := hierarchy.Release(lease)
    hierarchy.CompleteClose(releasedContext)
    AssertGuiSmoke(DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd, "Int"),
        "Owner GUI was not restored after child lease release")

    imageList := IL_Create(2, 2, true)
    AssertGuiSmoke(imageList != 0, "ImageList creation failed")
    IL_Destroy(imageList)
} finally {
    if child
        try child.Destroy()
    if owner
        try owner.Destroy()
}

FileAppend("GUI_SMOKE|PASS|dpi=" dpi "`n", "*")
ExitApp(0)

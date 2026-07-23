#Requires AutoHotkey v2.0
#SingleInstance Force

SetTabTheme(hWnd, theme) {
    try DllCall("uxtheme\SetWindowTheme", "Ptr", hWnd, "Str", theme, "Ptr", 0)
}

testGui := Gui("+AlwaysOnTop", "Codex Tab Theme Test")
testGui.OnEvent("Close", (*) => ExitApp())
testGui.BackColor := "1E1E1E"
testGui.SetFont("s10 cWhite", "Microsoft YaHei")

testGui.Add("Text", "x15 y10 cWhite", "DarkMode_Explorer")
tab1 := testGui.Add("Tab3", "x15 y30 w500 h80 Background1E1E1E cD0D0D0", ["Monitor", "Stop", "Logs", "Search", "System"])
SetTabTheme(tab1.Hwnd, "DarkMode_Explorer")

testGui.Add("Text", "x15 y120 cWhite", "DarkMode_ItemsView")
tab2 := testGui.Add("Tab3", "x15 y140 w500 h80 Background1E1E1E cD0D0D0", ["Monitor", "Stop", "Logs", "Search", "System"])
SetTabTheme(tab2.Hwnd, "DarkMode_ItemsView")

testGui.Add("Text", "x15 y230 cWhite", "Explorer")
tab3 := testGui.Add("Tab3", "x15 y250 w500 h80 Background1E1E1E cD0D0D0", ["Monitor", "Stop", "Logs", "Search", "System"])
SetTabTheme(tab3.Hwnd, "Explorer")

testGui.Add("Text", "x15 y340 cWhite", "Classic")
tab4 := testGui.Add("Tab3", "x15 y360 w500 h80 Background1E1E1E cD0D0D0", ["Monitor", "Stop", "Logs", "Search", "System"])
SetTabTheme(tab4.Hwnd, "")

testGui.Show("x100 y100 w530 h455")

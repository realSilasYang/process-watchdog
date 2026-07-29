#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 反复创建和销毁完整界面场景，观察 GDI 与 USER 句柄是否稳定。
; 循环覆盖按钮、输入框、图标和多级窗口，结束后资源增量必须回到允许范围。

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\TraditionalHongKongStrings.ahk
#Include ..\..\src\Localization\TraditionalTaiwanStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\SpanishStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\PortugueseBrazilStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\ItalianStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk
#Include ..\..\src\UI\UiThemeService.ahk
#Include ..\..\src\UI\UiInteractionRegistry.ahk
#Include ..\..\src\UI\ControlAccessibilityService.ahk
#Include ..\..\src\UI\WindowHierarchy.ahk
#Include ..\..\app\UI\InteractionPresenter.ahk

UiThemeService.Configure("dark")
global App := {uiInteractions: UiInteractionRegistry()}
global soakClickCount := 0

; 此测试独立加载交互层，不加载完整应用适配层；仍提供与正式入口等价的
; 资源目录定位函数，使共享 Lucide 按钮入口在 #Warn All 下也能完整解析。
GetApplicationAssetPath(relativePath) {
    return A_ScriptDir "\..\..\assets\" relativePath
}

GetTickCount64() {
    return DllCall("kernel32\GetTickCount64", "UInt64")
}

OnSoakButtonClick(*) {
    global soakClickCount
    soakClickCount++
}

GetGuiResourceCount(kind) {
    processHandle := DllCall("kernel32\GetCurrentProcess", "Ptr")
    return DllCall("user32\GetGuiResources", "Ptr", processHandle,
        "UInt", kind, "UInt")
}

FailSoak(message) {
    failRecord := "RESOURCE_SOAK|FAIL|" message "`n"
    FileAppend(failRecord, "*")
    ExitApp(1)
}

DrawSoakButton(button) {
    if !App.uiInteractions.HasButton(button.Hwnd)
        return false
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    if !screenDc
        return false
    targetDc := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDc, "Ptr")
    targetBitmap := targetDc ? DllCall("gdi32\CreateCompatibleBitmap",
        "Ptr", screenDc, "Int", 88, "Int", 30, "Ptr") : 0
    if !targetDc || !targetBitmap {
        if targetBitmap
            DllCall("gdi32\DeleteObject", "Ptr", targetBitmap)
        if targetDc
            DllCall("gdi32\DeleteDC", "Ptr", targetDc)
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
        return false
    }
    previousBitmap := DllCall("gdi32\SelectObject", "Ptr", targetDc,
        "Ptr", targetBitmap, "Ptr")
    try return RoundedButtonRenderer.Draw(targetDc, 88, 30,
        App.uiInteractions.GetButton(button.Hwnd))
    finally {
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", targetDc,
                "Ptr", previousBitmap)
        DllCall("gdi32\DeleteObject", "Ptr", targetBitmap)
        DllCall("gdi32\DeleteDC", "Ptr", targetDc)
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
    }
}

RegisterSoakButton(button, normalColor, feedbackMode) {
    hoverColor := ResolveButtonHoverColor(normalColor)
    state := {
        ctrl: button,
        normal: normalColor,
        hover: hoverColor,
        pressed: ResolveButtonFeedbackPressedColor(normalColor, hoverColor,
            "", feedbackMode),
        requestedPressed: "",
        feedbackMode: feedbackMode,
        current: normalColor,
        textColor: "FFFFFF",
        roundedOwnerDraw: false
    }
    if !App.uiInteractions.RegisterButton(button.Hwnd, state)
        return false
    RegisterButtonClick(button, OnSoakButtonClick, feedbackMode)
    return true
}

try {
durationSeconds := 10
if A_Args.Length {
    try durationSeconds := Integer(A_Args[1])
}
durationSeconds := Max(1, Min(durationSeconds, 3600))

initialGdi := GetGuiResourceCount(0)
initialUser := GetGuiResourceCount(1)
maximumGdi := initialGdi
maximumUser := initialUser
iterations := 0
baselineEstablished := false
deadline := GetTickCount64() + durationSeconds * 1000

while GetTickCount64() < deadline {
    owner := ""
    child := ""
    grandchild := ""
    hierarchy := ""
    ownerLease := ""
    childLease := ""
    imageList := 0
    list := ""
    try {
        owner := Gui("+Resize", "Resource soak owner")
        owner.BackColor := UiThemeService.Color("Window")
        owner.SetFont("s10 c" UiThemeService.Color("Text"),
            "Microsoft YaHei UI")
        inputBackground := owner.Add("Text",
            "x10 y10 w190 h30 Background" UiThemeService.Color("Input"))
        input := owner.Add("Edit",
            "x14 y12 w182 h26 Background" UiThemeService.Color("Input")
                " c" UiThemeService.Color("Text") " -E0x200",
            "iteration " iterations)
        RegisterTextInputControl(input)
        RegisterTextInputHitTarget(inputBackground, input)

        actionButton := owner.Add("Text",
            "x210 y10 w88 h30 Center 0x200 Background"
                UiThemeService.Color("Add") " c"
                UiThemeService.Color("ButtonText"),
            "Action")
        if !RegisterSoakButton(actionButton, UiThemeService.Color("Add"),
            ButtonFeedbackMode.Persistent)
            FailSoak("button registration failed")
        SetButtonTextColor(actionButton, UiThemeService.Color("ButtonText"))

        list := owner.Add("ListView",
            "x10 y48 w288 h116 -Hdr Background"
                UiThemeService.Color("Tooltip") " c"
                UiThemeService.Color("Text"),
            ["Name", "State"])
        imageList := IL_Create(4, 4, true)
        if !imageList
            FailSoak("ImageList creation failed")
        sharedIcon := DllCall("user32\LoadIconW", "Ptr", 0,
            "Ptr", 32512, "Ptr") ; IDI_APPLICATION：使用系统共享的默认应用图标。
        if !sharedIcon || !IL_Add(imageList, "HICON:" sharedIcon)
            FailSoak("ImageList icon insertion failed")
        list.SetImageList(imageList, 1)
        Loop 20
            list.Add("Icon1", "Target " A_Index,
                Mod(A_Index, 2) ? "Running" : "Paused")

        logEdit := owner.Add("Edit",
            "x10 y172 w288 h86 ReadOnly Multi VScroll HScroll -Wrap Background"
                UiThemeService.Color("Surface") " c"
                UiThemeService.Color("Text") " -E0x200")
        RegisterTextInputControl(logEdit, true, true)
        logText := ""
        Loop 60
            logText .= Format("{1:02} iteration {2} diagnostic line`r`n",
                A_Index, iterations)
        logEdit.Value := logText
        SendMessage(Win32.EM_SETSEL, StrLen(logText), StrLen(logText),
            logEdit.Hwnd)
        SendMessage(Win32.EM_LINESCROLL, 0, 10, logEdit.Hwnd)
        owner.Show("Hide w308 h270")

        if !DrawSoakButton(actionButton)
            FailSoak("rounded button rendering failed")

        child := Gui("+Owner" owner.Hwnd, "Resource soak child")
        child.BackColor := UiThemeService.Color("Window")
        childButton := child.Add("Text",
            "x10 y10 w88 h30 Center 0x200 Background"
                UiThemeService.Color("Toolbar") " c"
                UiThemeService.Color("ToolbarText"),
            "Child")
        if !RegisterSoakButton(childButton,
            UiThemeService.Color("Toolbar"),
            ButtonFeedbackMode.Dismissive)
            FailSoak("child button registration failed")
        child.Show("Hide w110 h52")

        grandchild := Gui("+Owner" child.Hwnd, "Resource soak grandchild")
        grandchild.BackColor := UiThemeService.Color("Window")
        grandchild.Add("Text", "x8 y8 w94 h24 c"
            UiThemeService.Color("Text") " BackgroundTrans",
            "Nested owner")
        grandchild.Show("Hide w112 h42")

        hierarchy := WindowHierarchyManager(WindowHierarchyPlatform())
        ownerLease := hierarchy.Acquire(owner, child.Hwnd)
        if !IsObject(ownerLease)
            FailSoak("owner lease acquisition failed")
        childLease := hierarchy.Acquire(child, grandchild.Hwnd)
        if !IsObject(childLease)
            FailSoak("nested owner lease acquisition failed")
        releasedContext := hierarchy.Release(childLease)
        childLease := ""
        hierarchy.CompleteClose(releasedContext)
        if !DllCall("user32\IsWindowEnabled", "Ptr", child.Hwnd, "Int")
            FailSoak("nested owner was not restored")
        releasedContext := hierarchy.Release(ownerLease)
        ownerLease := ""
        hierarchy.CompleteClose(releasedContext)
        if !DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd, "Int")
            FailSoak("root owner was not restored")
    } finally {
        if hierarchy && childLease {
            try hierarchy.CompleteClose(hierarchy.Release(childLease))
        }
        if hierarchy && ownerLease {
            try hierarchy.CompleteClose(hierarchy.Release(ownerLease))
        }
        if grandchild {
            try UnregisterGuiControls(grandchild.Hwnd)
            try grandchild.Destroy()
        }
        if child
            try UnregisterGuiControls(child.Hwnd)
        if child
            try child.Destroy()
        if owner {
            try UnregisterGuiControls(owner.Hwnd)
            if list && imageList
                try list.SetImageList(0, 1)
            try owner.Destroy()
        }
        if imageList
            try IL_Destroy(imageList)
    }
    iterations++
    list := ""
    hierarchy := ""
    ownerLease := ""
    childLease := ""
    releasedContext := ""
    grandchild := ""
    child := ""
    owner := ""
    if App.uiInteractions.Buttons.Count
        || App.uiInteractions.TextInputs.Count
        FailSoak("UI interaction registrations survived GUI destruction")
    currentGdi := GetGuiResourceCount(0)
    currentUser := GetGuiResourceCount(1)
    if (!baselineEstablished && iterations >= 5) {
        initialGdi := currentGdi
        initialUser := currentUser
        maximumGdi := currentGdi
        maximumUser := currentUser
        baselineEstablished := true
    } else if baselineEstablished {
        maximumGdi := Max(maximumGdi, currentGdi)
        maximumUser := Max(maximumUser, currentUser)
    }
    Sleep(1)
}

Sleep(100)
finalGdi := GetGuiResourceCount(0)
finalUser := GetGuiResourceCount(1)
gdiDelta := finalGdi - initialGdi
userDelta := finalUser - initialUser
if (gdiDelta > 8 || userDelta > 8) {
    resourceFailure := "RESOURCE_SOAK|FAIL|seconds=" durationSeconds
        . "|iterations=" iterations "|gdiDelta=" gdiDelta
        . "|userDelta=" userDelta "|maxGdi=" maximumGdi
        . "|maxUser=" maximumUser "`n"
    FileAppend(resourceFailure, "*")
    ExitApp(1)
}

ShutdownRoundedButtonRenderer()

FileAppend("RESOURCE_SOAK|PASS|seconds=" durationSeconds
    "|iterations=" iterations "|gdiDelta=" gdiDelta
    "|userDelta=" userDelta "|maxGdi=" maximumGdi
    "|maxUser=" maximumUser "|scenario=full-ui`n", "*")
} catch as soakError {
    catchRecord := "RESOURCE_SOAK|FAIL|exception=" soakError.Message
        . "|file=" soakError.File "|line=" soakError.Line "`n"
    FileAppend(catchRecord, "*")
    ExitApp(1)
}
ExitApp(0)

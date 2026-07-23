#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\UI\UiInteractionRegistry.ahk
#Include ..\..\src\UI\WindowHierarchy.ahk
#Include ..\..\app\UI\InteractionPresenter.ahk

global App := {uiInteractions: UiInteractionRegistry()}
global soakClickCount := 0

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
    deviceContext := DllCall("user32\GetDC", "Ptr", button.Hwnd, "Ptr")
    if !deviceContext
        return false
    try return RoundedButtonRenderer.Draw(deviceContext, 88, 30,
        App.uiInteractions.GetButton(button.Hwnd))
    finally DllCall("user32\ReleaseDC", "Ptr", button.Hwnd,
        "Ptr", deviceContext)
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
        owner.BackColor := "1E1E1E"
        owner.SetFont("s10 cFFFFFF", "Microsoft YaHei UI")
        inputBackground := owner.Add("Text",
            "x10 y10 w190 h30 Background252526")
        input := owner.Add("Edit",
            "x14 y12 w182 h26 Background252526 cFFFFFF -E0x200",
            "iteration " iterations)
        RegisterTextInputControl(input)
        RegisterTextInputHitTarget(inputBackground, input)

        actionButton := owner.Add("Text",
            "x210 y10 w88 h30 Center 0x200 Background3F6B5B cFFFFFF",
            "Action")
        if !RegisterSoakButton(actionButton, "3F6B5B",
            ButtonFeedbackMode.Persistent)
            FailSoak("button registration failed")
        SetButtonTextColor(actionButton, "FFFFFF")

        list := owner.Add("ListView",
            "x10 y48 w288 h116 -Hdr Background202020 cFFFFFF",
            ["Name", "State"])
        imageList := IL_Create(4, 4, true)
        if !imageList
            FailSoak("ImageList creation failed")
        sharedIcon := DllCall("user32\LoadIconW", "Ptr", 0,
            "Ptr", 32512, "Ptr") ; IDI_APPLICATION
        if !sharedIcon || !IL_Add(imageList, "HICON:" sharedIcon)
            FailSoak("ImageList icon insertion failed")
        list.SetImageList(imageList, 1)
        Loop 20
            list.Add("Icon1", "Target " A_Index,
                Mod(A_Index, 2) ? "Running" : "Paused")

        logEdit := owner.Add("Edit",
            "x10 y172 w288 h86 ReadOnly Multi VScroll HScroll -Wrap Background252526 cFFFFFF -E0x200")
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
        child.BackColor := "1E1E1E"
        childButton := child.Add("Text",
            "x10 y10 w88 h30 Center 0x200 Background3A4656 cFFFFFF",
            "Child")
        if !RegisterSoakButton(childButton, "3A4656",
            ButtonFeedbackMode.Dismissive)
            FailSoak("child button registration failed")
        child.Show("Hide w110 h52")

        grandchild := Gui("+Owner" child.Hwnd, "Resource soak grandchild")
        grandchild.BackColor := "1E1E1E"
        grandchild.Add("Text", "x8 y8 w94 h24 cFFFFFF BackgroundTrans",
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

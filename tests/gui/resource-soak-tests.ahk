#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\UI\WindowHierarchy.ahk

GetGuiResourceCount(kind) {
    processHandle := DllCall("kernel32\GetCurrentProcess", "Ptr")
    return DllCall("user32\GetGuiResources", "Ptr", processHandle,
        "UInt", kind, "UInt")
}

FailSoak(message) {
    FileAppend("RESOURCE_SOAK|FAIL|" message "`n", "*")
    ExitApp(1)
}

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
deadline := DllCall("kernel32\GetTickCount64", "UInt64")
    + durationSeconds * 1000

while DllCall("kernel32\GetTickCount64", "UInt64") < deadline {
    owner := ""
    child := ""
    try {
        owner := Gui("+Resize", "Resource soak owner")
        owner.BackColor := "1E1E1E"
        owner.Add("Edit", "x10 y10 w180 h26 Background252526 cFFFFFF",
            "iteration " iterations)
        list := owner.Add("ListView", "x10 y46 w260 h120 -Hdr Background202020 cFFFFFF",
            ["Name", "State"])
        Loop 20
            list.Add("", "Target " A_Index, Mod(A_Index, 2) ? "Running" : "Paused")
        owner.Show("Hide w290 h190")

        child := Gui("+Owner" owner.Hwnd, "Resource soak child")
        child.Add("Button", "x10 y10 w80 h28", "Close")
        child.Show("Hide w110 h55")
        hierarchy := WindowHierarchyManager(WindowHierarchyPlatform())
        lease := hierarchy.Acquire(owner, child.Hwnd)
        if !IsObject(lease)
            FailSoak("owner lease acquisition failed")
        releasedContext := hierarchy.Release(lease)
        hierarchy.CompleteClose(releasedContext)

        imageList := IL_Create(16, 4, true)
        if !imageList
            FailSoak("ImageList creation failed")
        IL_Destroy(imageList)
    } finally {
        if child
            try child.Destroy()
        if owner
            try owner.Destroy()
    }
    iterations++
    list := ""
    hierarchy := ""
    lease := ""
    releasedContext := ""
    child := ""
    owner := ""
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

Sleep(50)
finalGdi := GetGuiResourceCount(0)
finalUser := GetGuiResourceCount(1)
gdiDelta := finalGdi - initialGdi
userDelta := finalUser - initialUser
if (gdiDelta > 8 || userDelta > 8) {
    FileAppend("RESOURCE_SOAK|FAIL|seconds=" durationSeconds
        "|iterations=" iterations "|gdiDelta=" gdiDelta
        "|userDelta=" userDelta "|maxGdi=" maximumGdi
        "|maxUser=" maximumUser "`n", "*")
    ExitApp(1)
}

FileAppend("RESOURCE_SOAK|PASS|seconds=" durationSeconds
    "|iterations=" iterations "|gdiDelta=" gdiDelta
    "|userDelta=" userDelta "|maxGdi=" maximumGdi
    "|maxUser=" maximumUser "`n", "*")
ExitApp(0)

#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证原生进程检查器读取路径、创建身份、父进程和权限提升状态。
; 访问拒绝与 PID 复用必须保持不确定语义，不能被误判成目标已停止。

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Inspection\ProcessSnapshotIndex.ahk
#Include ..\..\src\Inspection\ProcessInspector.ahk

AssertProcessInspector(value, message) {
    if !value
        throw Error(message)
}

RunProcessInspectorTests() {
    inspector := ProcessInspector()
    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    imagePath := inspector.GetImagePath(currentPid)
    AssertProcessInspector(imagePath != "",
        "无法读取当前进程的完整镜像路径")

    creationIdentity := inspector.GetCreationIdentity(currentPid)
    AssertProcessInspector(RegExMatch(creationIdentity, "^[0-9A-F]{16}$"),
        "当前进程创建身份格式无效")

    elevationState := inspector.GetElevationState(currentPid)
    AssertProcessInspector(elevationState == 0 || elevationState == 1,
        "当前进程提权状态不可判定")

    snapshot := inspector.CaptureNativeSnapshot()
    AssertProcessInspector(snapshot.Ready
        && Type(snapshot.Processes) == "Array",
        "原生进程快照创建失败")
    currentFound := false
    for processInfo in snapshot.Processes {
        if processInfo.pid != currentPid
            continue
        currentFound := true
        AssertProcessInspector(processInfo.observedTicks
            == snapshot.CapturedAtTicks,
            "快照条目与快照本身的采集时间不一致")
        break
    }
    AssertProcessInspector(currentFound,
        "原生进程快照没有包含当前进程")

    autoHotkeySnapshot := inspector.CaptureAutoHotkeyScriptSnapshot()
    currentScriptFound := false
    for scriptInfo in autoHotkeySnapshot.Scripts {
        if (scriptInfo.PID == currentPid
            && ProcessSnapshotIndex.NormalizePath(scriptInfo.Path)
                == ProcessSnapshotIndex.NormalizePath(A_ScriptFullPath)) {
            currentScriptFound := true
            break
        }
    }
    AssertProcessInspector(autoHotkeySnapshot.Ready && currentScriptFound,
        "AutoHotkey 主窗口快照没有识别当前脚本")

    deadPid := 0x7FFFFFFF
    while (deadPid > 0 && ProcessExist(deadPid))
        deadPid--
    AssertProcessInspector(inspector.GetImagePath(deadPid) == "",
        "不存在的 PID 不应返回镜像路径")
    AssertProcessInspector(inspector.GetCreationIdentity(deadPid) == "",
        "不存在的 PID 不应返回创建身份")
    AssertProcessInspector(inspector.GetElevationState(deadPid) == -1,
        "不存在的 PID 不应返回确定的提权状态")
}

try {
    RunProcessInspectorTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

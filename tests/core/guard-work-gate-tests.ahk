#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Core\GuardWorkGate.ahk

AssertGuardWorkGate(value, message) {
    if !value
        throw Error(message)
}

RunGuardWorkGateTests() {
    gate := GuardWorkGate()
    AssertGuardWorkGate(gate.TryEnter(), "空闲工作门无法获取")
    AssertGuardWorkGate(gate.Busy, "工作门获取后没有进入忙碌状态")
    AssertGuardWorkGate(!gate.TryEnter(), "工作门允许重复进入")
    gate.Leave()
    AssertGuardWorkGate(!gate.Busy && gate.TryEnter(),
        "工作门释放后无法重新进入")
    gate.Leave()

    Critical("On")
    try {
        AssertGuardWorkGate(gate.TryEnter(), "临界线程无法获取工作门")
        AssertGuardWorkGate(A_IsCritical != 0,
            "工作门获取破坏了调用方的临界状态")
        gate.Leave()
        AssertGuardWorkGate(A_IsCritical != 0,
            "工作门释放破坏了调用方的临界状态")
    } finally Critical("Off")
}

try {
    RunGuardWorkGateTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

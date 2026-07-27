#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证配置历史栈的容量、撤销、重做和失败回滚契约。
; 只有成功应用的记录才会换栈，失败记录必须留在原处供用户再次尝试。

#Include ..\..\src\Core\AppConfigHistoryService.ahk

AssertAppConfigHistory(value, message) {
    if !value
        throw Error(message)
}

class AppConfigHistorySnapshotService {
    PrepareState(stateArray) {
        items := []
        if (Type(stateArray) != "Array")
            return {Items: items}
        for item in stateArray
            items.Push({Path: item.Path, Value: item.Value})
        return {Items: items}
    }

    StatesEqual(firstState, secondState) {
        if (firstState.Length != secondState.Length)
            return false
        for index, firstItem in firstState {
            secondItem := secondState[index]
            if (firstItem.Path != secondItem.Path
                || firstItem.Value != secondItem.Value)
                return false
        }
        return true
    }
}

AppConfigHistoryState(value) {
    return [{Path: "C:\App.exe", Value: value}]
}

RecordAppConfigHistoryTransition(calls, targetState, sourceState) {
    calls.Push({Target: targetState[1].Value, Source: sourceState[1].Value})
}

ThrowAppConfigHistoryTransition(*) {
    throw Error("模拟差异应用失败")
}

RecordCustomHistoryTransition(calls, targetState, sourceState) {
    calls.Push({Target: targetState.Value, Source: sourceState.Value})
}

RunReentrantAppConfigHistoryUndo(historyService, result, targetState,
    sourceState) {
    result.InnerAccepted := historyService.Undo((*) => 0)
    result.Target := targetState[1].Value
    result.Source := sourceState[1].Value
}

RunAppConfigHistoryServiceTests() {
    snapshotService := AppConfigHistorySnapshotService()
    historyService := AppConfigHistoryService(snapshotService, 2)
    AssertAppConfigHistory(!historyService.Commit("", AppConfigHistoryState(1))
        && !historyService.Commit(AppConfigHistoryState(1),
            AppConfigHistoryState(1)),
        "无效或无变化状态仍创建了撤销记录")

    historyService.Commit(AppConfigHistoryState(1), AppConfigHistoryState(2))
    historyService.Commit(AppConfigHistoryState(2), AppConfigHistoryState(3))
    action := {Kind: "edit-path", Paths: ["C:\App.exe"], Fields: []}
    historyService.Commit(AppConfigHistoryState(3), AppConfigHistoryState(4),
        action)
    AssertAppConfigHistory(historyService.GetUndoCount() == 2
        && historyService.GetRedoCount() == 0,
        "撤销历史没有按上限淘汰最旧记录")

    calls := []
    AssertAppConfigHistory(historyService.Undo(
        RecordAppConfigHistoryTransition.Bind(calls), &appliedEntry)
        && calls[1].Target == 3 && calls[1].Source == 4
        && appliedEntry.Action.Kind == "edit-path"
        && appliedEntry.Action.Paths[1] == "C:\App.exe"
        && historyService.GetUndoCount() == 1
        && historyService.GetRedoCount() == 1,
        "撤销没有应用显式反向转换或移动历史记录")

    failureRaised := false
    try historyService.Undo(ThrowAppConfigHistoryTransition)
    catch {
        failureRaised := true
    }
    AssertAppConfigHistory(failureRaised
        && historyService.GetUndoCount() == 1
        && historyService.GetRedoCount() == 1
        && historyService.CanUndo(),
        "差异应用失败后撤销记录丢失或服务未恢复可用")

    AssertAppConfigHistory(historyService.Undo(
        RecordAppConfigHistoryTransition.Bind(calls))
        && calls[2].Target == 2 && calls[2].Source == 3
        && historyService.Redo(RecordAppConfigHistoryTransition.Bind(calls))
        && calls[3].Target == 3 && calls[3].Source == 2,
        "失败重试或重做没有使用正确的转换方向")
    AssertAppConfigHistory(historyService.Commit(AppConfigHistoryState(3),
        AppConfigHistoryState(5)) && historyService.GetRedoCount() == 0,
        "新操作提交后没有清空已经分叉的重做历史")

    reentrantHistory := AppConfigHistoryService(snapshotService, 2)
    reentrantHistory.Commit(AppConfigHistoryState(10),
        AppConfigHistoryState(11))
    reentrantResult := {InnerAccepted: true, Target: 0, Source: 0}
    AssertAppConfigHistory(reentrantHistory.Undo(
        RunReentrantAppConfigHistoryUndo.Bind(reentrantHistory,
            reentrantResult))
        && !reentrantResult.InnerAccepted
        && reentrantResult.Target == 10 && reentrantResult.Source == 11,
        "撤销应用期间接受了重入操作或传递了错误状态")

    customCalls := []
    customHistory := AppConfigHistoryService(snapshotService, 3)
    customAction := {Kind: "runtime-settings", Paths: [],
        Fields: ["Theme"]}
    AssertAppConfigHistory(customHistory.CommitCustom({Value: "dark"},
        {Value: "light"}, RecordCustomHistoryTransition.Bind(customCalls),
        customAction), "自定义历史记录未被接受")
    AssertAppConfigHistory(customHistory.Undo((*) => 0, &customUndoEntry)
        && customCalls[1].Target == "dark"
        && customCalls[1].Source == "light"
        && customUndoEntry.Action.Kind == "runtime-settings"
        && customUndoEntry.Action.Fields[1] == "Theme",
        "自定义历史没有使用专属回调或返回动作信息")
    AssertAppConfigHistory(customHistory.Redo((*) => 0, &customRedoEntry)
        && customCalls[2].Target == "light"
        && customCalls[2].Source == "dark"
        && customRedoEntry == customUndoEntry,
        "自定义历史重做没有使用正确方向或返回同一记录")

    failingCustomHistory := AppConfigHistoryService(snapshotService, 2)
    failingCustomHistory.CommitCustom({Value: 1}, {Value: 2},
        ThrowAppConfigHistoryTransition, customAction)
    customFailureRaised := false
    try failingCustomHistory.Undo((*) => 0)
    catch
        customFailureRaised := true
    AssertAppConfigHistory(customFailureRaised
        && failingCustomHistory.GetUndoCount() == 1
        && failingCustomHistory.GetRedoCount() == 0,
        "自定义历史应用失败后仍错误换栈")
}

try {
    RunAppConfigHistoryServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

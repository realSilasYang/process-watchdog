#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

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
    historyService.Commit(AppConfigHistoryState(3), AppConfigHistoryState(4))
    AssertAppConfigHistory(historyService.GetUndoCount() == 2
        && historyService.GetRedoCount() == 0,
        "撤销历史没有按上限淘汰最旧记录")

    calls := []
    AssertAppConfigHistory(historyService.Undo(
        RecordAppConfigHistoryTransition.Bind(calls))
        && calls[1].Target == 3 && calls[1].Source == 4
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
}

try {
    RunAppConfigHistoryServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

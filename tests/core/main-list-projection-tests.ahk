#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\UI\MainListProjection.ahk

class FakeMainListView {
    __New(paths := "") {
        this.Paths := Type(paths) == "Array" ? paths : []
        this.GetTextCalls := 0
    }

    GetCount() {
        return this.Paths.Length
    }

    GetText(row, column) {
        this.GetTextCalls++
        return column == 3 && row >= 1 && row <= this.Paths.Length
            ? this.Paths[row] : ""
    }
}

NormalizeProjectionTestPath(path) {
    return StrReplace(Trim(path), "/", "\")
}

AssertProjection(value, message) {
    if !value
        throw Error(message)
}

AssertProjectionEqual(expected, actual, message) {
    if expected != actual
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

RunMainListProjectionTests() {
    listView := FakeMainListView([
        "C:\Apps\Alpha.exe",
        "C:\Apps\Beta.exe",
        "C:\Apps\Gamma.exe"
    ])
    projection := MainListProjection(NormalizeProjectionTestPath)
    AssertProjectionEqual(3, projection.Rebuild(listView),
        "主列表投影索引数量错误")
    AssertProjectionEqual(2, projection.Find(listView,
        "c:/apps/BETA.exe"), "规范化路径未命中投影行")

    listView.Paths := [
        "C:\Apps\Gamma.exe",
        "C:\Apps\Alpha.exe",
        "C:\Apps\Beta.exe"
    ]
    AssertProjectionEqual(3, projection.Find(listView,
        "C:\Apps\Beta.exe"), "列表重排后索引没有自愈")
    listView.Paths.RemoveAt(2)
    AssertProjectionEqual(0, projection.Find(listView,
        "C:\Apps\Alpha.exe"), "列表删除后仍返回旧行")

    listView.Paths.Push("C:\Apps\Gamma.exe")
    AssertProjection(projection.Remember("C:\Apps\Gamma.exe", 3),
        "新增行未登记到投影索引")
    AssertProjectionEqual(3, projection.Find(listView,
        "C:\Apps\Gamma.exe"), "增量登记的行无法查询")

    manyPaths := []
    Loop 1000
        manyPaths.Push("C:\Apps\App" A_Index ".exe")
    largeListView := FakeMainListView(manyPaths)
    projection.Rebuild(largeListView)
    largeListView.GetTextCalls := 0
    Loop 1000 {
        row := projection.Find(largeListView,
            "C:\Apps\App" A_Index ".exe")
        AssertProjectionEqual(A_Index, row, "批量路径投影行错误")
    }
    AssertProjection(largeListView.GetTextCalls <= 1000,
        "稳定投影查询退化为逐次全表扫描")
}

try {
    RunMainListProjectionTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n", "**")
    ExitApp(1)
}

#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\UI\IconResourceRegistry.ahk

IconRegistryTestRebuild(generation, expectedDpi, *) {
    return generation ":" expectedDpi
}

AssertIconRegistry(value, message) {
    if !value
        throw Error(message)
}

AssertIconRegistryEqual(expected, actual, message) {
    if expected != actual
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

RunIconResourceRegistryTests() {
    registry := IconResourceRegistry()
    AssertIconRegistry(registry.StoreCachedIcon(100, "C:\Apps\One.exe", 3)
        && registry.HasCachedIcon(100, "c:\apps\ONE.exe")
        && registry.GetCachedIcon(100, "C:\APPS\one.exe") == 3,
        "图标缓存没有保持路径大小写不敏感")
    registry.StoreCachedIcon(101, "C:\Apps\One.exe", 4)
    AssertIconRegistryEqual(1, registry.ClearImageListCache(100),
        "按 ImageList 清理缓存数量错误")
    AssertIconRegistry(!registry.HasCachedIcon(100, "C:\Apps\One.exe")
        && registry.GetCachedIcon(101, "C:\Apps\One.exe") == 4,
        "清理一个 ImageList 时污染了其他列表缓存")

    firstPair := [11, 12]
    secondPair := [21, 22]
    AssertIconRegistry(registry.ReplaceWindowIcons(200, firstPair).Length == 0
        && registry.ReplaceWindowIcons(200, secondPair) == firstPair,
        "窗口图标对替换没有返回原所有权")
    AssertIconRegistry(registry.TakeWindowIcons(200) == secondPair
        && registry.TakeWindowIcons(200) == "",
        "窗口图标所有权提取没有保持幂等")

    AssertIconRegistry(registry.AcquireMainImageList(300, 300) == 300
        && registry.AcquireMainImageList(300, 300) == 300
        && registry.GetMainImageListUseCount(300) == 2,
        "活动主 ImageList 没有正确累计占用")
    AssertIconRegistry(!registry.RetireMainImageList(300, 300),
        "仍是活动列表的 ImageList 被错误退役")
    AssertIconRegistry(!registry.RetireMainImageList(300, 301)
        && registry.IsMainImageListRetired(300),
        "有占用的旧 ImageList 没有进入延迟销毁状态")
    AssertIconRegistry(!registry.ReleaseMainImageList(300)
        && registry.GetMainImageListUseCount(300) == 1,
        "尚有占用的退役 ImageList 被提前销毁")
    AssertIconRegistry(registry.ReleaseMainImageList(300)
        && !registry.IsMainImageListRetired(300),
        "最后一个占用释放后没有移交销毁责任")
    AssertIconRegistry(!registry.ReleaseMainImageList(300),
        "重复释放 ImageList 产生了第二次销毁责任")
    AssertIconRegistry(registry.RetireMainImageList(302, 301),
        "无占用的旧 ImageList 没有立即移交销毁责任")
    AssertIconRegistry(!registry.AcquireMainImageList(999, 301),
        "未跟踪 ImageList 被错误接纳")

    originalMetrics := registry.GetMainIconMetrics()
    AssertIconRegistry(registry.UpdateMainIconMetrics(144)
        && registry.MainDpi == 144
        && registry.MainIconPixelSize == 42
        && registry.MainIconCellPixelSize == 54,
        "主图标 DPI 尺寸计算错误")
    AssertIconRegistry(registry.RestoreMainIconMetrics(originalMetrics)
        && registry.MainDpi == 96
        && registry.MainIconPixelSize == 28
        && registry.MainIconCellPixelSize == 36,
        "失败回滚没有恢复完整图标尺寸快照")

    AssertIconRegistry(registry.InstallResamplerFactory(501)
        && !registry.InstallResamplerFactory(502)
        && registry.GetResamplerFactory() == 501,
        "WIC 工厂所有权被重复覆盖")
    AssertIconRegistry(registry.TakeResamplerFactory() == 501
        && !registry.TakeResamplerFactory(),
        "WIC 工厂提取没有保持单一所有权")

    firstRequest := registry.CreateDpiRebuildRequest(120,
        IconRegistryTestRebuild)
    secondRequest := registry.CreateDpiRebuildRequest(144,
        IconRegistryTestRebuild)
    AssertIconRegistry(secondRequest.PreviousTimer == firstRequest.Timer
        && !registry.IsDpiRebuildCurrent(firstRequest.Generation)
        && registry.IsDpiRebuildCurrent(secondRequest.Generation)
        && !registry.AcceptDpiRebuild(firstRequest.Generation)
        && registry.AcceptDpiRebuild(secondRequest.Generation),
        "过期 DPI 重建任务没有被代际拒绝")
    thirdRequest := registry.CreateDpiRebuildRequest(192,
        IconRegistryTestRebuild)
    AssertIconRegistry(registry.CancelDpiRebuild() == thirdRequest.Timer
        && !registry.IsDpiRebuildCurrent(thirdRequest.Generation)
        && !registry.AcceptDpiRebuild(thirdRequest.Generation)
        && !registry.CancelDpiRebuild(),
        "DPI 重建取消没有使迟到回调失效")
}

try {
    RunIconResourceRegistryTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

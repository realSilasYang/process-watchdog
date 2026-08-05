# 可复用的局部布局事务规范

本规范适用于“多个同级子控件在窗口拖拽缩放时需要一起移动”的 Win32/AHK v2
场景。当前实现位于
[`src/UI/AtomicControlLayout.ahk`](https://github.com/realSilasYang/process-watchdog/blob/main/src/UI/AtomicControlLayout.ahk)，
主命令按钮和伪表头都必须通过它完成可见窗口布局。

## 公共接口

```ahk
result := AtomicControlLayout.Apply(parentGui, [
    {Control: buttonA, X: 600, Y: 15, Width: 80, Height: 30},
    {Control: buttonB, X: 690, Y: 15, Width: 80, Height: 30}
], {
    ParentColor: "1E1E1E",
    ClearMargin: 2
})
```

坐标和尺寸一律使用 96-DPI 逻辑单位。`Apply` 在进入 Win32 事务时只读取一次
父窗口 DPI 并转换为物理像素，避免同一轮布局重复缩放。`ParentColor` 是父客户区的
纯色背景；`ClearMargin` 是逻辑单位的边缘安全余量，用于清除圆角抗锯齿像素。

结果对象的 `Status` 有四种值：

- `Unchanged`：所有子控件的实际矩形已经等于目标矩形，没有调用移动或重绘。
- `Applied`：布局已完成。`Mode` 为 `Deferred`（原子 Win32 提交）、`Direct`（父窗口
  不可见时的初始化移动）或 `Fallback`（原子提交不可用后的受保护普通移动）。
- `Unavailable`：父窗口或子窗口句柄已失效；调用方应停止当前布局并等待窗口重建。
- `Failed`：参数校验、移动和回退都失败。调用方不得假定几何已完成，应保留下一轮重试。

## 不变量与顺序

1. **几何与绘制分离。** 先收集旧矩形，再提交全部几何变化，最后处理绘制；不要在
   单个 `.Move()` 之间主动 `RedrawWindow`。
2. **逻辑单位只出现在 API 边界。** `GuiControl.Move` 使用逻辑单位，
   `DeferWindowPos`、`GetWindowRect`、`RedrawWindow` 和 DC 坐标使用物理像素。
3. **同级窗口必须成批提交。** 用一次 `BeginDeferWindowPos`、多次
   `DeferWindowPos`、一次 `EndDeferWindowPos`，并使用 `SWP_NOREDRAW | SWP_NOCOPYBITS`
   等标志禁止中间表面提交。
4. **绝不暂停父窗口。** 交互式缩放期间父窗口继续处理绘制消息，否则稳定的左侧控件
   会整窗闪烁。父窗口只接受最终受影响区域的同步刷新。
5. **只保护会移动的叶控件。** `AtomicControlLayoutEraseGuard` 仅对事务中的子窗口
   拦截 `WM_ERASEBKGND`，且使用活动计数支持嵌套事务；不拦截父窗口或稳定控件。
6. **不要把 `RDW_NOERASE` 当成清理手段。** 它只避免重绘前的背景擦除，不能清掉子窗口
   旧位置留下的像素。
7. **旧位置必须显式回填。** 移动完成后，用 `GetDCEx(..., DCX_CLIPCHILDREN)` 在
   旧矩形上填充父背景，避免覆盖新子窗口表面。
8. **只重绘旧/新区并集。** 用 `RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN |
   RDW_NOERASE` 同步重绘并集，禁止无界的整客户区刷新。
9. **资源和保护状态必须成对释放。** 子类保护、HDC、画刷和临时缓冲区都必须在
   `finally` 或等价的收尾路径释放；任何异常都不能留下活动句柄计数。
10. **高频路径复用回调。** 子类回调指针和已附加 HWND 映射保持静态复用，避免每次
    拖拽创建/销毁回调造成资源抖动。
11. **保留未变化快路径。** 目标矩形与现状一致时直接返回 `Unchanged`，不安装子类、
    不申请 HDWP、不给父窗口发绘制消息。
12. **回退必须可解释。** `BeginDeferWindowPos` 或提交失败时，模块在同一保护边界内
    使用逻辑 `.Move()` 完成回退，并返回 `Mode: "Fallback"`；不能静默退回旧的逐项
    重绘实现。
13. **圆角余量必须统一。** 旧位置回填和并集失效使用同一个 `ClearMargin`，否则边缘
    会留下方角、抗锯齿残片或一像素拖影。
14. **调用方保持薄。** 调用方只计算业务位置和颜色，构造完整的
    `{Control, X, Y, Width, Height}` 条目；不得复制 DPI、HDWP、子类或 GDI 代码。
15. **验证提交后的实际几何。** `Applied` 之前必须重新读取每个 HWND 的物理矩形并与
    目标逐项比较；Win32 返回成功不等于窗口已经达到目标。
16. **禁止扩大修复范围。** 不使用父级 `WM_SETREDRAW`、`WS_EX_COMPOSITED` 或整窗
    `RedrawWindow` 作为缩放修复；这些策略会让稳定元素闪烁。

## 验证清单

- 连续交替改变窗口宽度至少 24 次，断言父窗口没有 `WM_SETREDRAW` 暂停。
- 断言稳定左侧按钮没有新增 `WM_PAINT`/`WM_ERASEBKGND`，移动控件的擦除消息全部被
  保护拦截，并且活动计数每轮回到零。
- 读取旧按钮中心像素，确认它等于父背景色；读取伪表头右缘，确认它等于工具栏色。
- 分别验证 `Unchanged`、`Applied/Deferred`、隐藏窗口 `Applied/Direct` 和失败回退结果。
- 在 96、125、150、200% DPI 下比较逻辑目标与物理实际矩形，允许最多一个取整像素误差。
- 统计 GDI/USER 句柄和回调数量，长时间拖拽不得增长。
- 自动化测试之外，必须在真实桌面上持续拖动窗口观察：无全窗闪烁、无旧位置拖影、无
  圆角残留。DWM、显卡驱动和多显示器组合不能由单次截图替代。

## 适用边界

该模块只处理同一父窗口下的子 HWND 几何变更和局部表面收尾。它不负责列表列宽业务
计算、字体刷新、主题生成、父窗口尺寸保存或控件生命周期。隐藏窗口初始化可以使用
`Mode: "Direct"`；不可见窗口不应为了“无闪烁”而强行安装子类或调用同步重绘。

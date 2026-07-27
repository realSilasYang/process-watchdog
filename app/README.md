# 应用适配层

**简体中文** | [English](README.en.md)

`app` 保存面向本应用的组合和 GUI 适配代码。这里的窗口类可以调用主程序提供
的应用命令与展示辅助函数；可复用且不应依赖根全局的配置、守护、平台和 UI
基础设施继续放在 `src`。

`app/UI` 保存主窗口专用的原生渲染与交互适配，`app/Windows` 保存短生命周期
窗口。两者都可以连接组合根，但不得自行创建第二份应用状态。

这个边界有意区分两类代码：

- `src`：通过构造参数或回调显式接收依赖，不读取 `App`、`Main` 或
  `GuiModules`。
- `app`：负责把具体窗口和应用命令连接到组合根，可以访问应用级状态，但仍
  必须由 `ManagedWindow` 和 `GuiModuleRegistry` 管理生命周期。

窗口只保留自身布局、业务校验和控件引用。相同目的的基础行为必须走共享入口：

- `InitializeApplicationWindow` 统一标题栏、应用图标、客户区颜色和默认字体；
- 现代文件与目录选择器共用 `SelectPathWithModernDialog` 的主题、初始路径、取消
  和 Shell 资源释放边界；
- 已注册按钮通过 `SetRegisteredButtonEnabled` 同步启用状态、交互状态与重绘；
- 配置窗口通过 `GuardMutationQueue.EnqueueExclusive` 防止同一操作重复排队；
- 主列表与 Everything 搜索的 ImageList 占用和延迟销毁都由
  `IconResourceRegistry` 计数。

窗口特有的表单取值、保存事务、搜索批次、日志测量和关闭清理不因代码形状相似而
强行合并；只有行为目的、所有权和异常契约都相同的实现才能进入共享层。

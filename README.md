<div align="center">
  <p><strong>简体中文</strong> · <a href="./docs/README.zh-HK.md">繁體中文（香港）</a> · <a href="./docs/README.zh-TW.md">繁體中文（台灣）</a> · <a href="./docs/README.en.md">English</a> · <a href="./docs/README.ja.md">日本語</a> · <a href="./docs/README.vi.md">Tiếng Việt</a> · <a href="./docs/README.ko.md">한국어</a> · <a href="./docs/README.es.md">Español</a> · <a href="./docs/README.fr.md">Français</a> · <a href="./docs/README.pt-BR.md">Português</a> · <a href="./docs/README.ru.md">Русский</a> · <a href="./docs/README.de.md">Deutsch</a> · <a href="./docs/README.it.md">Italiano</a></p>

  <h1>进程守护小助手</h1>

  <p><strong>持续守护重要程序与自动化任务，让日常工作稳定运行</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="最新版本"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="GitHub 下载量"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="CI 状态"></a>
    <a href="./LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="开源许可证"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="支持 Windows 10 和 Windows 11">
  </p>

  <p>
    <a href="#界面概览">界面概览</a> ·
    <a href="#用户使用指南">用户指南</a> ·
    <a href="#3-状态与恢复逻辑">状态说明</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">版本发布</a> ·
    <a href="./CHANGELOG.md">更新日志</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">问题反馈</a> ·
    <a href="#开发者指南">开发者指南</a>
  </p>
</div>

进程守护小助手面向需要长期驻留的 Windows 桌面程序、脚本和快捷方式：在目标异常退出后自动、审慎地恢复运行，同时区分“确认停止”与“暂时无法判断”，避免重复启动和误拉起。所有判断、配置与日志均留在本机；项目使用 AutoHotkey v2 x64 构建，支持 Windows 10 和 Windows 11。

小助手不只按进程名判断目标，而是结合完整路径、进程创建身份、快捷方式真实目标和命令行证据确认目标是否仍在运行。证据不足时会等待下一轮检查，不会把“暂时无法确认”直接当作停止并重复启动。

项目提供浅色与深色图形界面、自动恢复、软件升级保护、运行日志、撤销与重做、自定义名称和图标，以及包含 SPDX SBOM、SHA-256 校验和与构建溯源的 Windows x64 发行包。

# 界面概览

<p align="center">
  <img src="docs/images/process-watchdog-overview.png" alt="进程守护小助手主界面" width="100%">
</p>

主窗口集中展示守护项顺序、应用图标、名称、权限要求和当前状态。顶部命令栏提供添加、删除、暂停、设置、帮助信息与捐赠入口；帮助信息中可继续选择使用说明、运行日志或提交反馈。窗口底部汇总运行、恢复、升级、暂停和失败数量，异常状态可以继续通过运行日志追踪到具体判断依据。

## 主要能力

- 守护 EXE、AHK、Python、JavaScript、PowerShell、BAT、CMD 和 LNK。
- 使用 `Running`、`Stopped`、`Unknown` 三态探活；未知状态不会触发盲目重启。
- 每个目标拥有独立控制器、代际和任务令牌，暂停、删除或改路径后旧回调立即失效。
- 直接文件被更名或在同一卷（通常是同一盘符）内移动时，以 Windows 文件 ID 找回新路径并由用户确认；不会按目录中的相似文件猜测目标。
- 支持管理员权限要求；已运行实例权限不符时提示，手动重新启动时按配置提权。
- 软件升级保护默认关闭；启用后结合更新进程、父子关系、安装目录和文件稳定性暂停守护，并在升级结束后恢复。
- 配置采用原子替换；无法解析的监控记录进入 `[Recovery]`，不会静默丢弃。
- 程序搜索仅使用 Everything 服务，不启用本地全盘扫描，也不限制匹配结果数量；大量结果会分批加入列表，避免图标提取长时间阻塞界面。
- 支持简体中文、繁体中文（香港）、繁体中文（台湾）、英语、日语、越南语、韩语、西班牙语、法语、葡萄牙语（巴西）、俄语、德语和意大利语；默认跟随 Windows 界面语言，不受支持的系统语言回退英语，也可在“通用”中手动切换。语言和内容字体保存后在当前进程内立即生效，不会停止或重新初始化守护任务。
- “跟随语言默认”优先使用苹方、SF Pro Text、Harano Aji Gothic 或 Apple SD Gothic Neo；设备未安装时从随包商业授权或 OFL 资源私有加载，仍不可用时再加载对应 Noto 字体。内容字体控制正文、输入框、列表以及“关于”页的信息；按钮、设置切换标签与主窗口底部状态栏始终使用当前语言对应的 Windows 系统 UI 字体粗体。
- 浅色与深色 GUI 支持多级窗口独立最小化、DPI 图标重建、圆角按钮和自定义图标。
- 诊断包只在本机生成且不会自动上传；正式发行物可独立核验来源和完整性。

## 适用范围

适合需要在当前 Windows 桌面会话中持续运行、异常退出后自动恢复的普通应用、脚本和快捷方式。以下对象不属于当前项目范围：

- Windows 系统服务、驱动、内核组件或跨用户会话服务。
- Windows 7、32 位 Windows 或非 Windows 平台。
- 强实时、高可用集群或需要安全隔离边界的进程编排。
- 把未知进程状态强制当作停止的激进恢复策略。

已记录 Windows 11 实机 200% DPI 下的完整 GUI 自动化运行，并以回归测试覆盖 100% 和 300% 的渲染计算；各缩放下的人工视觉矩阵、跨显示器连续 DPI 切换和高对比度仍未完成，不能仅凭代码推定通过。完整证据与边界见[GUI 验证记录](tests/gui/VALIDATION-EVIDENCE.md)和[兼容性与已知限制](docs/compatibility.md)。

---

**[用户使用指南](#用户使用指南)**<br>
[安装与首次运行](#1-安装与首次运行) · [添加和管理项目](#2-添加和管理项目) · [状态与恢复逻辑](#3-状态与恢复逻辑) · [软件升级保护](#4-软件升级保护) · [设置](#5-设置) · [日志诊断和隐私](#6-日志诊断和隐私)

**[开发者指南](#开发者指南)**<br>
[目录与职责](#1-目录与职责) · [正确性边界](#2-正确性边界) · [验证命令](#3-验证命令) · [发布与贡献](#4-发布与贡献)

# 赞赏

如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者。进程守护小助手将持续保持开源，项目的长期维护有赖于您的支持和鼓励；您的支持将用于持续维护、兼容性验证和版本发布。

<p align="center">
  <img src="assets/donate/微信个人收款码.png" width="220" alt="微信支付捐赠二维码">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/donate/支付宝个人收款码.png" width="220" alt="支付宝捐赠二维码">
</p>

# 用户使用指南

## 1. 安装与首次运行

1. 从 [Releases](https://github.com/realSilasYang/process-watchdog/releases) 选择独立 EXE、完整便携 ZIP 或完整源码 ZIP。
2. 三种下载的运行和存储方式不同：

| 下载 | 适用场景 | 实际运行与配置位置 |
| --- | --- | --- |
| 独立 EXE | 单文件下载、无需安装 AutoHotkey | 首次运行校验内嵌载荷并安装到 `%LOCALAPPDATA%\ProcessWatchdog\Standalone`；程序、配置和后续自动更新都在该稳定目录中，移动或删除下载的引导 EXE 不会迁移配置 |
| 完整便携 ZIP | 可见、可备份、可手动部署的长期安装 | 完整解压后运行；程序资源与 `watchdog.ini` 保存在解压目录，不可只取出其中的 EXE |
| 完整源码 ZIP | 审阅、开发或源码运行 | 完整解压后用本机 AutoHotkey v2 x64 运行根 AHK；配置保存在源码目录 |

3. 运行 `进程守护小助手.exe`。程序会请求管理员权限，并按设置显示主窗口或静默驻留系统托盘。
4. 点击“添加”选择目标，或把支持的文件拖入主窗口。
5. 从“帮助信息 → 运行日志”查看目标识别、状态检查、恢复重试和升级保护实际采用的证据。

也可以从源码运行：安装 AutoHotkey v2 x64 后执行 `进程守护小助手.ahk`。通过 Git
克隆仓库时还需安装 Git LFS 并执行 `git lfs pull`，以取得随包字体的完整二进制文件；
Release 提供的源码 ZIP 已包含这些资源，不需要 Git LFS。独立 EXE 与便携 ZIP 中的
编译版已经内嵌发布时通过完整测试的 AutoHotkey 运行时，普通用户无需另行安装。

### 版本与运行方式

| 版本 | 编译版（独立 EXE／便携 ZIP） | 源码版 |
| --- | --- | --- |
| 小助手版本 | 来自 EXE 文件版本，更新时替换完整发行包 | 来自入口目录的 `VERSION`，通过 Git 快速前进或源码包更新 |
| AutoHotkey 版本 | 已内嵌；随下一版小助手发行包一起更新 | 使用本机解释器；小助手更新不会替用户升级 AutoHotkey |
| Ahk2Exe 版本 | 仅用于正式发布时生成 EXE，不进入用户电脑 | 不需要安装 |

“小助手已是最新版本”与“本机 AutoHotkey 已是最新版”不是同一件事。每次正式发布开始时会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版，冻结后完成全套测试；通过后才把所选 AutoHotkey 封装进 EXE。打开“小助手设置 → 关于”可以查看当前小助手版本、EXE／源码运行形态和实际 AutoHotkey 版本，并手动检查更新。详细边界见[版本、运行方式与更新责任](docs/versioning.md)。

主窗口关闭按钮只会把界面隐藏到系统托盘，不会结束守护。需要完全退出时，请使用托盘菜单中的“退出”。安装、升级、开始菜单快捷方式和计划任务说明见[安装、升级与卸载](docs/installation.md)。

## 2. 添加和管理项目

主窗口六个按钮的作用如下：

| 按钮 | 作用 |
| --- | --- |
| 添加 | 选择一个目标、搜索已安装程序或批量导入文件夹；文件夹默认递归扫描子目录 |
| 删除 | 删除选中的守护项；支持多选，可通过撤销恢复 |
| 暂停／恢复 | 只改变自动守护状态，不会主动关闭当前正在运行的目标；混合选择时逐项反转 |
| 设置 | 打开“小助手设置”，配置通用、监控、停止和日志选项 |
| 帮助信息 | 选择打开内置使用说明、本次运行日志或 GitHub 反馈页面 |
| 捐赠 | 显示微信支付和支付宝二维码，支持项目持续维护 |

添加项目时可以配置启动入口、工作目录、参数、环境变量和是否要求管理员权限。直接脚本还可以在“进程识别与启动设置”中指定 Python 虚拟环境、AutoHotkey、PowerShell、Node.js、Java 等任意运行时及其参数；实际顺序固定为“运行时参数、目标路径、目标参数”，留空则沿用默认启动方式。LNK 始终保留为启动入口，真实程序路径单独用于进程识别，因此安装器生成的间接快捷方式也不需要手工改成某个容易变化的内部 EXE。

程序搜索依赖正在运行的 Everything 后台实例；随包 `Everything64.dll` 只是连接该实例的 SDK 客户端，不包含索引器。后台未运行时，小助手会从有界的本机安装线索中查找并静默启动 Everything；未安装时则在搜索窗口提供官方最新版下载地址。详细示例见[常见使用场景](docs/quick-start.md)。

在主列表中右键项目可以：

- 打开文件所在位置、重新启动、修改目标路径，或配置进程识别与启动设置。
- 切换管理员运行要求；目标已运行但权限不符时显示警告，右键重新启动会提权启动。
- 配置软件升级保护。
- BAT／CMD 条目会额外显示“查看批处理输出日志”；其他目标不显示此项。该文件只在
  小助手实际启动该批处理入口时创建，用于保存其标准输出和错误输出。
- 自定义主窗口显示名称和图标；该设置不改变目标识别、启动路径或升级保护。
- 恢复默认名称和图标；当前已经是默认显示时，对应操作不可用。

主列表支持拖动排序，顺序会保存到配置。`Ctrl+Z`、`Ctrl+Y` 和 `Ctrl+Shift+Z` 可撤销或重做添加、删除、排序及配置变化。更多示例见[常见使用场景](docs/quick-start.md)。

列表最左侧序号始终反映当前显示顺序；删除、拖动排序、撤销或重做后会立即重新编号。应用图标仍与名称显示在同一列，序号不参与目标身份、启动或配置持久化。

## 3. 状态与恢复逻辑

主列表状态说明的是小助手当前掌握的证据和下一步动作，不应只按图标颜色推断结果：

| 状态类型 | 含义 |
| --- | --- |
| 运行中 | 已找到与目标身份相符的运行实例 |
| 运行中（权限不符） | 实例存在，但没有满足该项目配置的管理员权限要求 |
| 等待进程状态／疑似停止 | 当前证据不足或刚观察到退出，正在复核；此阶段不会立即重复启动 |
| 启动／重试倒计时 | 已确认需要恢复，并按“崩溃自动重启延迟序列”等待下一次尝试 |
| 软件升级中／确认文件稳定 | 升级保护已暂缓自动拉起，正在等待升级活动结束和目标文件稳定 |
| 已暂停 | 自动检查和恢复已暂停，但不会关闭目标进程 |
| 已停止／启动失败／等待超时 | 当前恢复没有成功或需要用户确认；打开日志可查看具体证据和失败原因 |

默认崩溃自动重启延迟序列为 1、10、60 秒。连续失败时沿用最后一个等待值，避免高速
循环拉起。删除、暂停、改路径或撤销会使旧的调度任务和异步结果失效，防止过期回调
重新修改已经变化的项目。

## 4. 软件升级保护

软件升级保护默认关闭，需要对每个项目手动启用：

1. 在主列表中右键目标，打开“软件升级保护”。
2. 勾选“自动识别升级并保护启动过程”。
3. 核对安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待。
4. 保存后，让软件按正常方式执行一次真实升级。小助手会结合更新进程、父子关系、安装目录变化、文件监听和已学习的更新程序特征判断是否进入保护。

确认升级后，小助手会暂缓自动启动；升级活动结束且目标文件稳定后自动恢复守护。如果判断超时或不符合实际情况，可以在同一窗口选择“结束升级等待并恢复守护”。恢复前仍会检查启动入口是否存在且可以安全使用。

升级保护不是通用安装器或系统服务管理器。涉及便携软件、安装目录外更新器或特殊启动器时，应先观察运行日志，再调整安装足迹和识别规则。

## 5. 设置

“小助手设置”按职责分为以下内容：

| 分类 | 可调整项目 |
| --- | --- |
| 通用 | 桌面与开始菜单快捷方式、计划任务开机自启、两项启动时行为、界面语言、界面内容字体和主题 |
| 监控与启动 | 进程状态检查间隔、崩溃自动重启延迟序列、导入文件夹时是否包含子目录 |
| 停止策略 | GUI 与 CLI 程序关闭超时、超时后是否允许强制结束 |
| 日志 | 启动时是否清空、运行日志显示上限、批处理日志保留天数和保存路径 |
| 关于 | 软件版本与运行环境、立即检查更新和开源地址 |

设置界面会校验数值范围。`watchdog.ini` 中的注释说明与设置项位于对应区段，建议优先通过界面修改，避免破坏编码字段。配置字段、备份和恢复步骤见[配置、备份与恢复](docs/configuration.md)。

## 6. 日志、诊断和隐私

“运行日志”支持选择和复制文本、最大化及调整窗口大小。滚动条仅在内容超出时显示；日志文本本身不会进入可编辑状态。

运行日志记录小助手自身的判断和操作，所有目标都会产生这类内存日志。批处理输出日志
则只属于由小助手实际启动的 BAT／CMD 条目：启动命令会把该批处理的标准输出和错误
输出追加到独立文件，即使程序没有输出，重定向建立后文件也可能为空。EXE、AHK、
PowerShell、快捷方式以及启动前已经运行的批处理不会因此自动生成独立输出文件。

难以定位的问题可以在日志窗口导出本地诊断包。诊断包包含应用、Windows、AutoHotkey、DPI、资源句柄、守护阶段、配置警告和当前日志摘要，但不会自动上传。

个人配置保存在实际运行目录的 `watchdog.ini`，未完成的软件升级会话保存在同目录的 `watchdog.maintenance.ini`。便携版和源码版以各自入口目录为实际运行目录；独立 EXE 则固定使用 `%LOCALAPPDATA%\ProcessWatchdog\Standalone`。这两个个人文件均被 Git 忽略，发行包不会携带或覆盖；仓库中的 `config/watchdog.example.ini` 只用于说明当前默认值和字段。

便携 EXE 与源码入口放在同一目录时共用个人状态，放在不同目录时彼此独立；独立 EXE 不与下载位置旁的文件共享配置。全局单实例锁会阻止不同形态同时运行。快捷方式和计划任务始终指向最后执行创建／切换操作的实际运行形态，因此每套安装只应选定一个日常入口。详细规则见[配置、备份与恢复](docs/configuration.md)和[安装、升级与卸载](docs/installation.md)。

日志和诊断包可能包含目标路径、启动参数或环境变量。公开提交前应自行检查和脱敏。提交问题时请使用[结构化 Issue 模板](https://github.com/realSilasYang/process-watchdog/issues/new/choose)；尚未修复的安全问题必须使用私密漏洞报告入口。详细说明见[本地诊断包](docs/diagnostics.md)、[故障排查](docs/troubleshooting.md)和[获取帮助](.github/SUPPORT.md)。

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# 开发者指南

## 1. 目录与职责

```text
process-watchdog/
├─ .github/
│  ├─ ISSUE_TEMPLATE/        缺陷、功能和改进建议表单
│  ├─ workflows/             CI、长时 GUI 稳定性测试与人工发布
│  ├─ CONTRIBUTING／SECURITY  贡献、安全、支持与行为准则
│  └─ PULL_REQUEST_TEMPLATE/  中英文 Pull Request 模板
├─ app/
│  ├─ UI/                    主界面绘制、图标与交互适配
│  └─ Windows/               设置、日志、帮助及各级对话框
├─ assets/
│  ├─ app/                   应用图标
│  ├─ fonts/                 进程私有首选／回退字体、授权声明与来源
│  └─ ui-icons/              按钮、主列表状态与底部统计栏 SVG 图标
├─ config/                   带就地注释的最新配置格式示例
├─ docs/                     使用、架构、多语言总览、截图及项目治理文档
├─ src/
│  ├─ Config/                配置编解码、事务、布局与持久化
│  ├─ Core/                  守护状态、调度、重试和目标控制器
│  ├─ Diagnostics/           本地诊断包
│  ├─ Execution/             启动、正常退出和分级终止
│  ├─ Inspection/            进程、快捷方式、文件和目录证据
│  ├─ Maintenance/           软件升级保护状态机和会话恢复
│  ├─ Platform/              Win32 常量与平台边界
│  ├─ UI/                    列表投影、图标资源和窗口生命周期
│  └─ Update/                小助手自身更新的异步协调
├─ runtime/                  EXE 与源码共用的后台更新检查和替换助手
├─ tests/
│  ├─ core/                  可独立运行的核心行为测试
│  └─ gui/                   真实控件压力测试和人工回归矩阵
├─ third_party/              锁定的运行时 DLL、许可和依赖清单
├─ tools/                    构建、SBOM、发行校验和工具链引导
└─ 进程守护小助手.ahk        组合根和启动入口
```

根脚本只负责组合模块、装配依赖和启动。`src` 不读取根全局 `App`、`Main` 或 `GuiModules`；`app` 负责把纯核心能力接入具体窗口、日志和系统操作。更详细的依赖方向与状态机说明见[架构与正确性边界](docs/architecture.md)。

## 2. 正确性边界

- 目标身份、启动入口和主窗口自定义显示彼此独立，展示设置不能改变守护判断。
- `Running`、`Stopped`、`Unknown` 是外部证据结果；只有确认停止才能进入恢复流程。
- 每个计时器、消息回调、文件监听、工作进程、窗口和原生资源都必须有幂等清理路径。
- 配置快照、守护项和升级保护设置在同一事务中提交，测试不得读取或覆盖正式 `watchdog.ini`。
- 已撤销的 GDI 截图覆盖式平滑滚动不得重新引入；ListView 和日志保留原生滚动。
- DPI、图标、深色模式、窗口层级和可访问性变化必须记录真实 Windows 与缩放验证证据，自动化测试不能替代物理显示器矩阵。

## 3. 验证命令

在 Windows PowerShell 中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-fast.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-windows-integration.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

- `verify-fast.ps1`：不拉取 LFS 大字体、不打开 GUI，检查依赖、静态边界、更新与安装事务、仓库、泄漏和工作流，供每个提交快速反馈。
- `verify.ps1`：在快速门禁之上运行 39 个 AHK 核心和集成测试。
- `verify-windows-integration.ps1`：校验完整字体哈希，创建真实 Windows 控件，覆盖 13 种语言、三级窗口和 GDI／USER 句柄回收。
- `reproducible-build.ps1`：连续构建两次独立 EXE、便携 ZIP、源码 ZIP 和 SBOM，比较逐项 SHA-256，并对单文件版执行空目录双启动。

GitHub Actions 先按变更路径分类：纯文档只运行快速门禁；运行时代码增加 Windows／GUI 集成；主分支非文档变更和发行工程相关 Pull Request 才执行完整可复现打包。正式发布仍会重新执行全部三层，不以较快的普通 CI 代替发布验收。

AutoHotkey 与 Ahk2Exe 不在仓库中预先锁定版本：每次人工正式发布都会重新查询 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版，先冻结本次解析快照，再用同一快照完成测试、双次构建、SBOM 和打包。actionlint 与 Gitleaks 等验证工具仍固定版本。最终实际版本、来源、提交和 SHA-256 随发行包保存。第三方详情见[第三方软件声明](docs/project/THIRD_PARTY_NOTICES.md)。

## 4. 发布与贡献

用户可见变化必须同步更新 README 和 CHANGELOG。新增版本时使用[更新日志模板](docs/changelog-template.md)，按用户能够观察到的“新增、优化、修复”归纳变化，不直接复制提交信息或内部类名。

完整发布步骤见[发布流程](docs/release-process.md)，仓库设置和版本发布门禁见[正式发布清单](docs/publication-checklist.md)。普通 Pull Request 不应创建版本标签或改写已经发布的标签。

欢迎提交能够复现问题、说明风险并附验证证据的 Issue 和 Pull Request。涉及窗口、DPI、图标或深色模式时，请同时说明实际验证的 Windows 版本和缩放比例。贡献要求见[贡献指南](.github/CONTRIBUTING.md)，项目决策原则见[项目治理](docs/project/GOVERNANCE.md)。

项目代码采用 [MIT License](LICENSE)。内嵌和随包组件仍遵循各自许可证；发行包会附带 AutoHotkey 许可证及对应源码归档。PingFang、SF Pro Text 与 Apple SD Gothic Neo 依据项目所有者持有的商业分发授权提供，不适用 MIT License。

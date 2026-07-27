# 参与贡献

**简体中文** | [English](CONTRIBUTING.en.md)

感谢你为进程守护小助手提交问题、文档或代码改进。

提交普通缺陷、新功能或改进建议时，请使用仓库提供的结构化 Issue 模板。使用问题
先阅读[获取帮助](SUPPORT.md)；尚未修复的安全问题必须按照
[安全策略](SECURITY.md)私密报告。

## 开发环境

- Windows 10 或 Windows 11 x64。
- AutoHotkey v2 x64；本地验证默认使用最近一次解析的上游稳定版。
- Windows PowerShell 5.1 或 PowerShell 7。
- 完整 Git 克隆；全历史泄漏检查不接受浅克隆。

首次检出后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
```

验证入口会按需解析 AutoHotkey 与 Ahk2Exe，并下载固定版本的 actionlint 和
Gitleaks，不需要把第三方 DLL 加入系统 `PATH`。正式发布会强制重新查询前两者的
上游版本；浅克隆和不完整历史会明确失败，
不会给出覆盖范围不足的“通过”结论。

测试不得读取、覆盖或依赖开发者的正式 `watchdog.ini`。需要配置数据时，应在
`tests/fixtures/` 中创建最小夹具，在隔离的临时目录中运行，并清理临时副本。

## 修改约定

- 一个提交只表达一个完整意图，不夹带无关重构或格式化。
- 根脚本是组合入口；`src` 模块不得读取根全局 `App`、`Main` 或 `GuiModules`。
- 目标身份、启动入口和自定义显示相互独立，展示设置不得改变守护判断。
- 新行为应补充对应核心、静态或 GUI 测试；复杂外部状态必须包含失败和过期结果反例。
- 任何计时器、消息回调、文件监听、工作进程、图标、窗口句柄或 COM／GDI 资源都
  必须有幂等清理边界。
- 用户可见中文使用全角括号，不使用“空格加半角括号”。
- 不重新引入已经撤销的 GDI 截图覆盖式平滑滚动；原生滚动行为是当前兼容边界。
- 新增第三方依赖前核对来源与再分发许可，并同步更新版本、SHA-256、许可证、
  `docs/project/THIRD_PARTY_NOTICES.md` 和 SBOM 关系。
- 外部 GitHub Action 必须固定到完整提交 SHA，并保留主版本注释；修改工作流后必须
  通过固定版本的 actionlint。正式发布只允许从 `main` 人工触发。
- 不得提交真实 `watchdog.ini`、维护会话、诊断包、私人路径、启动参数、凭据、
  构建产物或临时 Codex 探针。

## 选择验证层级

| 改动类型 | 最低验证要求 |
| --- | --- |
| 纯状态机、编解码、调度或路径逻辑 | 对应 `tests/core` 测试和 `tests/verify.ps1` |
| 模块边界、清理约束或用户可见文本 | 更新 `tests/static-check.ps1`，运行 `tests/verify.ps1` |
| 窗口、按钮、输入框、ListView、日志或图标 | 运行相关 GUI 测试，并记录人工观察结果 |
| DPI、暗色模式、窗口层级或可访问性 | 填写 Windows 版本、缩放比例和物理显示器证据 |
| 构建、依赖、SBOM 或发行包 | 运行 `tests/reproducible-build.ps1` 和发行结构校验 |

完整 GUI 人工范围见 `tests/gui/MANUAL-REGRESSION.md`。自动化不能替代真实 DPI、
多显示器、高对比度、触控板或屏幕阅读器验证；未覆盖的组合必须明确写出。

## 提交与 Pull Request

Pull Request 应说明问题、用户可见变化、关键设计、兼容性、实际验证命令和未覆盖
风险。涉及界面时附经过脱敏的截图或录屏；涉及配置时说明对 `watchdog.ini`、
`watchdog.maintenance.ini`、备份和恢复的影响。

用户可见变化必须同步更新 README、CHANGELOG 和对应使用文档。新增版本按
[更新日志模板](../docs/changelog-template.md)整理；普通 Pull Request 不应创建版本
标签、修改已发布版本或手工上传未经验证的发行包。

发布流程见[发布指南](../docs/release-process.md)，项目决策、合并和版本支持原则见
[项目治理](../docs/project/GOVERNANCE.md)。

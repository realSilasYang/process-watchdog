# Windows GUI 验证证据

**简体中文** | [English](VALIDATION-EVIDENCE.en.md)

本文件记录可以复现的本机验证事实，不把代码路径覆盖或自动化截图表述为人工视觉
验收。未列出的环境一律视为尚未完成实机验证。

## 2026-07-29 本机记录

| 项目 | 实际结果 |
| --- | --- |
| Windows | Windows 11，内部版本 26200 |
| 显示器 | 3072 × 1920，Intel Arc 130T（驱动 32.0.101.6554） |
| 实际窗口 DPI | 192，即 200%；由真实 AHK GUI 的 `GetDpiForWindow` 读取，而非进程 DPI 探针推断 |
| AutoHotkey | v2.0.26 x64 |
| 主题 | 当前系统深色；生产窗口在进程内完成深色与浅色热切换验证 |
| 高对比度 | 未启用、未验证 |

### 已通过的自动化验证

执行 `tests\verify-windows-integration.ps1 -SoakSeconds 15`，结果包括：

- 真实 GUI 冒烟：`GUI_SMOKE|PASS|dpi=192|sequenceWidth=96`。
- 日志窗口、13 种界面语言和生产子窗口的创建、销毁与资源回收通过。
- 深色／浅色热切换：`DISPLAY_HOT_SWITCH|PASS|languages=13|gdiDelta=1|userDelta=-1`。
- 发布门禁内的完整 UI 资源循环：`RESOURCE_SOAK|PASS|seconds=15|iterations=205|gdiDelta=0|userDelta=0|maxGdi=40|maxUser=16`。
- 额外 5 分钟资源浸泡：`RESOURCE_SOAK|PASS|seconds=300|iterations=3687|gdiDelta=0|userDelta=0|maxGdi=40|maxUser=16`。
- 自绘圆角按钮的 Windows MSAA 名称、按钮角色和本地化默认操作由
  `tests/core/rounded-button-renderer-tests.ahk` 进程内读取验证；Enter、Space
  与 Tab 焦点导航所需样式也有回归断言。

### 明确未覆盖的物理验收

- 100%、150%、300% 的实际显示缩放人工视觉检查。
- 多显示器之间的连续 DPI 迁移。
- Windows 高对比度主题和屏幕阅读器的端到端朗读体验。

上述限制同时记录在[手工回归矩阵](MANUAL-REGRESSION.md)。发布说明或 README
不得把这些项目描述为已完成。

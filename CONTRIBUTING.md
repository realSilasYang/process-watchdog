# 贡献指南

感谢改进进程守护小助手。提交改动前，请先确认问题能够在受支持的 Windows
和 AutoHotkey v2 环境中复现，并尽量把行为变化写成测试。

## 开发环境

1. 安装 Windows 10 或 Windows 11 x64。
2. 安装 AutoHotkey v2 x64；当前基准版本见 `README.md`。
3. 克隆仓库，不需要把第三方 DLL 加入系统 `PATH`。
4. 运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1`。

验证脚本会下载并核对锁定版本的 AutoHotkey、actionlint 和 Gitleaks。公开历史
检查要求完整克隆；浅克隆会明确失败，而不会给出不完整的“通过”结论。

测试不得读取、覆盖或依赖开发者的 `watchdog.ini`。需要配置数据时，应在
`tests/fixtures/` 中创建最小夹具，并在测试结束时清理临时副本。

## 提交要求

- 一个提交只处理一个能够清楚说明的主题。
- 保持 `src` 模块不读取根全局 `App`、`Main` 或 `GuiModules`。
- 任何计时器、消息回调、工作进程、图标或窗口句柄都必须有幂等清理边界。
- 用户可见中文使用全角括号，不使用“空格加半角括号”。
- 不重新引入已经移除的 GDI 截图覆盖式平滑滚动实现。
- 修改依赖时同步更新来源、许可证、版本和 SHA-256。
- 外部 GitHub Action 必须固定到完整提交 SHA，并保留主版本注释；修改工作流后
  必须通过锁定版本的 actionlint。
- 不得提交真实 `watchdog.ini`、维护会话、凭据、本机绝对路径或临时 Codex
  探针；提交前必须通过完整 Git 历史的 Gitleaks 检查。

## Pull Request

PR 说明应包含问题、解决方案、风险、测试证据和必要的 GUI 截图。涉及窗口、
DPI、图标或暗色模式时，请填写手工验证过的缩放比例和 Windows 版本。

项目的决策、合并和版本支持原则见 [项目治理](GOVERNANCE.md)。

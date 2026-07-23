# 进程守护小助手

[![CI](https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml/badge.svg)](https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/realSilasYang/process-watchdog?display_name=tag)](https://github.com/realSilasYang/process-watchdog/releases/latest)
[![License](https://img.shields.io/github/license/realSilasYang/process-watchdog)](LICENSE)

面向 Windows 桌面程序、脚本和快捷方式的本地守护工具。它不只按进程名判断，
而是结合完整路径、进程创建身份、快捷方式真实目标和命令行证据确认目标是否仍在
运行；证据不足时会等待下一轮检查，避免把“暂时无法确认”误判为停止并重复启动。

项目基于 AutoHotkey v2 x64，提供深色图形界面、自动恢复、软件升级保护、日志、
撤销与重做、自定义名称和图标，以及可复现的 Windows x64 发行包。

## 主要能力

- 守护 EXE、AHK、Python、JavaScript、PowerShell、BAT、CMD 和 LNK。
- 使用 `Running / Stopped / Unknown` 三态探活；未知状态不会触发盲目重启。
- 每个目标拥有独立控制器、代际和任务令牌，暂停、删除、改路径后旧回调立即失效。
- 支持管理员权限要求；已运行实例权限不符时提示，手动重启时按配置提权。
- 软件升级保护默认关闭，开启后结合更新进程、父子关系、安装目录和文件稳定性暂停
  守护，并在升级结束后恢复。
- 配置采用同目录原子替换，无法解析的监控记录进入 `[Recovery]`，不会静默丢弃。
- 深色 GUI 支持多级窗口、独立最小化、DPI 图标重建、圆角按钮和自定义图标。
- 诊断包只在本机生成且不会自动上传；发行包提供 SPDX SBOM、SHA-256 和构建溯源。

## 适用范围

适合需要在交互式 Windows 桌面会话中持续运行、退出后自动恢复的普通应用、脚本
和快捷方式。以下场景不属于当前项目范围：

- Windows 系统服务、驱动、内核组件或跨用户会话服务。
- Windows 7、32 位 Windows、非 Windows 平台。
- 强实时、高可用集群或需要安全隔离边界的进程编排。
- 把未知进程状态强制当作停止的激进恢复策略。

详细边界见[兼容性与已知限制](docs/compatibility.md)。

## 快速开始

1. 从 [Releases](https://github.com/realSilasYang/process-watchdog/releases) 下载
   `process-watchdog-<版本>-windows-x64.zip` 和同一版本的 `SHA256SUMS.txt`。
2. 核对 ZIP 与独立 SBOM 的 SHA-256，然后完整解压；不能只复制 EXE。
3. 运行 `进程守护小助手.exe`，点击“添加”选择目标。
4. 按需设置工作目录、参数和管理员运行。软件升级保护需要手动开启。
5. 从“运行日志”查看探活、重试和升级保护采用的实际证据。

```powershell
Get-FileHash -Algorithm SHA256 .\process-watchdog-*-windows-x64.zip
Get-Content .\SHA256SUMS.txt
```

也可以从源码运行：安装 AutoHotkey v2 x64 后执行 `进程守护小助手.ahk`。发行包
已经内嵌锁定版本的 AutoHotkey 运行时，普通用户无需另行安装。

## 数据与隐私

个人配置保存在程序目录的 `watchdog.ini`，未完成的软件升级会话保存在
`watchdog.maintenance.ini`。这两个文件均被 Git 忽略，发行包不会携带或覆盖它们；
仓库中的 `watchdog.example.ini` 只用于说明当前默认值和字段。

项目没有遥测，也不会自动上传日志或诊断包。运行日志可能包含目标路径、启动参数
或环境变量，公开提交前应自行检查。更多说明见[配置、备份与恢复](docs/configuration.md)
和[本地诊断包](docs/diagnostics.md)。

## 文档

- [常见使用场景](docs/quick-start.md)
- [安装、升级与卸载](docs/installation.md)
- [配置、备份与恢复](docs/configuration.md)
- [故障排查](docs/troubleshooting.md)
- [兼容性与已知限制](docs/compatibility.md)
- [架构与正确性边界](docs/architecture.md)
- [首次公开发布清单](docs/publication-checklist.md)
- [本地诊断包](docs/diagnostics.md)
- [获取帮助](SUPPORT.md)
- [贡献指南](CONTRIBUTING.md)
- [项目治理](GOVERNANCE.md)
- [安全问题报告](SECURITY.md)

## 开发与验证

项目在 Windows PowerShell 中提供一键验证入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-gui-tests.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

`verify.ps1` 会运行依赖哈希、静态检查、核心测试、仓库约束、完整 Git 历史泄漏
扫描和 GitHub Actions 校验。GUI 测试创建真实控件并检查 GDI／USER 句柄回收；
可复现构建会连续生成两次发行包并比较 ZIP 与 SBOM 哈希。

锁定工具链会按需下载 AutoHotkey、Ahk2Exe、actionlint、Gitleaks 以及与内嵌运行时
精确对应的 AutoHotkey 源码。第三方版本、来源、许可证和 SHA-256 见
[第三方软件声明](THIRD_PARTY_NOTICES.md)。

完整测试范围、模块职责和并发边界见[架构文档](docs/architecture.md)。发布步骤见
[发布流程](docs/release-process.md)。

## 贡献与许可

欢迎提交能够复现问题、说明风险并附验证证据的 Issue 和 Pull Request。涉及窗口、
DPI、图标或深色模式时，请同时说明实际验证的 Windows 版本和缩放比例。

项目代码采用 [MIT License](LICENSE)。内嵌和随包组件仍遵循各自许可证；发行包
会附带 AutoHotkey 许可证及对应源码归档。

# 第三方软件声明

**简体中文** | [English](THIRD_PARTY_NOTICES.en.md)

发行包包含或引用以下第三方组件。运行时 DLL 的精确版本、来源和 SHA-256 位于
`third_party/dependencies.lock.json` 及各自 `VERSION.txt`；构建工具和内嵌运行时
在正式发布时从上游解析，并记录在发行包的
`build-metadata/toolchain.resolved.json`。适用的完整许可证文本随仓库和发行包提供。

| 组件 | 用途 | 许可证 |
| --- | --- | --- |
| AutoHotkey | 编译版内嵌的 x64 运行时及 PCRE | GPL-2.0-only 及 BSD-3-Clause |
| resvg | SVG 内存栅格化 | MIT 或 Apache License 2.0 |
| Everything SDK DLL | 连接 Everything 索引和后台服务的程序搜索 IPC 客户端 | MIT |
| PingFang | 可选字体包中的简体、港繁和台繁界面首选字体 | 商业分发授权 |
| SF Pro Text | 可选字体包中的拉丁、越南语和西里尔语言界面首选字体 | 商业分发授权 |
| Apple SD Gothic Neo | 可选字体包中的韩文界面首选字体 | 商业分发授权 |
| Harano Aji Gothic | 可选字体包中的日文界面首选字体 | SIL Open Font License 1.1 |
| Noto Sans 及 Noto Sans CJK | 可选字体包中的界面回退字体 | SIL Open Font License 1.1 |
| Lucide Icons 1.27.0 | 按钮、主列表状态与底部统计栏 SVG 图标 | ISC；部分 Feather 派生图标为 MIT |

Lucide 选用图标的版本、来源和完整许可文本保存在
`assets/ui-icons/lucide/`。管理员徽标由 Windows Shell 在运行时提供，项目不复制
或分发该系统资源。发行包在 `licenses/AutoHotkey-LICENSE.txt` 中附带
所用运行时的完整许可证，并在
`licenses/sources/` 附带与内嵌运行时精确提交对应的完整 AutoHotkey 源码归档；
该归档同时包含所用 PCRE 源码及构建文件。`build-metadata/toolchain.resolved.json`
记录二进制与源码下载地址、提交、归档及可执行文件哈希。
Ahk2Exe 仅作为构建工具使用，不进入发行包；每次人工发布选择其最新发布版，采用
WTFPL。actionlint
和 Gitleaks 仅用于验证 GitHub Actions 工作流及公开历史，不进入发行包，采用
MIT 许可证。

可选字体包中字体的家族、版本、来源和 SHA-256 位于
[`assets/fonts/metadata.json`](https://github.com/realSilasYang/process-watchdog/blob/main/assets/fonts/metadata.json)，完整 OFL 文本位于
[`assets/fonts/OFL-1.1.txt`](https://github.com/realSilasYang/process-watchdog/blob/main/assets/fonts/OFL-1.1.txt)。PingFang、SF Pro Text
与 Apple SD Gothic Neo 依据项目所有者确认持有的商业分发授权在独立字体包中提供，公开授权边界
见[`商业字体授权说明`](https://github.com/realSilasYang/process-watchdog/blob/main/assets/fonts/COMMERCIAL-LICENSE-NOTICE.md)；这些字体
不适用本项目的开源许可证。Harano Aji Gothic 与 Noto 继续采用 OFL 1.1。两个程序
版本均不包含字体，运行时也不私有加载字体。Everything 本体不随项目分发；请从
[官方网站](https://www.voidtools.com/downloads/)获取最新版，`Everything64.dll` 不能替代它。

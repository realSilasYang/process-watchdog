# 第三方软件声明

发行包包含或引用以下第三方组件。运行时 DLL 的精确版本、来源和 SHA-256 位于
`third_party/dependencies.lock.json` 及各自 `VERSION.txt`；构建工具和内嵌运行时
记录在 `tools/toolchain.lock.json`。适用的完整许可证文本随仓库和发行包提供。

| 组件 | 用途 | 许可证 |
| --- | --- | --- |
| AutoHotkey | 编译版内嵌的 x64 运行时及 PCRE | GPL-2.0-only 及 BSD-3-Clause |
| resvg | SVG 内存栅格化 | MIT 或 Apache License 2.0 |
| Everything SDK DLL | 可选的文件搜索加速 | MIT |
| Google Material Symbols Rounded | 状态图标基础路径 | Apache License 2.0 |

发行包在 `licenses/AutoHotkey-LICENSE.txt` 中附带所用运行时的完整许可证，并在
`licenses/sources/` 附带与内嵌运行时精确提交对应的完整 AutoHotkey 源码归档；
该归档同时包含所用 PCRE 源码及构建文件。`build-metadata/toolchain.lock.json`
记录二进制与源码下载地址、提交、归档及可执行文件哈希。
Ahk2Exe 仅作为构建工具使用，不进入发行包；其锁定版本采用 WTFPL。actionlint
和 Gitleaks 仅用于验证 GitHub Actions 工作流及公开历史，不进入发行包，采用
MIT 许可证。

本项目对 Material Symbols 的配色、组合和留白做了调整，来源明细见
`assets/status-icons/README.md`。

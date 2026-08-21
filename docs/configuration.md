# 配置、备份与恢复

**简体中文** | [English](en/configuration.md)

`watchdog.ini` 是本机运行配置，使用 UTF-16 LE 编码，由程序执行原子替换写入。
仓库不会跟踪该文件。`config/watchdog.example.ini` 展示当前默认设置和就地注释，
可以用于理解字段，但不要用它覆盖已有配置。

程序会按当前界面语言生成简体中文、港繁、台繁、英文、日文、越南文、韩文、西班牙文、
法文、葡萄牙文、俄文、德文或意大利文注释；
节名、键名和值不会翻译。仓库示例沿用默认中文说明，其他语言仍使用相同的稳定键名。
切换语言并保存后，程序会立即移除旧语言的自动注释再写入当前语言，不会叠加。

`UiLanguage=auto` 表示跟随 Windows 界面语言。也可在设置的“显示”页选择语言，
或填写 `zh-CN`、`zh-HK`、`zh-TW`、`en-US`、`ja-JP`、`vi-VN`、`ko-KR`、
`es-ES`、`fr-FR`、`pt-BR`、`ru-RU`、`de-DE`、`it-IT` 之一；不受支持的系统语言
在自动模式下回退英语。设置界面保存后会在当前进程内热切换：主窗口标题、按钮、
当前状态、右键菜单和托盘立即更新，短生命周期窗口关闭后按新语言重新创建，后续日志、
诊断与更新检查也使用新语言。既有日志保留写入时的原文，核心守护、目标控制器、PID、
调度任务、主窗口和列表句柄均不会重建。

`UiFont=auto` 按下表解析当前界面语言的内容字体。每一级字体都必须已经安装到
Windows 并能由 GDI 实际创建；程序不会从自身目录或字体 ZIP 私有加载字体。首选字体
不可用时依次尝试已安装的 Noto 字体和最后一列 Windows 系统字体。

| 界面语言 | 首选字体 | 已安装 Noto 回退 | Windows 最终兜底 |
| --- | --- | --- | --- |
| 简体中文 | PingFang SC | Noto Sans CJK SC | Microsoft YaHei UI |
| 繁體中文（香港） | PingFang HK | Noto Sans CJK HK | Microsoft JhengHei UI |
| 繁體中文（台灣） | PingFang TC | Noto Sans CJK TC | Microsoft JhengHei UI |
| 日本語 | Harano Aji Gothic | Noto Sans CJK JP | Yu Gothic UI |
| 한국어 | AppleSDGothicNeoR00 | Noto Sans CJK KR | Malgun Gothic |
| English、Tiếng Việt、Español、Français、Português（Brasil）、Русский、Deutsch、Italiano | SF Pro Text | Noto Sans | Segoe UI |

可选字体包提供表中的首选字体和 Noto 回退字体，需由用户先安装到 Windows；它不包含在
便携版或源码版中，也不是程序运行必需。第二级回退取自 Google `NoTofu` 字体集：
拉丁字体保留可变字重与字宽，CJK 字体保留原始 45 字体面集合及各地区家族。OFL 与商业
字体的授权边界分别记录在字体包的许可证和商业授权声明中。

也可在“显示”页从本机已安装字体中选择；保存后会与语言一起在当前进程内立即应用。
该设置控制正文、输入框、列表以及“关于”页标题和信息等内容控件。按钮、设置切换
标签和主窗口底部状态栏不跟随 `UiFont`，始终使用表中最后一列对应的 Windows 系统
UI 字体粗体。配置中填写了无效或已卸载字体时，程序会回退
到 `auto`，不会把任意字体名传给界面。

## EXE 与源码的配置关系

配置位置由实际运行入口所在目录决定：

- 便携 `进程守护小助手.exe` 与 `进程守护小助手.ahk` 位于同一目录时，共用
  `watchdog.ini`。
- 两者位于不同目录时，各自读写所在目录内的配置，彼此不会自动同步。
- 两种形态使用完全相同的配置格式；全局单实例锁会阻止它们同时运行。
- 若要从一种形态切换到另一种形态，应先退出当前实例。需要沿用设置时，把两份
  配置文件复制到新的实际运行目录。
- 同目录共存只建议用于临时切换验证。EXE 包与源码包共用部分发行目录和一份
  `update-manifest.json`，不能把它们当作两套可分别自动更新的安装；需要长期保留
  两套形态时请使用不同的实际运行目录，并在完全退出后按需复制两份配置。

`CheckUpdatesOnStartup=1` 表示启动完成后在独立后台进程中检查小助手新版；设为
`0` 只关闭启动检查，仍可从“关于”页手动检查。

`AskBeforeRestartFromStopCount=2` 控制已开启“停止后每次询问恢复”的守护对象从第几次
确认停止开始显示恢复选择。取值范围是 `1-9999`；修改后会立即应用，并重新开始本轮停止计数。

## 守护对象与启动环境

`[Apps]` 中每个 `AppN` 保存九个稳定字段：

```text
Enabled|RunAsAdmin|Path|WorkDir|Args|EnvVars|ResolvedTarget|ResolvedTargetManual|ShortcutArgs
```

其中除布尔值和目标路径外的文本由小助手以 `<HEX>` 编码。不要手工插入竖线或改写
编码内容。`[Display]`、`[Launch]` 和 `[Identity]` 使用相同的 `AppN` 与守护对象
对应，并与 `[Apps]` 在同一个原子事务中保存。

`[Display]` 的第三个字段是序号圆点设置：留空或 `none` 表示不显示；颜色预设键表示
用户自定义颜色。

`[Launch]` 只在守护对象指定了自定义启动程序或解释器时保存：

```text
AppN=<HEX RuntimePath>|<HEX RuntimeArgs>
```

- `RuntimePath` 是 Python、AutoHotkey、PowerShell、Node.js、Java、Ruby、Perl、
  PHP、Lua、Bash 或其他运行时的可执行文件路径。
- `RuntimeArgs` 是运行时自身参数。实际顺序固定为
  `"RuntimePath" RuntimeArgs "TargetPath" Args`；例如运行 JAR 时填写 `-jar`。
- 两项均留空时，小助手按目标类型沿用默认启动方式；不会改变既有守护对象的行为。
- 自定义运行时只适用于直接脚本或文档型目标。快捷方式继续从 LNK 启动，普通 EXE
  直接启动，因此对应界面不会显示无关字段。
- `EnvVars` 每行使用 `KEY=VALUE`。值可以引用 `%PATH%` 等现有变量；这些覆盖只在
  小助手启动目标的一次调用期间生效，不会永久修改系统或小助手环境。

`[Identity]` 由小助手自动维护，仅为直接文件目标保存内容身份：

```text
AppN=FileSize|SHA256
```

文件大小用于快速筛选，完整 SHA-256 用于最终确认。该基线支持文件本身或上级目录
改名、跨目录和跨磁盘移动后的路径找回，也能识别小助手关闭期间发生的移动；文件名、
Windows 文件 ID 和目录通知不作为身份依据。不要手工编辑此节。

无法解析的 `[Launch]` 或 `[Identity]` 内容会与对应守护对象原文一起进入 `[Recovery]`，不会带着
不完整的启动环境注册。撤销、重做、路径修改和守护对象排序也会把这两个字段纳入守护对象快照。

## 备份

退出小助手后复制以下文件：

- `watchdog.ini`：设置、窗口布局、守护对象、启动环境和显示自定义。

配置写入失败时，正式文件保持原样并进行低频退避重试。无法解析的监控记录会
连同相关显示配置移入 `[Recovery]`，方便人工核对。

## 恢复

在程序退出状态下，把备份文件放回 EXE 或主 AHK 文件所在目录。若备份来自字段
格式不同的版本，应先按对应 Release 说明执行一次性迁移，不能直接依赖旧兼容
分支。

## 隐私边界

配置和运行日志可能包含程序路径、参数及环境变量。提交 Issue 前应删除不希望
公开的内容；“导出诊断包”是用户主动操作，不会自动上传。

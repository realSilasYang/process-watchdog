# 进程守护小助手

基于 AutoHotkey v2 x64 的进程、脚本、快捷方式和 Windows 服务守护工具。

## 运行要求

- Windows 10 或 Windows 11
- AutoHotkey v2 x64（开发环境当前使用 v2.0.26）
- `Everything64.dll` 为可选搜索加速组件；缺失时自动使用后台原生扫描

## 架构

- `App`：唯一业务模型，持有监控顺序、状态机、共享监听器和后台工作进程
- `Main`：主窗口，只投影 `App` 中的状态
- `GuiModules`：设置、添加、搜索、日志等短生命周期窗口的所有者

主线程只执行快速的原生探测和 UI 更新。WMI 进程命令行查询、磁盘搜索与批量导入均在隐藏的短生命周期工作进程中执行，通过 UTF-16 临时文件原子交付结果。安装目录监听器按规范化根目录共享，再把变化定向分发给订阅目标。

## 配置格式

`watchdog.ini` 的 `[Apps]` 当前字段顺序为：

```text
Enabled|RunAsAdmin|Path|WorkDir|Args|EnvVars|ResolvedTarget|ResolvedTargetManual|ShortcutArgs
```

旧的 8 字段记录会在读取时补全快捷方式内置参数，并在下次成功保存时写成当前格式。无法解析的记录不会被静默删除，而会保留到 `[Recovery]` 并写入运行日志。

`watchdog.maintenance.ini` 只保存尚未结束的升级保护会话，可以为空。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\static-check.ps1
```

测试会检查三项根全局、已废弃平滑滚动符号、当前 INI 字段与维护配置对应关系。GUI 行为仍需在不同 DPI 的显示器上做手工回归。

项目根目录中的 `_codex_tab_theme_test.ahk` 是既有手工主题探针；搜索和批量导入会主动排除 `_codex_*.ahk`，不会把它加入守护列表。

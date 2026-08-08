; en-US 本地化词条目录。
; 本目录由模型直接依据简体中文稳定键逐条翻译；生成步骤仅处理转义与格式。

class EnglishStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Press")
        catalog.Set(
            "`n位置：{1}",
                "`nLocation: {1}")
        catalog.Set(
            "`r`n      影响：该守护对象本次未加入守护列表。",
                "`r`n      Impact: this item was not added to the watchlist during this run.")
        catalog.Set(
            "`r`n      目标：{1}",
                "`r`n      Target: {1}")
        catalog.Set(
            "`r`n      问题：{1}：{2}",
                "`r`n      Problem: {1}: {2}")
        catalog.Set(
            "`r`n  [{1}] 位置：[{2}] {3}",
                "`r`n  [{1}] Location: [{2}] {3}")
        catalog.Set(
            "`r`n  处理建议：确认目标路径后，可在主界面重新添加该守护对象；也可退出小助手后检查上述配置位置。后续保存配置时，损坏记录会转存到 [Recovery]，不会被静默删除。",
                "`r`n  Recommended action: verify the target path, then add the item again from the main window`; alternatively, exit the assistant and inspect the configuration locations above. The next time the configuration is saved, damaged records will be moved to [Recovery] instead of being silently discarded.")
        catalog.Set(
            "`r`n  配置文件：{1}",
                "`r`n  Configuration file: {1}")
        catalog.Set(
            "   ⚠️ 配置未保存",
                "   ⚠️ Configuration not saved")
        catalog.Set(
            "  --maintenance-begin `"目标完整路径`"    开始维护",
                "  --maintenance-begin `"full target path`"    Begin maintenance")
        catalog.Set(
            "  --maintenance-end `"目标完整路径`"      结束维护",
                "  --maintenance-end `"full target path`"      End maintenance")
        catalog.Set(
            " 已保留并保存此前添加的 {1} 个守护对象。",
                " {1} previously added monitored item(s) were retained and saved.")
        catalog.Set(
            " 扫描达到时间或数量上限，结果已截断。",
                " The scan reached its time or result limit, so the results were truncated.")
        catalog.Set(
            "`; AllowForceTerminate：正常退出超时后是否允许强制结束进程。",
                "`; AllowForceTerminate: whether the process may be forcibly terminated after the graceful-exit timeout.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应，值为软件升级保护的 <HEX> 编码结构。",
                "`; Each AppN entry corresponds to the item with the same name in [Apps]. Its value is the <HEX>-encoded update-protection structure.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应；留空时使用目标自身的名称和图标。",
                "`; Each AppN entry corresponds to the item with the same name in [Apps]. An empty entry uses the target's own name and icon.")
        catalog.Set(
            "`; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。",
                "`; CheckInterval: status-check interval in milliseconds`; valid range: 500-86400000.")
        catalog.Set(
            "`; CheckUpdatesOnStartup：启动后是否在后台检查小助手新版。",
                "`; CheckUpdatesOnStartup: whether to check for a new assistant version in the background after startup.")
        catalog.Set(
            "`; ClearLogsOnStartup：启动时是否清空历史日志。",
                "`; ClearLogsOnStartup: whether to clear existing logs at startup.")
        catalog.Set(
            "`; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col1W: width of the first main-list column, stored in logical pixels at 96 DPI.")
        catalog.Set(
            "`; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col2W: width of the second main-list column, stored in logical pixels at 96 DPI.")
        catalog.Set(
            "`; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。",
                "`; CtrlCWaitSeconds: maximum number of seconds to wait after a console application receives Ctrl+C`; valid range: 1-60.")
        catalog.Set(
            "`; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。",
                "`; GracefulStopSeconds: maximum number of seconds to wait for a windowed application to exit normally`; valid range: 1-300.")
        catalog.Set(
            "`; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。",
                "`; GuiH: main-window height, stored in logical pixels at 96 DPI.")
        catalog.Set(
            "`; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。",
                "`; GuiW: main-window width, stored in logical pixels at 96 DPI.")
        catalog.Set(
            "`; LogDirectory：留空时使用系统临时目录下的 ProcessWatchdogLogs。",
                "`; LogDirectory: leave empty to use ProcessWatchdogLogs under the system temporary directory.")
        catalog.Set(
            "`; LogMaxEntries：日志界面保留条数，范围 50～10000。",
                "`; LogMaxEntries: number of entries retained in the log window`; valid range: 50-10000.")
        catalog.Set(
            "`; LogRetentionDays：日志文件保留天数，范围 1～3650。",
                "`; LogRetentionDays: number of days to retain log files`; valid range: 1-3650.")
        catalog.Set(
            "`; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。",
                "`; RecursiveBatchImport: whether folder batch import recursively scans subfolders.")
        catalog.Set(
            "`; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。",
                "`; RetrySequence: comma-separated restart delays in seconds`; up to 10 values, each within 1-86400.")
        catalog.Set(
            "`; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。",
                "`; ShowAfterReload: internal reload flag`; automatically reset to 0 when reloading finishes.")
        catalog.Set(
            "`; ShowAtStartup：启动后是否显示主窗口。",
                "`; ShowAtStartup: whether to show the main window after startup.")
        catalog.Set(
            "`; UiLanguage：界面语言；auto 表示跟随系统，也可填写受支持的语言代码。",
                "`; UiLanguage: interface language`; auto follows the system language, or a supported language code may be specified.")
        catalog.Set(
            "`; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。",
                "`; Stores only the name and icon source shown in the main window. It does not affect process matching, launching, or update protection.")
        catalog.Set(
            "`; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
                "`; Internal fields: Enabled, RootIsCustom, DetectionSeconds, StableSeconds, MaxWaitSeconds, InstallRoot, and Actor.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。",
                "`; Boolean values use 1 for enabled and 0 for disabled. Prefer changing them through the Settings window.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。",
                "`; Boolean values use 1 for enabled and 0 for disabled. <HEX> content is encoded and decoded automatically.")
        catalog.Set(
            "`; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。",
                "`; Change these values through the Update Protection window instead of editing the encoded content directly.")
        catalog.Set(
            "`; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。",
                "`; Monitored-item records that cannot be parsed safely are retained here to prevent silent data loss. Manual changes are not normally required.")
        catalog.Set(
            "`; 本区保存运行参数；以分号开头的注释不会参与软件读取。",
                "`; This section stores runtime settings. Comments beginning with a semicolon are ignored when the application reads the file.")
        catalog.Set(
            "`; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
                "`; Format: enabled state | run as administrator | target path | working directory | launch arguments | environment variables | resolved shortcut target | manual-target flag | shortcut arguments.")
        catalog.Set(
            "`; 每个 AppN 对应一个守护对象，九个字段使用竖线分隔。",
                "`; Each AppN entry represents one monitored item. Its nine fields are separated by vertical bars.")
        catalog.Set(
            "DPI 变化后刷新图标失败：{1}",
                "Failed to refresh icons after the DPI changed: {1}")
        catalog.Set(
            "DPI 变化后重建图标列表失败：{1}",
                "Failed to rebuild the icon list after the DPI changed: {1}")
        catalog.Set(
            "DPI 图标重建回调无效",
                "The DPI icon-rebuild callback is invalid")
        catalog.Set(
            "{1} 条监控配置未载入，相关守护对象当前不会被守护。点击查看具体位置和原因。",
                "{1} monitoring configuration record(s) could not be loaded, so the corresponding items are not currently monitored. Click to view their locations and the reasons.")
        catalog.Set(
            "• Ahk2Exe 只在发布服务器上用于生成 EXE，不随小助手安装，普通用户和源码运行用户都不需要维护它。",
                "• Ahk2Exe is used only on the release server to create the EXE. It is not installed with the assistant, and neither regular users nor source-edition users need to maintain it.")
        catalog.Set(
            "• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。",
                "• Ctrl+A selects all items. Esc first clears the selection`; pressing Esc again when nothing is selected hides the main window.")
        catalog.Set(
            "• EXE 版已内嵌该版本发布时验证通过的 AutoHotkey；更新完整小助手发行包时，内嵌运行时会一同更新，电脑无需另装 AutoHotkey。",
                "• The EXE edition embeds the AutoHotkey runtime validated for that release. Updating the complete assistant package also updates the embedded runtime, so AutoHotkey does not need to be installed separately.")
        catalog.Set(
            "• EXE 版更新完整编译包；Git 源码版仅在受跟踪文件无修改且可快速前进时更新；其他源码版使用源码发行包。",
                "• The EXE edition updates from the complete compiled package. A Git source checkout updates only when its tracked files are unchanged and it can fast-forward to the release tag. Other source installations use the source release package.")
        catalog.Set(
            "• 主界面的“日志”显示本次运行中的监控、重启、升级保护和操作记录，并会自动更新。",
                "• Logs on the main window shows monitoring, restart, update-protection, and user-action records from the current session, and updates automatically.")
        catalog.Set(
            "• 也可将文件或文件夹直接拖放到主列表；已经存在的守护对象不会重复添加。",
                "• You can also drag files or folders directly onto the main list. Existing items will not be added again.")
        catalog.Set(
            "• 停止：设置窗口程序和命令行程序的退出等待，以及是否允许强制终止。",
                "• Stopping: configure exit timeouts for windowed and console applications, and whether forced termination is allowed.")
        catalog.Set(
            "• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。",
                "• Closing the main window leaves the assistant running in the system tray. Use the tray menu to show the main window again, reload, or exit.")
        catalog.Set(
            "• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。",
                "• If the update wait times out or was detected incorrectly, choose End Update Wait and Resume Monitoring. The target file is still checked for a safe start before monitoring resumes.")
        catalog.Set(
            "• 单击选择守护对象；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。",
                "• Click an item to select it. Hold Ctrl or Shift to select multiple items. Drag list rows to change the monitoring order.")
        catalog.Set(
            "• 双击守护对象或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。",
                "• Double-click an item or press F2 to edit its full path. Delete removes it, Ctrl+Z undoes, and Ctrl+Shift+Z or Ctrl+Y redoes.")
        catalog.Set(
            "• 发现新版后会先询问；确认后校验完整发行包，退出当前实例、替换受管文件并自动重启，不会覆盖个人配置和升级保护会话。",
                "• When a new version is found, the assistant asks before proceeding. After confirmation, it verifies the complete release package, exits the current instance, replaces managed files, and restarts automatically without overwriting personal configuration or update-protection sessions.")
        catalog.Set(
            "• 可控的更新脚本可显式发送维护指令：",
                "• Update scripts under your control can send explicit maintenance commands:")
        catalog.Set(
            "• 在守护对象右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。",
                "• Open Update Protection from an item's context menu to adjust the installation directory, exit-detection window, file-stability wait, and maximum update wait, or to clear learned updater signatures.")
        catalog.Set(
            "• 多个守护对象状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。",
                "• When all selected items have the same state, Pause pauses or resumes them together. With mixed states, each item is toggled individually.")
        catalog.Set(
            "• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。",
                "• The assistant verifies the target path or command line so processes are not mistaken for one another based only on their names.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“通用”页会同时显示当前小助手版本、运行形态和实际运行时版本。",
                "• The assistant version and AutoHotkey version are independent. General displays the current assistant version, edition, and actual runtime version together.")
        catalog.Set(
            "• 程序搜索：仅使用 Everything 服务并显示全部匹配结果；使用前请保持 Everything 正在运行。",
                "• Program search: uses only the Everything service and displays every matching result. Keep Everything running before you search.")
        catalog.Set(
            "• 日志：设置运行日志内存上限、批处理输出日志的保存目录、保留时间和启动时清理策略。",
                "• Logs: configure the in-memory runtime-log limit, batch-output log directory, retention period, and startup cleanup policy.")
        catalog.Set(
            "• 暂停守护对象会取消它的重试和升级检测；恢复后会重新检查目标状态。",
                "• Pausing an item cancels its retries and update detection. Its target state is checked again when monitoring resumes.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“重启等待序列”依次重试；连续失败时采用后续等待时间，避免频繁拉起。",
                "• After detecting that a target has stopped, the assistant confirms its state and retries according to the Restart Delay Sequence. Later delays are used after repeated failures to prevent rapid restart loops.")
        catalog.Set(
            "• 每次正式发布开始时都会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版（可能为预发布），冻结本次版本后完成全套测试；只有通过才生成发行包。",
                "• At the beginning of every official release, the latest stable AutoHotkey version and latest released Ahk2Exe version（which may be a prerelease）are selected anew and frozen for that release. A package is created only after the full test suite passes.")
        catalog.Set(
            "• 源码版使用电脑当前安装的 AutoHotkey；小助手更新只更新项目源码，不会安装或升级本机解释器。",
                "• The source edition uses the AutoHotkey installation already on this computer. Updating the assistant changes only the project source and does not install or update the local interpreter.")
        catalog.Set(
            "• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。",
                "• Click Add to search for an application, or select an application, script, shortcut, or folder.")
        catalog.Set(
            "• 界面语言和字体可在“通用”中手动切换；保存后立即更新主窗口、菜单和托盘，无需重新启动。",
                "• The interface language and font can be changed under General. Saving updates the main window, menus, and tray immediately, without restarting.")
        catalog.Set(
            "• 启动 / 监控：设置状态检查间隔、重启等待序列、启动后是否显示主窗口、是否检查小助手更新，以及文件夹批量导入是否递归。",
                "• Startup / Monitoring: configure the status-check interval, restart delay sequence, whether to show the main window and check for assistant updates after startup, and whether folder batch import is recursive.")
        catalog.Set(
            "• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。",
                "• After an update is confirmed, automatic restart is suspended. Monitoring resumes automatically after the related activity ends and the target files become stable. Updater signatures observed during real updates are learned automatically.")
        catalog.Set(
            "• 程序：EXE、COM、MSC。",
                "• Applications: EXE, COM, and MSC.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，并可立即检查小助手更新。",
                "• General: create Desktop and Start menu shortcuts, enable or disable scheduled startup, and check for assistant updates immediately.")
        catalog.Set(
            "• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。",
                "• Scripts: AHK, Python, JavaScript, VBScript, PowerShell, batch files, Ruby, Perl, PHP, Lua, JAR, Shell, and others.")
        catalog.Set(
            "• 软件升级保护默认关闭。需要时在守护对象右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。",
                "• Update protection is disabled by default. When needed, open Update Protection from the item's context menu, select Automatically detect updates and protect startup, and save.")
        catalog.Set(
            "• 选中守护对象后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。",
                "• After selecting items, you can pause, resume, or delete them. Pausing stops only monitoring and does not close a target that is already running.")
        catalog.Set(
            "• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控”控制。",
                "• Selecting a folder batch-imports the supported files it contains. Whether subfolders are scanned is controlled under Monitoring in Settings.")
        catalog.Set(
            "• 守护对象右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。",
                "• View Runtime Log in an item's context menu opens the output log generated for a BAT or CMD target. For other target types, or before a log has been generated, a file-not-found message appears.")
        catalog.Set(
            "⏳ 正在结束运行...",
                "⏳ Stopping the target...")
        catalog.Set(
            "⏳ 判断是否正在升级",
                "⏳ Checking whether an update is in progress")
        catalog.Set(
            "⏳ 升级完成，准备恢复",
                "⏳ Update complete`; preparing to resume")
        catalog.Set(
            "⏳ 启动倒计时 {1} 秒",
                "⏳ Starting in {1} seconds")
        catalog.Set(
            "⏳ 启动失败，稍后自动重试",
                "⏳ Start failed`; retrying later")
        catalog.Set(
            "⏳ 确认升级文件稳定",
                "⏳ Confirming update-file stability")
        catalog.Set(
            "⏳ 确认升级文件稳定 {1}s",
                "⏳ Confirming update-file stability {1}s")
        catalog.Set(
            "⏳ 稍后自动重试 {1} 秒",
                "⏳ Retrying automatically in {1} seconds")
        catalog.Set(
            "⏳ 等待安全启动条件",
                "⏳ Waiting for safe-start conditions")
        catalog.Set(
            "⏳ 等待进程状态...",
                "⏳ Waiting for process status...")
        catalog.Set(
            "⏳ 重试倒计时 {1} 秒",
                "⏳ Retry in {1} seconds")
        catalog.Set(
            "⏳ 验证运行状态...",
                "⏳ Verifying running state...")
        catalog.Set(
            "⏸️ 已暂停",
                "⏸️ Paused")
        catalog.Set(
            "⏸️ 暂停",
                "⏸️ Pause")
        catalog.Set(
            "▶️ 恢复",
                "▶️ Resume")
        catalog.Set(
            "⚙️ 启动参数：{1}`n",
                "⚙️ Launch arguments: {1}`n")
        catalog.Set(
            "⚠️ 升级等待超时",
                "⚠️ Update Wait Timed Out")
        catalog.Set(
            "⚠️ 疑似停止",
                "⚠️ Possibly Stopped")
        catalog.Set(
            "⚠️ 运行中（权限不符）",
                "⚠️ Running（Privilege Mismatch）")
        catalog.Set(
            "✅ 已启动（非驻留目标）",
                "✅ Started（Nonresident Target）")
        catalog.Set(
            "✅ 运行中",
                "✅ Running")
        catalog.Set(
            "✅ 运行：{1}   🚫 停止：{2}   ⏳ 恢复：{3}   🔄 升级：{4}   ⏸️ 暂停：{5}   ❌ 失效：{6}   ｜   🎯 总计：{7}",
                "✅ Running: {1}   🚫 Stopped: {2}   ⏳ Recovering: {3}   🔄 Updating: {4}   ⏸️ Paused: {5}   ❌ Invalid: {6}   |   🎯 Total: {7}")
        catalog.Set(
            "✒️ 编辑完整路径（F2）",
                "✒️ Edit Full Path（F2）")
        catalog.Set(
            "确 定",
                "OK")
        catalog.Set(
            "取 消",
                "Cancel")
        catalog.Set(
            "❌ 无法结束运行",
                "❌ Could Not Stop Target")
        catalog.Set(
            "❌ 目标不存在",
                "❌ Target Not Found")
        catalog.Set(
            "❌ 程序不存在",
                "❌ Application Not Found")
        catalog.Set(
            "❌ 脚本不存在",
                "❌ Script Not Found")
        catalog.Set(
            "➕ 添加",
                "➕ Add")
        catalog.Set(
            "。",
                ".")
        catalog.Set(
            "一、快速上手",
                "1. Quick Start")
        catalog.Set(
            "七、软件升级保护",
                "7. Update Protection")
        catalog.Set(
            "三、主界面操作",
                "3. Main Window")
        catalog.Set(
            "不允许的升级保护阶段转换：{1}",
                "Disallowed update-protection phase transition: {1}")
        catalog.Set(
            "不支持的启动规格类型",
                "Unsupported launch specification type")
        catalog.Set(
            "不支持的图标格式",
                "Unsupported icon format")
        catalog.Set(
            "不是当前 <HEX> 编码格式",
                "Not encoded in the current <HEX> format")
        catalog.Set(
            "与已加载守护对象重复，或目标格式无效",
                "Duplicates a loaded item or uses an invalid target format")
        catalog.Set(
            "主进程监控",
                "Main process monitoring")
        catalog.Set(
            "主进程监控异常：{1}",
                "Main process monitoring error: {1}")
        catalog.Set(
            "二、支持的守护对象",
                "2. Supported Targets")
        catalog.Set(
            "五、设置",
                "5. Settings")
        catalog.Set(
            "代码热重载完毕，界面已恢复显示。",
                "Hot reload completed and the window is visible again.")
        catalog.Set(
            "仲裁期间捕获到升级活动",
                "Update activity detected during arbitration")
        catalog.Set(
            "使用说明",
                "User Guide")
        catalog.Set(
            "恢复默认",
                "Restore Default")
        catalog.Set(
            "保存",
                "Save")
        catalog.Set(
            "保存升级保护恢复状态失败：{1}",
                "Failed to save update-protection recovery state: {1}")
        catalog.Set(
            "保存失败",
                "Save Failed")
        catalog.Set(
            "保存显示设置失败，请查看运行日志。",
                "Could not save display settings. Check the runtime log for details.")
        catalog.Set(
            "保存监控配置失败：{1}",
                "Failed to save monitoring configuration: {1}")
        catalog.Set(
            "保存窗口布局失败：{1}",
                "Failed to save the window layout: {1}")
        catalog.Set(
            "保存设置失败，请查看运行日志。",
                "Could not save settings. Check the runtime log for details.")
        catalog.Set(
            "保存软件升级保护设置失败，请查看运行日志。",
                "Could not save update-protection settings. Check the runtime log for details.")
        catalog.Set(
            "保存运行参数失败：{1}",
                "Failed to save runtime settings: {1}")
        catalog.Set(
            "值不是 0 或 1",
                "The value is neither 0 nor 1")
        catalog.Set(
            "停止",
                "Stopping")
        catalog.Set(
            "八、日志与托盘",
                "8. Logs and System Tray")
        catalog.Set(
            "六、版本与小助手自身更新",
                "6. Versions and Assistant Updates")
        catalog.Set(
            "内容为空",
                "The content is empty")
        catalog.Set(
            "内容无法解析",
                "The content could not be parsed")
        catalog.Set(
            "创建快捷方式失败：{1}",
                "Could not create shortcuts: {1}")
        catalog.Set(
            "初始化...",
                "Initializing...")
        catalog.Set(
            "删除选中的守护对象（支持多选，可撤销）`n快捷键：Delete",
                "Delete selected monitored items（supports multiple selection and undo）`nKey: Delete")
        catalog.Set(
            "刷新主窗口状态失败，已暂停界面倒计时刷新：{1}",
                "Failed to refresh main-window status`; countdown updates have been paused: {1}")
        catalog.Set(
            "刷新运行日志窗口失败，已暂停自动刷新：{1}",
                "Failed to refresh the runtime-log window`; automatic refresh has been paused: {1}")
        catalog.Set(
            "升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。",
                "Update protection requires an application or script with a valid full path. The installation directory must exist and contain the target file.")
        catalog.Set(
            "升级保护仍在进行",
                "Update protection is still active")
        catalog.Set(
            "升级保护初始化时无法建立进程基线，将在下一轮重试。",
                "Update protection could not establish a process baseline during initialization and will retry on the next cycle.")
        catalog.Set(
            "升级保护协调器未能初始化，核心守护不会启动。",
                "The update-protection coordinator could not be initialized, so core monitoring will not start.")
        catalog.Set(
            "升级保护配置",
                "Update-protection configuration")
        catalog.Set(
            "升级文件监听",
                "Update file watcher")
        catalog.Set(
            "升级文件监听异常（{1}）：{2}",
                "Update file watcher error（{1}）: {2}")
        catalog.Set(
            "升级文件监听异常：{1}",
                "Update file watcher error: {1}")
        catalog.Set(
            "升级等待已超时",
                "The update wait timed out")
        catalog.Set(
            "升级进程扫描",
                "Update process scan")
        catalog.Set(
            "升级进程扫描异常：{1}",
                "Update process scan error: {1}")
        catalog.Set(
            "参数错误",
                "Parameter Error")
        catalog.Set(
            "发现小助手新版本：{1}（当前版本：{2}）",
                "A new assistant version is available: {1}（current version: {2}）")
        catalog.Set(
            "发现新版本 {1}，当前版本为 {2}。{3}{3}{4}{3}{3}是否立即更新？",
                "Version {1} is available`; the current version is {2}.{3}{3}{4}{3}{3}Update now?")
        catalog.Set(
            "取消",
                "Cancel")
        catalog.Set(
            "名称",
                "Name")
        catalog.Set(
            "后台任务耗时较长：{1}，本次 {2} 毫秒",
                "Background task is taking longer than expected: {1}`; this run took {2} ms")
        catalog.Set(
            "后台扫描进程未返回 PID",
                "The background scan process did not return a PID")
        catalog.Set(
            "后台调度任务异常（{1}）：{2}",
                "Background scheduling task error（{1}）: {2}")
        catalog.Set(
            "后台进程快照为空或不完整，已忽略本次结果并安排重试。",
                "The background process snapshot was empty or incomplete. This result was ignored and a retry was scheduled.")
        catalog.Set(
            "后台进程快照已确认",
                "Background process snapshot confirmed")
        catalog.Set(
            "后台进程快照未及时返回，已等待完整检测窗口",
                "The background process snapshot did not return in time`; the full detection window was observed")
        catalog.Set(
            "启动前没有可用的启动目标，已停止重试：{1}{2}",
                "No usable launch target was available before startup`; retries were stopped: {1}{2}")
        catalog.Set(
            "启动参数",
                "Launch arguments")
        catalog.Set(
            "启动参数（Args）：",
                "Launch arguments（Args）:")
        catalog.Set(
            "启动器需要 LaunchSpec",
                "The launcher requires a LaunchSpec")
        catalog.Set(
            "启动失败",
                "Startup Failed")
        catalog.Set(
            "启动失败 [{1}/{2}]：{3} - {4}",
                "Startup failed [{1}/{2}]: {3} - {4}")
        catalog.Set(
            "启动成功且运行稳定：{1}",
                "Started successfully and remained stable: {1}")
        catalog.Set(
            "启动批量导入失败",
                "Failed to start folder batch import")
        catalog.Set(
            "启动时检查小助手更新",
                "Check for assistant updates at startup")
        catalog.Set(
            "启动时清空批处理日志",
                "Clear batch-output logs at startup")
        catalog.Set(
            "启动目标不可用",
                "The launch target is unavailable")
        catalog.Set(
            "启动目标不存在",
                "The launch target does not exist")
        catalog.Set(
            "启用状态",
                "Enabled state")
        catalog.Set(
            "四、守护与重启",
                "4. Monitoring and Restart")
        catalog.Set(
            "图标来源无效",
                "The icon source is invalid")
        catalog.Set(
            "图标来源：",
                "Icon source:")
        catalog.Set(
            "图标缩放器",
                "Icon resampler")
        catalog.Set(
            "处理后台进程快照时发生错误：{1}",
                "Error while processing the background process snapshot: {1}")
        catalog.Set(
            "处理应用更新结果失败：{1}",
                "Failed to process the application-update result: {1}")
        catalog.Set(
            "字段数量应为 {1}，实际为 {2}",
                "Expected {1} fields, but found {2}")
        catalog.Set(
            "守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！",
                "Process monitoring requires elevated system access. Run this application as administrator.")
        catalog.Set(
            "守护对象：",
                "Watched Target:")
        catalog.Set(
            "安全启动门暂缓启动：{1}（{2}）",
                "The safe-start gate postponed launch: {1}（{2}）")
        catalog.Set(
            "安装目录特征",
                "Installation-directory signature")
        catalog.Set(
            "安装足迹目录：",
                "Installation directory:")
        catalog.Set(
            "完整路径",
                "Full Path")
        catalog.Set(
            "完整路径：{1}",
                "Full path: {1}")
        catalog.Set(
            "导出诊断包",
                "Export Diagnostic Bundle")
        catalog.Set(
            "导出诊断包失败：{1}",
                "Failed to export the diagnostic bundle: {1}")
        catalog.Set(
            "将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。",
                "The complete release package will be downloaded and verified. The assistant will then exit, replace its program files, and restart automatically.")
        catalog.Set(
            "将下载并校验源码发行包，保留个人配置后替换源码并自动重启。",
                "The source release package will be downloaded and verified. Personal configuration will be retained while the source files are replaced, and the assistant will restart automatically.")
        catalog.Set(
            "将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。",
                "The source repository will be checked for uncommitted changes, fast-forwarded to the official release tag, and restarted automatically.")
        catalog.Set(
            "小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。",
                "The assistant monitors applications, scripts, and shortcuts in the background. If a target exits unexpectedly, it is restarted using the configured delay sequence. Closing the main window only hides it in the system tray and does not stop monitoring.")
        catalog.Set(
            "小助手已是最新版本：{1}",
                "The assistant is up to date: {1}")
        catalog.Set(
            "小助手更新",
                "Assistant Update")
        catalog.Set(
            "小助手设置",
                "Assistant Settings")
        catalog.Set(
            "进程守护小助手更新",
                "Process Watchdog Assistant Update")
        catalog.Set(
            "进程守护小助手设置",
                "Process Watchdog Assistant Settings")
        catalog.Set(
            "尚未从真实升级过程学习到更新程序特征。",
                "No updater signature has yet been learned from a real update.")
        catalog.Set(
            "展示配置",
                "Display configuration")
        catalog.Set(
            "工作目录",
                "Working directory")
        catalog.Set(
            "工作目录（CWD）：",
                "Working directory（CWD）:")
        catalog.Set(
            "已从本次升级过程学习更新程序特征：{1}",
                "Updater signatures learned during this update: {1}")
        catalog.Set(
            "已保存身份",
                "Saved identity")
        catalog.Set(
            "已关闭以管理员身份运行：{1}",
                "Run as administrator disabled: {1}")
        catalog.Set(
            "已创建最高权限的开机自启计划任务（Win10 配置，适配笔记本）。",
                "A highest-privilege scheduled startup task was created with Windows 10 power settings suitable for laptops.")
        catalog.Set(
            "已创建桌面与开始菜单快捷方式。",
                "Desktop and Start menu shortcuts were created.")
        catalog.Set(
            "已删除自启计划任务。",
                "The scheduled startup task was removed.")
        catalog.Set(
            "已刷新快捷方式内置参数：{1}",
                "Refreshed arguments embedded in the shortcut: {1}")
        catalog.Set(
            "已刷新快捷方式真实进程（{1}）：{2} -> {3}",
                "Refreshed the shortcut's real process（{1}）: {2} -> {3}")
        catalog.Set(
            "已发送启动指令：{1}{2}",
                "Launch command sent: {1}{2}")
        catalog.Set(
            "已取消监控：{1}",
                "Monitoring cancelled: {1}")
        catalog.Set(
            "已启动批处理并重定向输出到：{1}",
                "Batch target started with output redirected to: {1}")
        catalog.Set(
            "已启动非驻留目标：{1}",
                "Nonresident target started: {1}")
        catalog.Set(
            "已启用以管理员身份运行：{1}",
                "Run as administrator enabled: {1}")
        catalog.Set(
            "已导出本地诊断包：{1}",
                "Local diagnostic bundle exported: {1}")
        catalog.Set(
            "已恢复未完成的升级保护会话：{1}",
                "Restored an unfinished update-protection session: {1}")
        catalog.Set(
            "已撤销上一步操作。",
                "Undid the previous action.")
        catalog.Set(
            "已更新主窗口显示设置：{1}",
                "Updated main-window display settings: {1}")
        catalog.Set(
            "已更新守护对象路径。",
                "The watched-target path was updated.")
        catalog.Set(
            "已更新软件升级保护设置：{1}",
                "Updated update-protection settings: {1}")
        catalog.Set(
            "已添加 {1} 个守护对象。",
                "Added {1} monitored item(s).")
        catalog.Set(
            "已用完快速重试，将每隔 {1} 秒继续尝试启动：{2}",
                "Fast retries exhausted`; launch attempts will continue every {1} seconds: {2}")
        catalog.Set(
            "已自动学习的更新程序特征：",
                "Automatically learned updater signatures:")
        catalog.Set(
            "已进入软件升级保护：{1}{2}",
                "Update protection activated: {1}{2}")
        catalog.Set(
            "已重做操作。",
                "Redid the action.")
        catalog.Set(
            "常规终止权限不足，已提权终止进程 PID：{1}",
                "Standard termination lacked permission`; process PID {1} was terminated with elevation.")
        catalog.Set(
            "序号",
                "No.")
        catalog.Set(
            "应用更新助手不存在",
                "The application-update helper does not exist")
        catalog.Set(
            "应用更新参数无效",
                "The application-update parameters are invalid")
        catalog.Set(
            "应用更新安装进程未返回 PID",
                "The application-update installer did not return a PID")
        catalog.Set(
            "应用更新本地化资源不存在",
                "The application-update localization resource does not exist")
        catalog.Set(
            "应用更新检查进程未返回 PID",
                "The application-update check process did not return a PID")
        catalog.Set(
            "守护对象",
                "Watched Target")
        catalog.Set(
            "应用资源",
                "Application resources")
        catalog.Set(
            "开机自动启动（计划任务）",
                "Start automatically at sign-in（scheduled task）")
        catalog.Set(
            "当前陪伴您的已经是最新版本的小助手啦！",
                "Your assistant is already up to date!")
        catalog.Set(
            "当前应用版本无效",
                "The current application version is invalid")
        catalog.Set(
            "当前版本：{1}（EXE 版；内嵌 AutoHotkey {2} x64）",
                "Current version: {1}（EXE edition`; embedded AutoHotkey {2} x64）")
        catalog.Set(
            "当前版本：{1}（源码版；本机 AutoHotkey {2} x64）",
                "Current version: {1}（source edition`; local AutoHotkey {2} x64）")
        catalog.Set(
            "当前状态：升级活动已结束，正在确认程序文件稳定",
                "Current status: update activity has ended`; confirming that program files are stable")
        catalog.Set(
            "当前状态：升级等待超时，需要确认后恢复",
                "Current status: the update wait timed out and requires confirmation before resuming")
        catalog.Set(
            "当前状态：已从上次运行恢复未完成的升级保护",
                "Current status: an unfinished update-protection session was restored from the previous run")
        catalog.Set(
            "当前状态：已暂停自动启动，正在等待升级完成",
                "Current status: automatic launch is paused while the update completes")
        catalog.Set(
            "当前状态：显式升级维护已开始，正在等待结束命令",
                "Current status: explicit update maintenance is active and waiting for the end command")
        catalog.Set(
            "当前状态：正在判断本次退出是否由升级引起",
                "Current status: determining whether this exit was caused by an update")
        catalog.Set(
            "当前状态：正常守护",
                "Current status: monitoring normally")
        catalog.Set(
            "快捷方式参数",
                "Shortcut arguments")
        catalog.Set(
            "快捷方式及已解析目标均不可用",
                "Neither the shortcut nor its resolved target is available")
        catalog.Set(
            "快捷方式目标",
                "Shortcut target")
        catalog.Set(
            "快捷方式真实目标",
                "Resolved shortcut target")
        catalog.Set(
            "快捷方式真实进程刷新被拒绝，目标已由其它守护对象守护：{1} -> {2}",
                "The shortcut's real-process refresh was rejected because another item already monitors that target: {1} -> {2}")
        catalog.Set(
            "恢复守护：{1}",
                "Monitoring resumed: {1}")
        catalog.Set(
            "恢复记录列表无效",
                "The recovery-record list is invalid")
        catalog.Set(
            "恢复记录无效",
                "The recovery record is invalid")
        catalog.Set(
            "恢复记录缺少字段：{1}",
                "Recovery record is missing a field: {1}")
        catalog.Set(
            "成功",
                "Success")
        catalog.Set(
            "所选文件夹内未找到支持的程序、脚本或快捷方式。",
                "No supported application, script, or shortcut was found in the selected folder.")
        catalog.Set(
            "手动添加守护对象：{1}",
                "Monitoring item added manually: {1}")
        catalog.Set(
            "已结束运行：{1}",
                "Stopped target: {1}")
        catalog.Set(
            "结束运行失败，目标进程未能停止：{1}",
                "Could not stop target process: {1}")
        catalog.Set(
            "托管窗口生命周期尚未配置",
                "The managed-window lifecycle has not been configured")
        catalog.Set(
            "托管窗口生命周期适配器无效",
                "The managed-window lifecycle adapter is invalid")
        catalog.Set(
            "扩展设置包含无效数值。`n`n窗口程序关闭等待：1-300 秒`n命令行程序退出等待：1-60 秒`n日志条数：50-10000`n日志保留：1-3650 天",
                "One or more advanced settings are invalid.`n`nWindowed application close wait: 1-300 seconds`nConsole application exit wait: 1-60 seconds`nLog entries: 50-10000`nLog retention: 1-3650 days")
        catalog.Set(
            "批处理启动需要输出日志路径",
                "Launching a batch target requires an output-log path")
        catalog.Set(
            "批量导入中断",
                "Batch Import Interrupted")
        catalog.Set(
            "批量导入完成",
                "Batch Import Complete")
        catalog.Set(
            "批量导入已取消，已保留并保存此前添加的 {1} 个守护对象。",
                "Folder batch import was cancelled. The {1} item(s) added earlier were retained and saved.")
        catalog.Set(
            "拒绝修改路径，真实进程已由其它守护对象守护：{1}",
                "Path change rejected because another item already monitors the real process: {1}")
        catalog.Set(
            "拒绝更新路径，已存在相同的守护对象：{1}",
                "Path update rejected because an identical watched target already exists: {1}")
        catalog.Set(
            "按钮绘制器",
                "Button renderer")
        catalog.Set(
            "捕获守护对象历史失败：{1}",
                "Failed to capture monitored-item history: {1}")
        catalog.Set(
            "提示",
                "Notice")
        catalog.Set(
            "⚡️搜索⚡️",
                "⚡️ Search ⚡️")
        catalog.Set(
            "操作计划任务时发生错误！`n`n{1}",
                "An error occurred while operating the scheduled task.`n`n{1}")
        catalog.Set(
            "支持的图标与图片",
                "Supported Icons and Images")
        catalog.Set(
            "支持的程序、脚本与快捷方式",
                "Supported Applications, Scripts, and Shortcuts")
        catalog.Set(
            "支持的程序与脚本",
                "Supported Applications and Scripts")
        catalog.Set(
            "收到显式维护开始命令",
                "Received explicit maintenance-begin command")
        catalog.Set(
            "收到显式维护结束命令，开始执行安全恢复检查：{1}",
                "Received explicit maintenance-end command`; beginning safe-resume checks: {1}")
        catalog.Set(
            "整条展示配置",
                "Complete display configuration")
        catalog.Set(
            "整条记录",
                "Complete record")
        catalog.Set(
            "文件稳定等待（秒）：",
                "File stability wait（seconds）:")
        catalog.Set(
            "新脚本未通过 AutoHotkey 解析检查",
                "The new script did not pass the AutoHotkey parse check")
        catalog.Set(
            "无法从损坏记录中提取",
                "Could not extract data from the damaged record")
        catalog.Set(
            "无法停止进程 PID：{1}{2}",
                "Could not stop process PID {1}{2}")
        catalog.Set(
            "无法写入诊断文件：{1}",
                "Could not write the diagnostic file: {1}")
        catalog.Set(
            "无法启动后台文件扫描：{1}",
                "Could not start the background file scan: {1}")
        catalog.Set(
            "无法启动后台进程快照任务：{1}",
                "Could not start the background process-snapshot task: {1}")
        catalog.Set(
            "无法启动小助手更新安装：{1}",
                "Could not start assistant-update installation: {1}")
        catalog.Set(
            "无法启动小助手更新检查：{1}",
                "Could not start the assistant update check: {1}")
        catalog.Set(
            "无法导出诊断包：`n{1}",
                "Could not export the diagnostic bundle:`n{1}")
        catalog.Set(
            "无法建立单实例运行锁，小助手将退出。",
                "The single-instance lock could not be created. The assistant will exit.")
        catalog.Set(
            "无法开始更新：{1}",
                "Could not begin the update: {1}")
        catalog.Set(
            "无法收集此部分诊断信息：{1}",
                "Could not collect this diagnostic section: {1}")
        catalog.Set(
            "无法检查更新：{1}",
                "Could not check for updates: {1}")
        catalog.Set(
            "无法清理后台扫描临时文件：{1}",
                "Could not remove the background-scan temporary file: {1}")
        catalog.Set(
            "无法清理后台扫描结果文件：{1}",
                "Could not remove the background-scan result file: {1}")
        catalog.Set(
            "无法生成守护对象快照：{1}",
                "Could not create the monitored-item snapshot: {1}")
        catalog.Set(
            "日志",
                "Logs")
        catalog.Set(
            "日志文件不存在：{1}",
                "The log file does not exist: {1}")
        catalog.Set("📄 查看批处理输出日志", "📄 View batch output log")
        catalog.Set("尚未生成批处理输出日志", "No batch output log yet")
        catalog.Set(
            "小助手只有在启动 BAT 或 CMD 守护对象时才会创建此文件。",
                "This file is created only when the assistant launches a BAT or CMD item.")
        catalog.Set("日志保存位置：", "Log file location:")
        catalog.Set("确定", "OK")
        catalog.Set(
            "时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间",
                "One or more time settings are invalid.`n`nExit-detection window: 2-120 seconds`nFile stability wait: 2-300 seconds`nMaximum update wait: 60-86400 seconds and greater than the file stability wait")
        catalog.Set(
            "显式升级维护命令执行异常：{1}",
                "Explicit update-maintenance command failed: {1}")
        catalog.Set(
            "显式升级维护命令未找到监控目标：{1}",
                "The explicit update-maintenance command did not match a monitored target: {1}")
        catalog.Set(
            "显式升级维护命令被忽略，目标未启用升级保护：{1}",
                "The explicit update-maintenance command was ignored because update protection is disabled for the target: {1}")
        catalog.Set(
            "显示主界面",
                "Show Main Window")
        catalog.Set(
            "显示名称：",
                "Display name:")
        catalog.Set(
            "暂停守护：{1}",
                "Monitoring paused: {1}")
        catalog.Set(
            "暂停或恢复选中守护对象，不会退出目标`n支持多选；混合状态时逐项反转`n快捷键：Space",
                "Pause or resume monitoring for the selected items without closing their targets`nSupports multiple selection`; mixed states are toggled individually`nShortcut: Space")
        catalog.Set(
            "暂时无法查询进程状态，稍后重试结束运行：{1}",
                "Process status is temporarily unavailable. Stopping will be retried later: {1}")
        catalog.Set(
            "暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                "Existing processes cannot currently be verified, so launch was delayed to avoid a duplicate instance: {1}")
        catalog.Set(
            "暂时无法结束运行",
                "Stop Temporarily Unavailable")
        catalog.Set(
            "更新助手已启动，小助手即将退出并完成更新。",
                "The update helper has started. The assistant will exit to complete the update.")
        catalog.Set(
            "更新应用搜索结果失败：{1}",
                "Failed to update application search results: {1}")
        catalog.Set(
            "更新检查未返回结果",
                "The update check returned no result")
        catalog.Set(
            "更新检查正在进行，请稍候。",
                "An update check is already in progress. Please wait.")
        catalog.Set(
            "更新检查返回了无法识别的状态：{1}",
                "The update check returned an unrecognized status: {1}")
        catalog.Set(
            "最长升级等待（秒）：",
                "Maximum update wait（seconds）:")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），恢复普通重启流程：{3}",
                "No update activity was found（{1}, {2} seconds）`; resuming the normal restart flow: {3}")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），目标仍不存在：{3}",
                "No update activity was found（{1}, {2} seconds）`; the target is still missing: {3}")
        catalog.Set(
            "未找到目标",
                "No Target Found")
        catalog.Set(
            "未添加",
                "Not Added")
        catalog.Set(
            "未知升级保护阶段",
                "Unknown update-protection phase")
        catalog.Set(
            "未知守护阶段",
                "Unknown monitoring phase")
        catalog.Set(
            "未知版本",
                "Unknown Version")
        catalog.Set(
            "未知解析错误",
                "Unknown parse error")
        catalog.Set(
            "未知错误",
                "Unknown error")
        catalog.Set(
            "查看实时运行日志`n涵盖监控、重启、升级保护与操作记录",
                "View the live runtime log`nIncludes monitoring, restart, update-protection, and user-action records")
        catalog.Set(
            "查看支持类型、操作方法、守护设置`n以及升级保护说明",
                "View supported target types, controls, and monitoring settings`nIncludes update-protection guidance")
        catalog.Set(
            "核心守护",
                "Core monitoring")
        catalog.Set(
            "核心守护计时器启动失败。",
                "The core monitoring timer failed to start.")
        catalog.Set(
            "桌面与开始菜单快捷方式",
                "Desktop and Start Menu Shortcuts")
        catalog.Set(
            "创建成功！",
                "Created!")
        catalog.Set(
            "检查小助手更新",
                "Check for Assistant Updates")
        catalog.Set(
            "检查小助手更新失败：{1}",
                "Failed to check for assistant updates: {1}")
        catalog.Set(
            "检查更新",
                "Check for Updates")
        catalog.Set(
            "检查更新失败：{1}",
                "Update check failed: {1}")
        catalog.Set(
            "检查更新超时",
                "Update Check Timed Out")
        catalog.Set(
            "检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。",
                "A scheduled task with the same name exists, but it was not created by this application. To avoid deleting an unrelated task, handle it in Task Scheduler first.")
        catalog.Set(
            "检测到安装目录变化",
                "Installation-directory change detected")
        catalog.Set(
            "检测到相关安装进程",
                "Related installer process detected")
        catalog.Set(
            "检测到程序文件变化",
                "Program-file change detected")
        catalog.Set(
            "检测到运行中的目标未使用管理员权限：{1}",
                "A running target was detected without administrator privileges: {1}")
        catalog.Set(
            "检测到进程停止，准备重启：{1}（将在 {2} 秒后启动）",
                "Target process stopped`; preparing to restart: {1}（starting in {2} seconds）")
        catalog.Set(
            "正在扫描...",
                "Scanning...")
        catalog.Set(
            "正在扫描文件夹，可点击取消停止",
                "Scanning the folder`; click Cancel to stop")
        catalog.Set(
            "正在扫描：{1}",
                "Scanning: {1}")
        catalog.Set(
            "正在添加扫描结果...",
                "Adding scan results...")
        catalog.Set(
            "正在添加：{1} / {2}",
                "Adding: {1} / {2}")
        catalog.Set(
            "正常关闭超时后允许强制终止",
                "Allow forced termination after the graceful-close timeout")
        catalog.Set(
            "正常关闭超时，已强制终止进程 PID：{1}",
                "Graceful close timed out`; process PID {1} was forcibly terminated.")
        catalog.Set(
            "正常关闭超时，已按设置跳过强制终止 PID：{1}",
                "Graceful close timed out`; forced termination was skipped for PID {1} according to the settings.")
        catalog.Set(
            "没有可安装的应用更新",
                "No Installable Application Update")
        catalog.Set(
            "浏览",
                "Browse")
        catalog.Set(
            "添加扫描结果失败",
                "Failed to add scan results")
        catalog.Set(
            "添加守护对象",
                "Add Monitored Item")
        catalog.Set(
            "添加守护对象失败，已回滚内存状态：{1}",
                "Failed to add the monitored item`; in-memory state was rolled back: {1}")
        catalog.Set(
            "添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放",
                "Add an application, script, or shortcut`nSupports search, folder batch import, and file drag-and-drop")
        catalog.Set(
            "清除记录",
                "Clear Records")
        catalog.Set(
            "状态",
                "Status")
        catalog.Set(
            "独立环境配置 💡`n",
                "Separate environment configuration 💡`n")
        catalog.Set(
            "环境变量",
                "Environment variables")
        catalog.Set(
            "环境变量（每行一个 KEY=VALUE）：",
                "Environment variables（one KEY=VALUE per line）:")
        catalog.Set(
            "用户指定",
                "Specified by user")
        catalog.Set(
            "用户结束了升级等待，重新执行安全启动检查：{1}",
                "The user ended the update wait`; running safe-start checks again: {1}")
        catalog.Set(
            "界面语言和字体已即时更新，无需重新启动小助手。",
                "The interface language and font were updated immediately; the assistant does not need to restart.")
        catalog.Set(
            "更新配置注释语言失败：{1}",
                "Could not update the language of the configuration comments: {1}")
        catalog.Set(
            "；恢复配置失败：{1}",
                "; restoring the configuration also failed: {1}")
        catalog.Set(
            "界面显示设置无法即时应用，已恢复原语言和字体：{1}",
                "The display settings could not be applied immediately. The previous language and font were restored: {1}")
        catalog.Set(
            "无法即时切换界面语言或字体，原显示设置已恢复。`n`n{1}",
                "The interface language or font could not be changed immediately. The previous display settings were restored.`n`n{1}")
        catalog.Set(
            "显示设置应用失败",
                "Could Not Apply Display Settings")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Follow language default（{1}）")
        catalog.Set(
            "正在检查更新…",
                "Checking for updates…")
        catalog.Set(
            "`; UiFont：界面字体；auto 表示使用当前语言的默认字体，也可填写本机已安装字体名称。",
                "`; UiFont: interface font`; auto uses the default font for the current language, or an installed font name may be specified.")
        catalog.Set(
            "界面语言：",
                "Interface language:")
        catalog.Set(
            "界面资源",
                "UI resources")
        catalog.Set("启动", "Startup")
        catalog.Set("监控", "Monitoring")
        catalog.Set(
            "守护对象重复",
                "Duplicate monitored target")
        catalog.Set(
            "监控配置加载异常",
                "Monitoring Configuration Load Error")
        catalog.Set(
            "监控配置加载异常：共 {1} 条记录未能载入。",
                "Monitoring configuration load error: {1} record(s) could not be loaded.")
        catalog.Set(
            "监控配置尚未保存，请查看运行日志。",
                "The monitoring configuration has not been saved. Check the runtime log.")
        catalog.Set(
            "守护对象保存状态无效",
                "The monitored-item save state is invalid")
        catalog.Set(
            "守护对象注册回调无效",
                "The monitored-item registration callback is invalid")
        catalog.Set(
            "守护对象路径无效：{1}",
                "Invalid monitored-item path: {1}")
        catalog.Set(
            "监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核：{1}",
                "The target file no longer exists. Monitoring entered the missing-file state and will recheck automatically when the file returns: {1}")
        catalog.Set(
            "目标任务需要 WatchdogScheduler",
                "Target tasks require a WatchdogScheduler")
        catalog.Set(
            "目标文件已恢复，重新核对运行状态：{1}",
                "The target file has returned`; checking its running state again: {1}")
        catalog.Set(
            "目标文件缺失时检测到升级活动",
                "Update activity detected while the target file was missing")
        catalog.Set(
            "目标程序文件不存在",
                "The target program file does not exist")
        catalog.Set(
            "目标程序：{1}",
                "Target application: {1}")
        catalog.Set(
            "目标路径",
                "Target path")
        catalog.Set(
            "目标退出时检测到升级信号",
                "Update signal detected when the target exited")
        catalog.Set(
            "真实目标来源标记",
                "Real-target source flag")
        catalog.Set(
            "真实进程路径无效",
                "The real-process path is invalid")
        catalog.Set(
            "确 定",
                "OK")
        catalog.Set(
            "程序文件刚刚发生变化",
                "The program file changed recently")
        catalog.Set(
            "程序文件尚未达到稳定等待时间",
                "The program file has not yet remained stable for the required time")
        catalog.Set(
            "程序文件正在写入或结构不完整",
                "The program file is still being written or is structurally incomplete")
        catalog.Set(
            "稍后",
                "Later")
        catalog.Set(
            "窗口层级平台适配器无效",
                "The window-hierarchy platform adapter is invalid")
        catalog.Set(
            "窗口层级管理器无效",
                "The window-hierarchy manager is invalid")
        catalog.Set(
            "窗口布局字段不是整数：{1}",
                "Window-layout field is not an integer: {1}")
        catalog.Set(
            "窗口布局字段超出范围：{1}",
                "Window-layout field is outside the allowed range: {1}")
        catalog.Set(
            "窗口布局对象无效",
                "The window-layout object is invalid")
        catalog.Set(
            "立即更新",
                "Update Now")
        catalog.Set(
            "等待 {1} 秒后进行第 {2} 次尝试...",
                "Waiting {1} seconds before attempt {2}...")
        catalog.Set(
            "管理员运行状态",
                "Run-as-administrator state")
        catalog.Set(
            "系统 PowerShell 不可用",
                "System PowerShell is unavailable")
        catalog.Set(
            "系统压缩工具未能创建诊断包",
                "The system compression utility could not create the diagnostic bundle")
        catalog.Set(
            "系统权限拦截",
                "Administrator Privileges Required")
        catalog.Set(
            "通用",
                "General")
        catalog.Set(
            "显示",
                "Display")
        catalog.Set(
            "结束升级等待并恢复守护",
                "End Update Wait and Resume Monitoring")
        catalog.Set(
            "编码损坏",
                "The encoded value is damaged")
        catalog.Set(
            "缺少窗口布局字段：{1}",
                "Missing window-layout field: {1}")
        catalog.Set(
            "缺少窗口生命周期回调：{1}",
                "Missing window-lifecycle callback: {1}")
        catalog.Set(
            "缺少诊断信息提供器：{1}",
                "Missing diagnostic-information provider: {1}")
        catalog.Set(
            "缺少运行参数：{1}",
                "Missing runtime setting: {1}")
        catalog.Set(
            "自动",
                "Automatic")
        catalog.Set(
            "自动识别升级并保护启动过程",
                "Automatically detect updates and protect startup")
        catalog.Set(
            "自动识别进程",
                "Detect process automatically")
        catalog.Set(
            "自定义名称",
                "Custom name")
        catalog.Set(
            "自定义图标",
                "Custom icon")
        catalog.Set(
            "计划任务冲突",
                "Scheduled Task Conflict")
        catalog.Set(
            "计划任务操作失败：{1}",
                "Scheduled task operation failed: {1}")
        catalog.Set(
            "设置已更新：轮询={1}ms，序列=[{2}]，日志上限={3}",
                "Settings updated: polling={1}ms, sequence=[{2}], log limit={3}")
        catalog.Set(
            "设置无效",
                "Invalid Settings")
        catalog.Set(
            "诊断临时目录已存在",
                "The diagnostic temporary directory already exists")
        catalog.Set(
            "诊断包保存目录不存在",
                "The diagnostic bundle destination directory does not exist")
        catalog.Set(
            "诊断包已导出到：`n{1}",
                "Diagnostic bundle exported to:`n{1}")
        catalog.Set(
            "诊断包目标文件名已被占用",
                "The diagnostic bundle's target file name is already in use")
        catalog.Set(
            "诊断压缩包未生成",
                "The diagnostic archive was not created")
        catalog.Set(
            "该文件不是受支持的图标或图片格式。`n`n支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。",
                "This file is not a supported icon or image format.`n`nSupported formats: ICO, EXE, DLL, CPL, LNK, PNG, JPG, JPEG, JPE, JFIF, BMP, GIF, TIF, TIFF, WebP, SVG, and ANI.")
        catalog.Set(
            "该目标已存在、无效或指向目录。",
                "The target already exists, is invalid, or points to a directory.")
        catalog.Set(
            "该真实进程已由其他守护对象守护。",
                "Another monitored item already monitors this real process.")
        catalog.Set(
            "该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再结束运行。",
                "Update protection is active for this application. Wait for the update to finish, or end the wait in Update Protection before stopping it.")
        catalog.Set(
            "语义版本无效",
                "The semantic version is invalid")
        catalog.Set(
            "请通过上方按钮搜索或选择，或在下方填写进程名或目标路径：`n【支持程序、脚本、快捷方式，以及文件夹批量导入】",
                "Search or browse with the buttons above.`nAlternatively, enter a process name or target path below.`n【Supports programs, scripts, shortcuts, and folder batch import.】")
        catalog.Set(
            "请选择现有且可执行的真实程序或脚本路径。",
                "Select an existing, executable application or script as the real target.")
        catalog.Set(
            "请选择现有的图标、程序、资源库或快捷方式文件。",
                "Select an existing icon, application, resource library, or shortcut file.")
        catalog.Set(
            "读取后台扫描结果失败",
                "Failed to read the background-scan result")
        catalog.Set(
            "调度器已停止",
                "The scheduler has stopped")
        catalog.Set(
            "跟随系统",
                "Follow System")
        catalog.Set(
            "路径",
                "Path")
        catalog.Set(
            "轮询间隔必须为 500-86400000 毫秒的正整数！",
                "The polling interval must be a positive integer from 500 to 86400000 milliseconds.")
        catalog.Set(
            "软件升级保护",
                "Update Protection")
        catalog.Set(
            "软件升级保护超过最长等待时间，需要用户确认后恢复：{1}",
                "Update protection exceeded its maximum wait and requires user confirmation before resuming: {1}")
        catalog.Set(
            "软件升级完成，准备恢复启动：{1}",
                "Application update complete`; preparing to resume launch: {1}")
        catalog.Set(
            "软件升级完成，已恢复正常守护：{1}",
                "Application update complete`; normal monitoring resumed: {1}")
        catalog.Set(
            "载入中...",
                "Loading...")
        catalog.Set(
            "运行参数不是支持的界面语言：{1}",
                "Runtime setting is not a supported interface language: {1}")
        catalog.Set(
            "运行参数不是整数：{1}",
                "Runtime setting is not an integer: {1}")
        catalog.Set(
            "运行参数不能为空：{1}",
                "Runtime setting cannot be empty: {1}")
        catalog.Set(
            "运行参数对象无效",
                "The runtime-settings object is invalid")
        catalog.Set(
            "运行参数超出范围：{1}",
                "Runtime setting is outside the allowed range: {1}")
        catalog.Set(
            "运行日志",
                "Runtime Log")
        catalog.Set(
            "进程仍在运行，忽略重复启动：{1}",
                "Process is still running`; duplicate launch ignored: {1}")
        catalog.Set(
            "进程启动后迅速退出或未成功常驻后台",
                "The process exited soon after launch or did not remain running in the background")
        catalog.Set(
            "进程守护小助手",
                "Process Watchdog Assistant")
        catalog.Set(
            "持续守护重要程序与自动化任务，让日常工作稳定运行",
                "Keep essential apps and automations running reliably, day after day")
        catalog.Set(
            "进程守护小助手 - 开机自启守护程序",
                "Process Watchdog Assistant - Scheduled Startup Monitor")
        catalog.Set(
            "进程守护小助手已静默启动。",
                "Process Watchdog Assistant started silently.")
        catalog.Set(
            "退出检测窗口（秒）：",
                "Exit-detection window（seconds）:")
        catalog.Set(
            "退出清理异常（{1}）：{2}",
                "Shutdown cleanup error（{1}）: {2}")
        catalog.Set(
            "退出程序",
                "Exit")
        catalog.Set(
            "选择主窗口图标",
                "Select Main Window Icon")
        catalog.Set(
            "选择工作目录",
                "Select Working Directory")
        catalog.Set(
            "选择快捷方式对应的真实进程",
                "Select the Real Process for the Shortcut")
        catalog.Set(
            "选择批处理日志目录",
                "Select Batch-output Log Directory")
        catalog.Set(
            "选择文件",
                "Select File")
        catalog.Set(
            "选择文件夹",
                "Select Folder")
        catalog.Set(
            "选择要监控的文件",
                "Select a File to Monitor")
        catalog.Set(
            "选择要监控的文件夹",
                "Select a Folder to Monitor")
        catalog.Set(
            "选择诊断包保存位置",
                "Select Diagnostic Bundle Destination")
        catalog.Set(
            "选择软件安装目录",
                "Select Application Installation Directory")
        catalog.Set(
            "通过拖拽添加了 {1} 个守护对象。",
                "Added {1} monitored item(s) by drag-and-drop.")
        catalog.Set(
            "配置仓储无效",
                "The configuration repository is invalid")
        catalog.Set(
            "配置写入器无效",
                "The configuration writer is invalid")
        catalog.Set(
            "配置文件写入事务正在进行",
                "A configuration-file write transaction is already in progress")
        catalog.Set(
            "重新加载",
                "Reload")
        catalog.Set(
            "重新加载失败",
                "Reload Failed")
        catalog.Set(
            "重新加载失败，已保留当前实例：{1}",
                "Reload failed`; the current instance was kept running: {1}")
        catalog.Set(
            "重新加载失败，当前守护仍在运行。`n`n{1}",
                "Reload failed. Monitoring remains active in the current instance.`n`n{1}")
        catalog.Set(
            "重试序列不能为空！",
                "The retry sequence cannot be empty.")
        catalog.Set(
            "重试序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "The retry-sequence format is invalid. Enter comma-separated positive integers（for example: 1,10,60）, each from 1 to 86400 seconds.")
        catalog.Set(
            "重试延迟序列不能为空",
                "The retry delay sequence cannot be empty")
        catalog.Set(
            "重试延迟序列无效",
                "The retry delay sequence is invalid")
        catalog.Set(
            "错误",
                "Error")
        catalog.Set(
            "名称：{1}`n真实路径：{2}",
                "Name: {1}`nReal path: {2}")
        catalog.Set(
            "🌿 环境变量：{1} 项`n",
                "🌿 Environment variables: {1}`n")
        catalog.Set(
            "🎨 自定义名称和图标",
                "🎨 Customize Name and Icon")
        catalog.Set(
            "📁 工作目录：{1}`n",
                "📁 Working directory: {1}`n")
        catalog.Set(
            "📂 打开所在位置",
                "📂 Open File Location")
        catalog.Set(
            "📂 浏览文件夹...",
                "📂 Browse for Folder...")
        catalog.Set(
            "选择...",
                "Select...")
        catalog.Set(
            "📄 查看运行日志",
                "📄 View Runtime Log")
        catalog.Set(
            "📄 浏览文件...",
                "📄 Browse for File...")
        catalog.Set(
            "🔄 反转状态",
                "🔄 Toggle States")
        catalog.Set(
            "🔄 恢复升级保护状态",
                "🔄 Restore Update-protection State")
        catalog.Set(
            "🔄 显式升级维护中",
                "🔄 Explicit Update Maintenance")
        catalog.Set(
            "🔄 检查",
                "🔄 Check")
        catalog.Set(
            "🔄 等待程序文件可用",
                "🔄 Waiting for Program File to Become Available")
        catalog.Set(
            "🔄 等待程序文件恢复",
                "🔄 Waiting for Program File to Return")
        catalog.Set(
            "🔄 软件升级中",
                "🔄 Application Updating")
        catalog.Set(
            "🔄 软件升级保护",
                "🔄 Update Protection")
        catalog.Set(
            "⏹️ 结束运行",
                "⏹️ Stop Target")
        catalog.Set(
            "搜索...",
                "Search...")
        catalog.Set(
            "搜索：",
                "Search:")
        catalog.Set(
            "扩展名",
                "Extension")
        catalog.Set(
            "🗑️ 删除",
                "🗑️ Delete")
        catalog.Set(
            "🚀 正在启动...",
                "🚀 Starting...")
        catalog.Set(
            "🛡️ 以管理员身份运行",
                "🛡️ Run as Administrator")
        catalog.Set(
            "（{1}）",
                "（{1}）")
        catalog.Set(
            "（第 {1} 行）",
                "（line {1}）")
        catalog.Set(
            "（管理员权限）",
                "（administrator privileges）")
        catalog.Set(
            "：{1}",
                ": {1}")
        catalog.Set(
            "Everything 搜索不可用，请确认 Everything 正在运行。",
                "Everything search is unavailable. Make sure Everything is running.")
        catalog.Set(
            "正在载入 Everything 搜索结果：{1}／{2}",
                "Loading Everything search results: {1}/{2}")
        catalog.Set(
            "Everything 搜索结果：{1} 项",
                "Everything search results: {1} items")
        catalog.Set(
            "{1}（EXE 版）",
                "{1}（EXE edition）")
        catalog.Set(
            "{1}（源码版）",
                "{1}（source edition）")
        catalog.Set(
            "• “结束运行”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。",
                "• “Stop Target” first asks the target to exit normally. If the timeout expires, the option under “Stop Policy” determines whether it is forcibly terminated.")
        catalog.Set(
            "• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。",
                "• About: view the application version and AutoHotkey runtime, check for updates manually, or open the open-source project.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。",
                "• After detecting that a target has stopped, the assistant confirms its status, then retries according to the “Automatic restart delay sequence after crash”. Later delays are used after repeated failures to prevent rapid restart loops.")
        catalog.Set(
            "• 界面语言和内容字体保存后会立即更新主窗口、菜单和托盘，无需重新启动。",
                "• Saving the interface language or content font immediately updates the main window, menus, and tray without restarting.")
        catalog.Set(
            "• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。",
                "• Logs: set the runtime log display limit, batch-output log path, retention period, and cleanup behavior at startup.")
        catalog.Set(
            "• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。",
                "• Stop Policy: set shutdown timeouts for GUI and CLI applications and choose whether force termination is allowed after a normal shutdown times out.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时是否显示主窗口，以及界面语言和内容字体。",
                "• General: create desktop and Start menu shortcuts, enable or disable scheduled startup, choose whether to show the main window at startup, and set the interface language and content font.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“关于”页会分别显示当前小助手版本、运行形态和实际运行时版本。",
                "• The assistant version and AutoHotkey version are independent. The “About” page shows the current assistant version, distribution type, and actual runtime version separately.")
        catalog.Set(
            "CLI 程序关闭超时（秒）：",
                "CLI application shutdown timeout（seconds）:")
        catalog.Set(
            "GUI 程序关闭超时（秒）：",
                "GUI application shutdown timeout（seconds）:")
        catalog.Set(
            "崩溃自动重启延迟序列（秒）：",
                "Automatic restart delay sequence after crash（seconds）:")
        catalog.Set(
            "崩溃自动重启延迟序列不能为空！",
                "The automatic restart delay sequence after a crash cannot be empty!")
        catalog.Set(
            "崩溃自动重启延迟序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "Invalid automatic restart delay sequence after crash! Enter comma-separated positive integers（for example: 1,10,60）, each from 1 to 86400 seconds.")
        catalog.Set(
            "当前版本：",
                "Current version:")
        catalog.Set(
            "导入文件夹时包含子目录",
                "Include subfolders when importing a folder")
        catalog.Set(
            "开源地址",
                "Open-source project")
        catalog.Set(
            "关于",
                "About")
        catalog.Set(
            "界面内容字体：",
                "Interface content font:")
        catalog.Set(
            "进程状态检查间隔（毫秒）：",
                "Process status check interval（milliseconds）:")
        catalog.Set(
            "进程状态检查间隔必须为 500-86400000 毫秒的正整数！",
                "The process status check interval must be a positive integer from 500 to 86400000 milliseconds!")
        catalog.Set(
            "扩展设置包含无效数值。`n`nGUI 程序关闭超时：1-300 秒`nCLI 程序关闭超时：1-60 秒`n运行日志显示上限：50-10000 条`n批处理日志保留天数：1-3650 天",
                "Some advanced settings contain invalid values.`n`nGUI application shutdown timeout: 1-300 seconds`nCLI application shutdown timeout: 1-60 seconds`nRuntime log display limit: 50-10000 entries`nBatch-output log retention: 1-3650 days")
        catalog.Set(
            "配置显示、启动、监控、停止策略与日志",
                "Configure Display, Startup, Monitoring, Stop Policy, and Logs")
        catalog.Set(
            "批处理日志保存路径：",
                "Batch-output log save path:")
        catalog.Set(
            "批处理日志保留天数：",
                "Batch-output log retention（days）:")
        catalog.Set(
            "启动时显示主窗口",
                "Show the main window at startup")
        catalog.Set(
            "设置已更新：进程检查间隔={1}ms，重启延迟序列=[{2}]，日志显示上限={3}",
                "Settings updated: process check interval={1} ms, restart delay sequence=[{2}], log display limit={3}")
        catalog.Set(
            "停止策略",
                "Stop Policy")
        catalog.Set(
            "运行环境：",
                "Runtime:")
        catalog.Set(
            "运行日志显示上限（条）：",
                "Runtime log display limit（entries）:")
        catalog.Set(
            "; Theme：界面主题；auto 表示跟随 Windows 系统，light 表示浅色，dark 表示深色。",
                "; Theme: interface theme`; auto follows the Windows system, light selects the light theme, and dark selects the dark theme.")
        catalog.Set(
            "主题：",
                "Theme:")
        catalog.Set(
            "浅色",
                "Light")
        catalog.Set(
            "深色",
                "Dark")
        catalog.Set(
            "运行参数不是支持的界面主题：{1}",
                "The runtime setting is not a supported interface theme: {1}")
        catalog.Set(
            "界面显示设置无法即时应用，已恢复原语言、字体和主题：{1}",
                "The display settings could not be applied immediately; the previous language, font, and theme were restored: {1}")
        catalog.Set(
            "无法即时切换界面语言、字体或主题，原显示设置已恢复。`n`n{1}",
                "The interface language, font, or theme could not be switched immediately. The previous display settings were restored.`n`n{1}")
        catalog.Set(
            "界面语言、字体和主题已即时更新，无需重新启动小助手。",
                "The interface language, font, and theme were updated immediately; restarting the assistant is not required.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。",
                "• General: create desktop and Start menu shortcuts, enable or disable scheduled startup, choose whether to show the main window and check for assistant updates at startup, and set the interface language, content font, and theme.")
        catalog.Set(
            "• 显示：界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。",
                "• Display: saving the interface language, content font, or theme immediately updates the main window, menus, and tray without restarting.")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Open Help`nChoose the user guide, runtime log, or feedback page")
        catalog.Set("快揭不开锅了（≥Д≤）", "The budget's almost gone（≥Д≤）")
        catalog.Set("帮助", "Help")
        catalog.Set("提交反馈", "Submit Feedback")
        catalog.Set("支持开源项目", "Support the Open-Source Project")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式：", "If the assistant has saved you time diagnosing problems and getting programs running again, please consider supporting the author through one of the QR codes below!`nChoose how you'd like to help:")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "QR code image not found")
        catalog.Set("• 主界面的“帮助”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。", "• Open Help from the main window to view the user guide, this session's runtime log, or the project feedback page. The log includes monitoring, restarts, update protection, and user actions, and updates automatically.")
        catalog.Set("⚙️ 进程识别与启动设置", "⚙️ Process Identification and Launch Settings")
        catalog.Set("进程识别与启动设置", "Process Identification and Launch Settings")
        catalog.Set("进程识别", "Process identification")
        catalog.Set("启动环境", "Launch environment")
        catalog.Set("快捷方式仍用于启动；真实进程用于判断程序是否正在运行。", "The shortcut remains the launch entry; the actual process is used to determine whether the application is running.")
        catalog.Set("该守护对象直接启动并监控同一个目标，无需额外识别真实进程。", "This item launches and monitors the same target directly, so no separate process identification is needed.")
        catalog.Set("用于判断运行状态的真实进程：", "Actual process used for status detection:")
        catalog.Set("用于判断运行状态的目标：", "Target used for status detection:")
        catalog.Set("重新识别", "Detect Again")
        catalog.Set("选择程序", "Choose Program")
        catalog.Set("识别依据：{1}", "Detection source: {1}")
        catalog.Set("识别依据：暂无可靠结果", "Detection source: no reliable result")
        catalog.Set("识别状态：路径有效。", "Detection status: the path is valid.")
        catalog.Set("识别状态：路径暂时不可用，已保留上次可靠结果。", "Detection status: the path is temporarily unavailable; the last reliable result has been retained.")
        catalog.Set("识别状态：路径暂时不可用，将保留此身份等待恢复。", "Detection status: the path is temporarily unavailable; this identity will be retained while recovery is awaited.")
        catalog.Set("识别状态：未找到可靠目标，请改为手动指定。", "Detection status: no reliable target was found. Specify one manually.")
        catalog.Set("识别状态：手动指定，保存时将验证路径。", "Detection status: specified manually; the path will be validated when saved.")
        catalog.Set("识别状态：启动入口与监控目标一致。", "Detection status: the launch entry and monitored target are the same.")
        catalog.Set("这些设置仅在小助手下次启动目标时生效，不会重启当前进程。", "These settings take effect the next time the assistant launches the target. They do not restart the currently running process.")
        catalog.Set("留空时使用快捷方式工作目录或程序所在目录。", "Leave blank to use the shortcut's working directory or the application's directory.")
        catalog.Set("留空时不附加额外参数。", "Leave blank to add no extra arguments.")
        catalog.Set("留空时继承小助手当前环境。", "Leave blank to inherit the assistant's current environment.")
        catalog.Set("工作目录不存在或不可访问：{1}", "The working directory does not exist or cannot be accessed: {1}")
        catalog.Set("工作目录无效", "Invalid Working Directory")
        catalog.Set("环境变量第 {1} 行缺少等号（KEY=VALUE）。", "Environment-variable line {1} is missing an equals sign（KEY=VALUE）.")
        catalog.Set("环境变量第 {1} 行的名称无效：{2}", "Environment-variable line {1} has an invalid name: {2}")
        catalog.Set("环境变量第 {1} 行重复定义了 {2}。", "Environment-variable line {1} defines {2} more than once.")
        catalog.Set("环境变量配置无法解析。", "The environment-variable configuration could not be parsed.")
        catalog.Set("环境变量配置无效", "Invalid Environment Variables")
        catalog.Set("设置已应用到当前运行，但暂未写入配置文件；小助手将在后台自动重试。", "The settings are active for this session but have not yet been written to the configuration file. The assistant will retry automatically in the background.")
        catalog.Set("配置暂未写入", "Configuration Not Yet Written")
        catalog.Set("已更新进程识别与启动设置：{1}", "Process identification and launch settings updated: {1}")
        catalog.Set("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。", "• Shortcuts: LNK, URL, and APPREF-MS, including MSI shortcuts whose actual target can be resolved. For special shortcuts, specify the actual process manually under Process Identification and Launch Settings.")
        catalog.Set("• 右键守护对象可自定义主窗口名称和图标，也可打开所在位置、结束运行、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。“结束运行”会同时暂停守护，目标不会被自动重新启动；要求管理员运行但当前权限不符时仍会显示警告。", "• Right-click an item to customize its main-window name and icon, open its location, stop the target, edit its path, toggle administrator launch, configure process identification, launch settings, and update protection, or view redirected batch-output logs. Stop Target also pauses monitoring, so the target is not started again automatically; a privilege mismatch still shows a warning.")
        catalog.Set("添加", "Add")
        catalog.Set("暂停", "Pause")
        catalog.Set("恢复", "Resume")
        catalog.Set("删除", "Delete")
        catalog.Set("设置", "Settings")
        catalog.Set("打赏", "Donate")
        catalog.Set("保存", "Save")
        catalog.Set("取消", "Cancel")
        catalog.Set("反转状态", "Toggle States")
        catalog.Set("统计：运行", "Running")
        catalog.Set("统计：停止", "Stopped")
        catalog.Set("统计：恢复", "Recovering")
        catalog.Set("统计：升级", "Updating")
        catalog.Set("统计：暂停", "Paused")
        catalog.Set("统计：失效", "Invalid")
        catalog.Set("统计：总计", "Total")
        catalog.Set("配置未保存", "Configuration not saved")
        catalog.Set("创建", "Create")
        catalog.Set("开启", "Enable")
        catalog.Set("关闭", "Disable")
        catalog.Set("切换", "Toggle")
        catalog.Set("冲突", "Conflict")
        catalog.Set("浏览", "Browse")
        catalog.Set("监控配置", "Watchlist configuration")
        catalog.Set("管理员运行状态", "Run as administrator")
        catalog.Set("调整守护顺序", "Reorder watchlist")
        catalog.Set("编辑完整路径", "Edit full path")
        catalog.Set("自定义名称和图标", "Customize name and icon")
        catalog.Set("已撤销：{1}", "Undone: {1}")
        catalog.Set("已重做：{1}", "Redone: {1}")
        catalog.Set("Everything 搜索暂时不可用，请稍后重试。",
            "Everything search is temporarily unavailable. Try again shortly.")
        catalog.Set("Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。",
            "The Everything search component is missing or could not be loaded. Fully extract or reinstall the assistant.")
        catalog.Set("已找到 Everything，但无法后台启动，请手动启动后重试。",
            "Everything was found but could not be started in the background. Start it manually and try again.")
        catalog.Set("后台启动 Everything 失败：{1}",
            "Failed to start Everything in the background: {1}")
        catalog.Set("正在后台启动 Everything 并等待搜索服务就绪...",
            "Starting Everything in the background and waiting for its search service...")
        catalog.Set("已在后台启动 Everything：{1}",
            "Started Everything in the background: {1}")
        catalog.Set("等待 Everything 搜索服务就绪超时：{1}",
            "Timed out waiting for the Everything search service: {1}")
        catalog.Set("未找到 Everything，点击前往官网下载最新版：{1}",
            "Everything was not found. Click to download the latest version from the official site: {1}")
        catalog.Set("本机未找到 Everything；程序搜索需要 Everything 后台服务。",
            "Everything was not found on this computer; program search requires the Everything background service.")
        catalog.Set("• 程序搜索：使用 Everything 服务并显示全部匹配结果；未运行时会尝试在本机查找并后台启动，未找到时提供官网最新版下载地址。",
            "• Program search: uses the Everything service and displays every match. If Everything is not running, the assistant looks for it on this computer and starts it in the background; if it is not found, an official download link is provided.")
        catalog.Set("• 小助手随包的 Everything64.dll 只是连接 Everything 后台实例的 SDK 客户端，不负责扫描磁盘或建立索引，不能替代 Everything 本体。",
            "• The bundled Everything64.dll is only an SDK client that connects to the Everything background instance. It does not scan disks or build an index and cannot replace Everything itself.")
        catalog.Set("六、进程识别与启动设置",
            "6. Process Identification and Launch Settings")
        catalog.Set("• 此设置只作用于当前守护对象，并将“用什么启动”和“用什么判断正在运行”分开处理。启动环境只在小助手下次启动目标时生效，不会重启当前进程。",
            "• These settings apply only to the current watched item and treat what to launch separately from what proves it is running. The launch environment takes effect only the next time the assistant starts the target and does not restart the current process.")
        catalog.Set("• 直接添加程序或脚本时，启动入口与监控目标相同；EXE 按完整路径识别，脚本按宿主进程命令行中的脚本路径识别。",
            "• When an application or script is added directly, the launch entry and monitored target are the same. EXE files are identified by full path; scripts are identified by the script path in the host process command line.")
        catalog.Set("• 添加 LNK 快捷方式时，快捷方式始终作为启动入口；自动识别出的真实程序或脚本只用于判断运行状态。",
            "• When an LNK shortcut is added, the shortcut always remains the launch entry. The automatically resolved application or script is used only to determine whether the target is running.")
        catalog.Set("• 自动识别会综合快捷方式目标、参数、Windows Installer 信息、安装目录、文件版本信息和已观察进程；证据不唯一时不会随意绑定。",
            "• Automatic identification combines the shortcut target and arguments, Windows Installer data, installation directory, file-version information, and observed processes. It does not bind a target when the evidence is ambiguous.")
        catalog.Set("• 自动结果不正确时改用“用户指定”，选择程序正常运行期间持续存在的主程序或脚本；不要选择启动器、更新器或短暂子进程。",
            "• If the automatic result is wrong, choose User-specified and select the main application or script that remains present while the application is normally running. Do not select a launcher, updater, or short-lived child process.")
        catalog.Set("启动程序或解释器：", "Launcher or interpreter:")
        catalog.Set("留空时按目标类型自动启动；可选择 Python、AutoHotkey、PowerShell、Node.js、Java 等运行时。", "Leave blank to launch according to the target type, or select a runtime such as Python, AutoHotkey, PowerShell, Node.js, or Java.")
        catalog.Set("启动程序参数：", "Launcher arguments:")
        catalog.Set("参数顺序为：启动程序参数、目标路径、目标参数；例如 Java 使用 -jar。", "The order is launcher arguments, target path, then target arguments. For example, use -jar with Java.")
        catalog.Set("目标参数（Args）：", "Target arguments（Args）:")
        catalog.Set("留空时继承小助手当前环境；值中可用 %变量名% 引用已有环境变量。", "Leave blank to inherit the assistant's current environment. Use %VARIABLE% in a value to reference an existing environment variable.")
        catalog.Set("选择启动程序或解释器", "Choose a Launcher or Interpreter")
        catalog.Set("可执行程序", "Executable Programs")
        catalog.Set("请先选择启动程序或解释器，再填写它的参数。", "Choose a launcher or interpreter before entering its arguments.")
        catalog.Set("启动程序未设置", "Launcher Not Set")
        catalog.Set("启动程序或解释器不存在：{1}", "The launcher or interpreter does not exist: {1}")
        catalog.Set("启动程序无效", "Invalid Launcher")
        catalog.Set("整条启动配置", "entire launch configuration")
        catalog.Set("启动程序或解释器", "launcher or interpreter")
        catalog.Set("解释器参数", "interpreter arguments")
        catalog.Set("• 直接脚本可指定“启动程序或解释器”，选择实际执行脚本的可执行文件，例如 Python、AutoHotkey、PowerShell、Node.js、Ruby、Perl、PHP、Lua、Java 或 Bash；留空时沿用系统默认启动方式。", "• For a directly added script, Launcher or interpreter lets you select the executable that actually runs it, such as Python, AutoHotkey, PowerShell, Node.js, Ruby, Perl, PHP, Lua, Java, or Bash. Leave it blank to use the system's default launch method.")
        catalog.Set("• “启动程序参数”位于目标路径之前，“目标参数（Args）”位于目标路径之后。Java 可填写 -jar；PowerShell 可填写 -NoProfile -ExecutionPolicy Bypass -File。", "• Launcher arguments are placed before the target path; Target arguments（Args）are placed after it. For Java, use -jar. For PowerShell, you can use -NoProfile -ExecutionPolicy Bypass -File.")
        catalog.Set("• Python 虚拟环境请选择该环境的 Scripts\python.exe；其他语言也可选择项目要求的确切运行时版本。进程识别仍以目标脚本路径为准，不会误把解释器本身当成守护目标。", "• For a Python virtual environment, select its Scripts\python.exe. Other languages can likewise use the exact runtime version required by the project. Process identification still uses the target script path, so the interpreter itself is not mistaken for the watched target.")
        catalog.Set("• 工作目录（CWD）用于解析相对路径；留空时使用快捷方式工作目录或目标所在目录。", "• The working directory（CWD）resolves relative paths. When left blank, the shortcut's working directory or the target's directory is used.")
        catalog.Set("• 环境变量每行填写一个 KEY=VALUE，只覆盖列出的变量；值中可用 %变量名% 引用已有环境变量。启动完成后小助手会恢复自身环境。", "• Enter one KEY=VALUE environment variable per line. Only the listed variables are overridden, and %VARIABLE% can reference an existing value. The assistant restores its own environment after launching.")
        catalog.Set("; AppN 与 [Apps] 中同名的守护对象一一对应，依次保存启动程序或解释器路径及其参数。", "; Each AppN entry corresponds to the watched target with the same name in [Apps] and stores the launcher or interpreter path followed by its arguments.")
        catalog.Set("; 两个字段均为 <HEX> 编码；留空时由小助手按目标类型使用默认启动方式。", "; Both fields use <HEX> encoding. When empty, the assistant uses the default launch method for the target type.")
        catalog.Set("守护对象不能指向文件夹：{1}", "A monitored item cannot point to a folder: {1}")
        catalog.Set("自动识别目标新位置", "Identify the target's new location automatically")
        catalog.Set("检测到的目标新位置已失效，请重新操作。", "The detected new target location is no longer valid. Please try again.")
        catalog.Set("已更新已更名的守护目标：{1} -> {2}", "Updated the renamed monitored target: {1} -> {2}")
        catalog.Set("守护目标内容迁移识别服务未能启动。", "The monitored-target content relocation detection service could not be started.")
        catalog.Set("检测到守护目标可能已更名，等待用户确认：{1} -> {2}", "A monitored target may have been renamed`; awaiting confirmation: {1} -> {2}")
        catalog.Set("确认窗口暂时无法显示，将稍后重试", "The confirmation window is temporarily unavailable. It will be retried shortly.")
        catalog.Set("发现多个内容完全相同的迁移候选，已暂停自动迁移：{1}", "Multiple relocation candidates with identical content were found`; automatic relocation is paused: {1}")
        catalog.Set("无法执行内容迁移：缺少旧文件的完整内容指纹：{1}",
            "Content relocation cannot run because the previous file has no complete content fingerprint: {1}")
        catalog.Set("监测到目标文件缺失，内容迁移将在缺失状态稳定后开始扫描：{1}",
            "The target file is missing; content relocation will start scanning after the missing state is stable: {1}")
        catalog.Set("内容迁移暂缓：目标正处于升级保护、维护恢复或近期启动信号保护中：{1}",
            "Content relocation is paused because the target is under update protection, maintenance recovery, or recent launch-signal protection: {1}")
        catalog.Set("内容迁移候选已被拒绝：{1} -> {2}（候选不存在、扩展名不兼容、已被守护或与现有目标冲突）",
            "The content relocation candidate was rejected: {1} -> {2} (candidate missing, incompatible extension, already monitored, or conflicting with an existing target)")
        catalog.Set("内容迁移候选仍在本次忽略冷却期内：{1} -> {2}",
            "The content relocation candidate is still in this ignore cooldown: {1} -> {2}")
        catalog.Set("后台扫描失败或超时",
            "The background scan failed or timed out")
        catalog.Set("扫描未能在时限内完整核对",
            "The scan could not complete verification within the time limit")
        catalog.Set("内容迁移扫描未完成，将稍后重试：{1}（搜索根：{2}；原因：{3}）",
            "Content relocation scan did not complete and will retry later: {1} (search root: {2}; reason: {3})")
        catalog.Set("发现多个内容完全相同的迁移候选，已暂停自动迁移：{1}（候选：{2}）",
            "Multiple relocation candidates with identical content were found; automatic relocation is paused: {1} (candidates: {2})")
        catalog.Set("正在扫描内容迁移候选：{1}（搜索根：{2}；方式：{3}）",
            "Scanning for content relocation candidates: {1} (search root: {2}; method: {3})")
        catalog.Set("Everything 索引预筛选",
            "Everything index prefilter")
        catalog.Set("直接递归扫描",
            "direct recursive scan")
        catalog.Set("无法启动内容迁移扫描，已尝试下一个搜索根：{1}（搜索根：{2}；方式：{3}）",
            "Could not start the content relocation scan; trying the next search root: {1} (search root: {2}; method: {3})")
        catalog.Set("尚未找到内容完全一致的迁移候选，将稍后重试：{1}（已按扩展名、大小和 SHA-256 完整内容指纹核对）",
            "No relocation candidate with identical content has been found yet; will retry later: {1} (checked by extension, size, and full SHA-256 content fingerprint)")
        catalog.Set("未知", "Unknown")
        catalog.Set("无", "None")
        catalog.Set("，另有 {1} 个", ", plus {1} more")
        catalog.Set("检测到内容一致的守护目标新位置，等待用户确认：{1} -> {2}", "A new location with matching content was detected`; awaiting confirmation: {1} -> {2}")
        catalog.Set("守护目标内容迁移识别异常：{1}", "Monitored-target content relocation detection error: {1}")
        catalog.Set("等待确认目标新位置", "Waiting to confirm the target's new location")
        catalog.Set("确认目标新位置", "Confirm New Target Location")
        catalog.Set("检测到守护目标可能已更名", "A monitored target may have been renamed")
        catalog.Set("小助手找到了与原文件内容完全一致的新路径。确认后将更新守护目标，名称、图标和启动设置保持不变。", "The assistant found a new path whose file content is an exact match. Confirming updates the monitored target while preserving its name, icon, and launch settings.")
        catalog.Set("原路径：", "Previous path:")
        catalog.Set("新路径：", "New path:")
        catalog.Set("识别依据：", "Detection evidence: ")
        catalog.Set("更新守护路径", "Update monitored path")
        catalog.Set("忽略", "Ignore")
        catalog.Set("更新已更名的守护目标", "Update renamed monitored target")
        catalog.Set("• 直接添加的程序或脚本本身或上级目录被更名、跨目录或跨磁盘移动后，小助手会按文件大小筛选并以 SHA-256 内容哈希确认新路径；即使移动发生在小助手关闭期间也能识别。", "• After a directly added program, script, or parent folder is renamed or moved across folders or drives, the assistant filters by file size and confirms the new path with a SHA-256 content hash, even when the move happened while the assistant was closed.")
        catalog.Set("• 文件名、文件 ID 和目录监听不参与迁移判断。发现多个内容相同的副本或扫描未完整完成时不会猜测目标；确认后只更新守护路径，名称、图标和启动设置保持不变。", "• File names, file IDs, and directory watchers are not used for relocation decisions. The assistant does not guess when identical copies exist or a scan is incomplete. Confirming changes only the monitored path and preserves the name, icon, and launch settings.")
        catalog.Set("; AppN 与 [Apps] 中同名的直接文件目标一一对应，依次保存文件大小和 SHA-256 内容哈希。", "; Each AppN entry corresponds to the directly monitored file with the same name in [Apps] and stores its file size followed by its SHA-256 content hash.")
        catalog.Set("; 此节由小助手自动维护，用于在文件或目录改名、跨目录或跨磁盘移动后确认内容未变；请勿手动编辑。", "; The assistant maintains this section automatically to verify unchanged content after file or folder renames and moves across folders or drives. Do not edit it manually.")
        catalog.Set("Everything64.dll 已加载，但 Everything 后台实例未响应；正在尝试定位并启动 Everything 本体。",
            "Everything64.dll is loaded, but the Everything background instance is not responding. The assistant is trying to locate and start the Everything application.")
        catalog.Set("Everything 查询失败：{1}",
            "Everything query failed: {1}")
        catalog.Set("Everything 搜索暂时不可用：后台实例未返回结果，请稍后重试。",
            "Everything search is temporarily unavailable: the background instance did not return results. Try again shortly.")
        catalog.Set("内存不足", "Not enough memory")
        catalog.Set("后台 IPC 服务不可用",
            "The background IPC service is unavailable")
        catalog.Set("无法注册 Everything 查询窗口类",
            "Could not register the Everything query window class")
        catalog.Set("无法创建 Everything 查询窗口",
            "Could not create the Everything query window")
        catalog.Set("无法创建 Everything 查询线程",
            "Could not create the Everything query thread")
        catalog.Set("结果索引无效", "The result index is invalid")
        catalog.Set("调用顺序无效", "The call sequence is invalid")
        catalog.Set("未知错误码 {1}", "Unknown error code {1}")
        catalog.Set("已找到 Everything 本体，但无法后台启动；请手动启动 Everything 后重试。",
            "Everything was found but could not be started in the background. Start Everything manually and try again.")
        catalog.Set("后台启动 Everything 失败：{1}（路径：{2}；发现过程：{3}）",
            "Failed to start Everything in the background: {1} (path: {2}; discovery: {3})")
        catalog.Set("正在后台启动 Everything 本体并等待搜索服务就绪...",
            "Starting the Everything application in the background and waiting for the search service...")
        catalog.Set("已启动 Everything，但后台搜索服务仍未响应；请确认 Everything 主程序完成启动且服务可用。",
            "Everything was started, but the background search service is still not responding. Confirm that Everything finished starting and its service is available.")
        catalog.Set("未找到 Everything 本体，点击前往官网下载最新版：{1}",
            "Everything was not found. Click to download the latest version from the official site: {1}")
        catalog.Set("本机未找到 Everything 本体；程序搜索需要 Everything 的索引和后台服务，随包 Everything64.dll 只是 IPC 客户端。{1}{2}",
            "Everything was not found on this computer. Program search requires Everything's index and background service; the bundled Everything64.dll is only an IPC client. {1}{2}")
        catalog.Set("暂时无法核对现有进程，延迟启动以避免重复实例：{1}{2}",
            "The existing process cannot be verified yet, so startup is delayed to avoid a duplicate instance: {1}{2}")
        catalog.Set("来源：{1}", "Source: {1}")
        catalog.Set("原因：{1}", "Reason: {1}")
        catalog.Set("原因码：{1}", "Reason code: {1}")
        catalog.Set("命令行探测", "command-line probe")
        catalog.Set("进程路径探测", "process-path probe")
        catalog.Set("工作目录探测", "working-directory probe")
        catalog.Set("后台进程快照", "background process snapshot")
        catalog.Set("进程名探测", "process-name probe")
        catalog.Set("AutoHotkey 窗口探测", "AutoHotkey window probe")
        catalog.Set("目标探活配置", "target probe configuration")
        catalog.Set("后台进程快照不可用",
            "The background process snapshot is unavailable")
        catalog.Set("候选进程命令行不可用",
            "The candidate process command line is unavailable")
        catalog.Set("命令行只提供相对目标路径，无法可靠匹配",
            "The command line provides only a relative target path, so it cannot be matched reliably")
        catalog.Set("候选进程镜像路径不可访问",
            "The candidate process image path is inaccessible")
        catalog.Set("候选进程创建身份无法核对",
            "The candidate process creation identity cannot be verified")
        catalog.Set("存在多个候选进程，无法唯一确认",
            "Multiple candidate processes exist, so the target cannot be uniquely confirmed")
        catalog.Set("目标探活规格无效",
            "The target probe specification is invalid")
        catalog.Set("🔄 重新启动", "🔄 Restart")
        catalog.Set("点个 star 吧~", "Give us a little star~")
        catalog.Set("⏳ 停止原进程...", "⏳ Stopping the existing process...")
        catalog.Set("❌ 无法停止原进程", "❌ Could Not Stop Existing Process")
        catalog.Set("手动触发了重新启动：{1}", "Restart requested manually: {1}")
        catalog.Set("手动重启已取消，原进程未能停止：{1}", "Manual restart was cancelled because the existing process could not be stopped: {1}")
        catalog.Set("暂时无法查询进程状态，稍后重试手动重启：{1}", "Process status is temporarily unavailable. Manual restart will be retried later: {1}")
        catalog.Set("暂时无法重新启动", "Restart Temporarily Unavailable")
        catalog.Set("该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。", "Update protection is active for this application. Wait for the update to finish, or end the wait in Update Protection before restarting it.")
        catalog.Set("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• “Restart” first asks the target to exit normally. If the timeout expires, the option under “Stop Policy” determines whether it is forcibly terminated.")
        catalog.Set("查看版本、运行环境和项目入口", "View version, runtime, and project links")
        catalog.Set("找作者对线", "Talk to the author")
        return catalog
    }
}

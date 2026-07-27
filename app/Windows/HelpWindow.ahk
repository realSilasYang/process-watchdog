; 内置使用说明窗口。
; 以只读文本展示随发行包提供的说明文件，保留选择和复制能力但不进入编辑状态；
; 读取失败时给出可理解的替代内容，窗口关闭不会影响主窗口可见性。

class HelpWindow extends ManagedWindow {
    static TextCache := Map()

    __New(mainGui) {
        this.owner := mainGui
        this.textEdit := ""
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "", Tr("使用说明"))
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        InitializeApplicationWindow(this.gui, "s11")

        helpText := this.BuildText()

        helpWidth := LocalizationService.UsesCompactLayout() ? 660 : 760
        this.textEdit := this.gui.Add("Edit", "w" helpWidth
            " r23 ReadOnly Background" UiThemeService.Color("Surface")
                " c" UiThemeService.Color("Text")
                " -E0x200 Multi VScroll", helpText)
        SetDarkControl(this.textEdit.Hwnd)
        RegisterTextInputControl(this.textEdit, true, true)
        this.textEdit.OnEvent("Focus", ObjBindMethod(this, "HideCaret"))
        this.gui.Show("AutoSize")
        SendMessage(Win32.EM_SETSEL, 0, 0, this.textEdit.Hwnd)
        SendMessage(0x00B7, 0, 0, this.textEdit.Hwnd) ; EM_SCROLLCARET：确保帮助内容从首行开始显示。
        lineCount := SendMessage(0x00BA, 0, 0, this.textEdit.Hwnd)
        if (lineCount <= 23)
            DllCall("ShowScrollBar", "Ptr", this.textEdit.Hwnd, "Int", 1, "Int", 0)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    BuildText() {
        cacheKey := LocalizationService.GetLanguage() "|"
            (A_IsCompiled ? "compiled" : "source")
        if HelpWindow.TextCache.Has(cacheKey)
            return HelpWindow.TextCache[cacheKey]
        runtimeUpdateNote := A_IsCompiled
            ? Tr("• EXE 版已内嵌该版本发布时验证通过的 AutoHotkey；更新完整小助手发行包时，内嵌运行时会一同更新，电脑无需另装 AutoHotkey。")
            : Tr("• 源码版使用电脑当前安装的 AutoHotkey；小助手更新只更新项目源码，不会安装或升级本机解释器。")
        lines := [
            "",
            Tr("小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。"),
            "",
            Tr("一、快速上手"),
            Tr("• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。"),
            Tr("• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控与启动”控制。"),
            Tr("• 也可将文件或文件夹直接拖放到主列表；已经存在的项目不会重复添加。"),
            Tr("• 选中项目后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。"),
            "",
            Tr("二、支持的目标"),
            Tr("• 程序：EXE、COM、MSC。"),
            Tr("• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。"),
            Tr("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。"),
            "",
            Tr("三、主界面操作"),
            Tr("• 单击选择项目；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。"),
            Tr("• 双击项目或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。"),
            Tr("• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。"),
            Tr("• 多选项目状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。"),
            Tr("• 右键项目可自定义主窗口名称和图标，也可打开所在位置、重新启动、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。要求管理员运行但当前权限不符时会显示警告；右键重新启动会按该设置提权启动。"),
            "",
            Tr("四、守护与重启"),
            Tr("• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。"),
            Tr("• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。"),
            Tr("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。"),
            Tr("• 暂停项目会取消该项目的重试和升级检测；恢复后会重新检查目标状态。"),
            "",
            Tr("五、设置"),
            Tr("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。"),
            Tr("• 界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。"),
            Tr("• 监控与启动：设置进程状态检查间隔、崩溃自动重启延迟序列，以及导入文件夹时是否包含子目录。"),
            Tr("• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。"),
            Tr("• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。"),
            Tr("• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。"),
            Tr("• 程序搜索：仅使用 Everything 服务并显示全部匹配结果；使用前请保持 Everything 正在运行。"),
            "",
            Tr("六、版本与小助手自身更新"),
            "• " GetApplicationVersionSummary(),
            Tr("• 小助手版本与 AutoHotkey 版本彼此独立；“关于”页会分别显示当前小助手版本、运行形态和实际运行时版本。"),
            runtimeUpdateNote,
            Tr("• 每次正式发布开始时都会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版（可能为预发布），冻结本次版本后完成全套测试；只有通过才生成发行包。"),
            Tr("• Ahk2Exe 只在发布服务器上用于生成 EXE，不随小助手安装，普通用户和源码运行用户都不需要维护它。"),
            Tr("• “关于”页可控制是否在启动时后台检查新版，也可随时手动检查。检查过程不会阻塞主界面。"),
            Tr("• 发现新版后会先询问；确认后校验完整发行包，退出当前实例、替换受管文件并自动重启，不会覆盖个人配置和升级保护会话。"),
            Tr("• EXE 版更新完整编译包；Git 源码版仅在受跟踪文件无修改且可快速前进时更新；其他源码版使用源码发行包。"),
            "",
            Tr("七、软件升级保护"),
            Tr("• 软件升级保护默认关闭。需要时在项目右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。"),
            Tr("• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。"),
            Tr("• 在项目右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。"),
            Tr("• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。"),
            Tr("• 可控的更新脚本可显式发送维护指令："),
            Tr("  --maintenance-begin `"目标完整路径`"    开始维护"),
            Tr("  --maintenance-end `"目标完整路径`"      结束维护"),
            "",
            Tr("八、日志与托盘"),
            Tr("• 主界面的“帮助信息”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。"),
            Tr("• 项目右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。"),
            Tr("• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。")
        ]
        text := ""
        for index, line in lines
            text .= (index > 1 ? "`r`n" : "") line
        HelpWindow.TextCache[cacheKey] := text
        return text
    }

    HideCaret(*) {
        if this.textEdit
            ScheduleHideTextCaret(this.textEdit.Hwnd)
    }

    Close(*) {
        this.DestroyGui()
        this.textEdit := ""
    }
}

class HelpWindow extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.textEdit := ""
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "", "使用说明")
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s11 cWhite", "Microsoft YaHei")

        helpText := this.BuildText()

        this.textEdit := this.gui.Add("Edit", "w660 r23 ReadOnly Background252526 cWhite -E0x200 Multi VScroll", helpText)
        SetDarkControl(this.textEdit.Hwnd)
        RegisterTextInputControl(this.textEdit, true, true)
        this.textEdit.OnEvent("Focus", ObjBindMethod(this, "HideCaret"))
        this.gui.Show("AutoSize")
        SendMessage(Win32.EM_SETSEL, 0, 0, this.textEdit.Hwnd)
        SendMessage(0x00B7, 0, 0, this.textEdit.Hwnd) ; EM_SCROLLCARET
        lineCount := SendMessage(0x00BA, 0, 0, this.textEdit.Hwnd)
        if (lineCount <= 23)
            DllCall("ShowScrollBar", "Ptr", this.textEdit.Hwnd, "Int", 1, "Int", 0)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    BuildText() {
        lines := [
            "",
            "小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。",
            "",
            "一、快速上手",
            "• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。",
            "• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控与启动”控制。",
            "• 也可将文件或文件夹直接拖放到主列表；已经存在的项目不会重复添加。",
            "• 选中项目后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。",
            "",
            "二、支持的目标",
            "• 程序：EXE、COM、MSC。",
            "• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。",
            "• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“高级运行环境设置”中手动指定真实进程。",
            "",
            "三、主界面操作",
            "• 单击选择项目；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。",
            "• 双击项目或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。",
            "• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。",
            "• 多选项目状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。",
            "• 右键项目可自定义主窗口名称和图标，也可打开所在位置、重新启动、编辑路径、切换管理员运行、配置高级运行环境与软件升级保护，并查看批处理输出日志。要求管理员运行但当前权限不符时会显示警告；右键重新启动会按该设置提权启动。",
            "",
            "四、守护与重启",
            "• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。",
            "• 检测到目标停止后，会先确认状态，再按“重启等待序列”依次重试；连续失败时采用后续等待时间，避免频繁拉起。",
            "• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止”中的选项决定。",
            "• 暂停项目会取消该项目的重试和升级检测；恢复后会重新检查目标状态。",
            "",
            "五、设置",
            "• 系统集成：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启。",
            "• 监控与启动：设置状态检查间隔、重启等待序列、启动后是否显示主窗口，以及文件夹批量导入是否递归。",
            "• 停止：设置窗口程序和命令行程序的退出等待，以及是否允许强制终止。",
            "• 日志：设置运行日志内存上限、批处理输出日志的保存目录、保留时间和启动时清理策略。",
            "• 搜索与导入：选择 Everything 或内置搜索，并设置扫描时间和结果数量上限。",
            "",
            "六、软件升级保护",
            "• 软件升级保护默认关闭。需要时在项目右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。",
            "• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。",
            "• 在项目右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。",
            "• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。",
            "• 可控的更新脚本可显式发送维护指令：",
            "  --maintenance-begin `"目标完整路径`"    开始维护",
            "  --maintenance-end `"目标完整路径`"      结束维护",
            "",
            "七、日志与托盘",
            "• 主界面的“日志”显示本次运行中的监控、重启、升级保护和操作记录，并会自动更新。",
            "• 项目右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。",
            "• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。"
        ]
        text := ""
        for index, line in lines
            text .= (index > 1 ? "`r`n" : "") line
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

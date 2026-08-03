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
        ShowApplicationWindow(this.gui, "AutoSize")
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
        lines := [
            "",
            Tr("小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。"),
            "",
            Tr("一、快速上手"),
            Tr("• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。"),
            Tr("• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控与启动”控制。"),
            Tr("• 也可将文件或文件夹直接拖放到主列表；已经存在的守护对象不会重复添加。"),
            Tr("• 选中守护对象后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。"),
            "",
            Tr("二、支持的守护对象"),
            Tr("• 程序：EXE、COM、MSC。"),
            Tr("• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。"),
            Tr("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。"),
            "",
            Tr("三、主界面操作"),
            Tr("• 单击选择守护对象；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。"),
            Tr("• 双击守护对象或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。"),
            Tr("• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。"),
            Tr("• 多个守护对象状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。"),
            Tr("• 右键守护对象可自定义主窗口名称和图标，也可打开所在位置、结束运行、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。“结束运行”会同时暂停守护，目标不会被自动重新启动；要求管理员运行但当前权限不符时仍会显示警告。"),
            Tr("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。"),
            Tr("• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。"),
            "",
            Tr("四、守护与重启"),
            Tr("• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。"),
            Tr("• 直接添加的程序或脚本本身或上级目录被更名、跨目录或跨磁盘移动后，小助手会按文件大小筛选并以 SHA-256 内容哈希确认新路径；即使移动发生在小助手关闭期间也能识别。"),
            Tr("• 文件名、文件 ID 和目录监听不参与迁移判断。发现多个内容相同的副本或扫描未完整完成时不会猜测目标；确认后只更新守护路径，名称、图标和启动设置保持不变。"),
            Tr("• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。"),
            Tr("• “结束运行”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。"),
            Tr("• 暂停守护对象会取消它的重试和升级检测；恢复后会重新检查目标状态。"),
            "",
            Tr("五、设置"),
            Tr("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。"),
            Tr("• 界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。"),
            Tr("• 监控与启动：设置进程状态检查间隔、崩溃自动重启延迟序列，以及导入文件夹时是否包含子目录。"),
            Tr("• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。"),
            Tr("• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。"),
            Tr("• 程序搜索：使用 Everything 服务并显示全部匹配结果；未运行时会尝试在本机查找并后台启动，未找到时提供官网最新版下载地址。"),
            Tr("• 小助手随包的 Everything64.dll 只是连接 Everything 后台实例的 SDK 客户端，不负责扫描磁盘或建立索引，不能替代 Everything 本体。"),
            "",
            Tr("六、进程识别与启动设置"),
            Tr("• 此设置只作用于当前守护对象，并将“用什么启动”和“用什么判断正在运行”分开处理。启动环境只在小助手下次启动目标时生效，不会重启当前进程。"),
            Tr("• 直接添加程序或脚本时，启动入口与监控目标相同；EXE 按完整路径识别，脚本按宿主进程命令行中的脚本路径识别。"),
            Tr("• 添加 LNK 快捷方式时，快捷方式始终作为启动入口；自动识别出的真实程序或脚本只用于判断运行状态。"),
            Tr("• 自动识别会综合快捷方式目标、参数、Windows Installer 信息、安装目录、文件版本信息和已观察进程；证据不唯一时不会随意绑定。"),
            Tr("• 自动结果不正确时改用“用户指定”，选择程序正常运行期间持续存在的主程序或脚本；不要选择启动器、更新器或短暂子进程。"),
            Tr("• 直接脚本可指定“启动程序或解释器”，选择实际执行脚本的可执行文件，例如 Python、AutoHotkey、PowerShell、Node.js、Ruby、Perl、PHP、Lua、Java 或 Bash；留空时沿用系统默认启动方式。"),
            Tr("• “启动程序参数”位于目标路径之前，“目标参数（Args）”位于目标路径之后。Java 可填写 -jar；PowerShell 可填写 -NoProfile -ExecutionPolicy Bypass -File。"),
            Tr("• Python 虚拟环境请选择该环境的 Scripts\python.exe；其他语言也可选择项目要求的确切运行时版本。进程识别仍以目标脚本路径为准，不会误把解释器本身当成守护目标。"),
            Tr("• 工作目录（CWD）用于解析相对路径；留空时使用快捷方式工作目录或目标所在目录。"),
            Tr("• 环境变量每行填写一个 KEY=VALUE，只覆盖列出的变量；值中可用 %变量名% 引用已有环境变量。启动完成后小助手会恢复自身环境。"),
            "",
            Tr("七、软件升级保护"),
            Tr("• 软件升级保护默认关闭。需要时在守护对象右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。"),
            Tr("• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。"),
            Tr("• 在守护对象右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。"),
            Tr("• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。"),
            Tr("• 可控的更新脚本可显式发送维护指令："),
            Tr("  --maintenance-begin `"目标完整路径`"    开始维护"),
            Tr("  --maintenance-end `"目标完整路径`"      结束维护"),
            "",
            Tr("八、日志与托盘"),
            Tr("• 主界面的“帮助”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。"),
            Tr("• 守护对象右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。"),
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

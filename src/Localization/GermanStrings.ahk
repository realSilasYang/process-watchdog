; de-DE 本地化词条目录。
; 本目录由模型直接依据简体中文稳定键逐条翻译；生成步骤仅处理转义与格式。

class GermanStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Drücken")
        catalog.Set(
            "`n位置：{1}",
                "`nSpeicherort: {1}")
        catalog.Set(
            "`r`n      影响：该项目本次未加入守护列表。",
                "`r`n      Auswirkung: Dieser Eintrag wurde nicht zur Überwachungsliste hinzugefügt.")
        catalog.Set(
            "`r`n      目标：{1}",
                "`r`n      Ziel: {1}")
        catalog.Set(
            "`r`n      问题：{1}：{2}",
                "`r`n      Problem: {1}: {2}")
        catalog.Set(
            "`r`n  [{1}] 位置：[{2}] {3}",
                "`r`n  [{1}] Speicherort: [{2}] {3}")
        catalog.Set(
            "`r`n  处理建议：确认目标路径后，可在主界面重新添加该项目；也可退出小助手后检查上述配置位置。后续保存配置时，损坏记录会转存到 [Recovery]，不会被静默删除。",
                "`r`n  Empfohlene Maßnahme: Prüfen Sie den Zielpfad und fügen Sie den Eintrag anschließend im Hauptfenster erneut hinzu. Sie können den Assistenten auch beenden und den oben genannten Konfigurationsort prüfen. Beim nächsten Speichern werden beschädigte Datensätze nach [Recovery] verschoben und nicht unbemerkt gelöscht.")
        catalog.Set(
            "`r`n  配置文件：{1}",
                "`r`n  Konfigurationsdatei: {1}")
        catalog.Set(
            "   ⚠️ 配置未保存",
                "   ⚠️ Konfiguration nicht gespeichert")
        catalog.Set(
            "  --maintenance-begin `"目标完整路径`"    开始维护",
                "  --maintenance-begin `"vollständiger Zielpfad`"    Wartung beginnen")
        catalog.Set(
            "  --maintenance-end `"目标完整路径`"      结束维护",
                "  --maintenance-end `"vollständiger Zielpfad`"      Wartung beenden")
        catalog.Set(
            " 已保留并保存此前添加的 {1} 个监控项。",
                " Die zuvor hinzugefügten {1} Überwachungseinträge wurden beibehalten und gespeichert.")
        catalog.Set(
            " 扫描达到时间或数量上限，结果已截断。",
                " Die Suche hat das Zeit- oder Ergebnislimit erreicht`; die Ergebnisse wurden gekürzt.")
        catalog.Set(
            "`; AllowForceTerminate：正常退出超时后是否允许强制结束进程。",
                "`; AllowForceTerminate: Legt fest, ob der Prozess nach Ablauf der Wartezeit für das reguläre Beenden zwangsweise beendet werden darf.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名项目一一对应，值为软件升级保护的 <HEX> 编码结构。",
                "`; Jeder AppN-Eintrag entspricht dem gleichnamigen Eintrag unter [Apps]`; sein Wert enthält die als <HEX> codierte Struktur für den Update-Schutz.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名项目一一对应；留空的项目使用目标自身的名称和图标。",
                "`; Jeder AppN-Eintrag entspricht dem gleichnamigen Eintrag unter [Apps]`; leere Einträge verwenden Name und Symbol des Ziels.")
        catalog.Set(
            "`; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。",
                "`; CheckInterval: Intervall der Statusprüfung in Millisekunden`; Bereich 500 bis 86400000.")
        catalog.Set(
            "`; CheckUpdatesOnStartup：启动后是否在后台检查小助手新版。",
                "`; CheckUpdatesOnStartup: Legt fest, ob nach dem Start im Hintergrund nach einer neuen Version des Assistenten gesucht wird.")
        catalog.Set(
            "`; ClearLogsOnStartup：启动时是否清空历史日志。",
                "`; ClearLogsOnStartup: Legt fest, ob frühere Protokolle beim Start gelöscht werden.")
        catalog.Set(
            "`; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col1W: Breite der ersten Spalte der Hauptliste, gespeichert in logischen Pixeln bei 96 DPI.")
        catalog.Set(
            "`; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col2W: Breite der zweiten Spalte der Hauptliste, gespeichert in logischen Pixeln bei 96 DPI.")
        catalog.Set(
            "`; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。",
                "`; CtrlCWaitSeconds: Maximale Wartezeit in Sekunden, nachdem ein Befehlszeilenprogramm Strg+C empfangen hat`; Bereich 1 bis 60.")
        catalog.Set(
            "`; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。",
                "`; GracefulStopSeconds: Maximale Wartezeit in Sekunden für das reguläre Beenden eines Fensterprogramms`; Bereich 1 bis 300.")
        catalog.Set(
            "`; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。",
                "`; GuiH: Höhe des Hauptfensters, gespeichert in logischen Pixeln bei 96 DPI.")
        catalog.Set(
            "`; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。",
                "`; GuiW: Breite des Hauptfensters, gespeichert in logischen Pixeln bei 96 DPI.")
        catalog.Set(
            "`; LogDirectory：留空时使用系统临时目录下的 ProcessWatchdogLogs。",
                "`; LogDirectory: Bleibt der Wert leer, wird ProcessWatchdogLogs im temporären Systemverzeichnis verwendet.")
        catalog.Set(
            "`; LogMaxEntries：日志界面保留条数，范围 50～10000。",
                "`; LogMaxEntries: Anzahl der im Protokollfenster behaltenen Einträge`; Bereich 50 bis 10000.")
        catalog.Set(
            "`; LogRetentionDays：日志文件保留天数，范围 1～3650。",
                "`; LogRetentionDays: Aufbewahrungsdauer der Protokolldateien in Tagen`; Bereich 1 bis 3650.")
        catalog.Set(
            "`; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。",
                "`; RecursiveBatchImport: Legt fest, ob beim stapelweisen Import eines Ordners Unterordner durchsucht werden.")
        catalog.Set(
            "`; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。",
                "`; RetrySequence: Wartezeiten vor einem Neustart in Sekunden, durch Kommas getrennt`; höchstens 10 Werte, jeweils im Bereich 1 bis 86400.")
        catalog.Set(
            "`; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。",
                "`; ShowAfterReload: Interne Markierung für das Neuladen`; wird danach automatisch auf 0 zurückgesetzt.")
        catalog.Set(
            "`; ShowAtStartup：启动后是否显示主窗口。",
                "`; ShowAtStartup: Legt fest, ob das Hauptfenster nach dem Start angezeigt wird.")
        catalog.Set(
            "`; UiLanguage：界面语言；auto 表示跟随系统，也可填写受支持的语言代码。",
                "`; UiLanguage: Sprache der Benutzeroberfläche`; auto übernimmt die Systemsprache, alternativ kann ein unterstützter Sprachcode eingetragen werden.")
        catalog.Set(
            "`; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。",
                "`; Speichert nur den im Hauptfenster angezeigten Namen und die Symbolquelle`; beeinflusst weder Prozesserkennung noch Start oder Update-Schutz.")
        catalog.Set(
            "`; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
                "`; Zu den internen Feldern gehören Enabled, RootIsCustom, DetectionSeconds, StableSeconds, MaxWaitSeconds, InstallRoot und Actor.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。",
                "`; Boolesche Werte verwenden 1 für aktiviert und 0 für deaktiviert`; Änderungen sollten vorzugsweise im Einstellungsfenster vorgenommen werden.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。",
                "`; Boolesche Werte verwenden 1 für aktiviert und 0 für deaktiviert`; <HEX>-Inhalte werden automatisch vom Programm codiert und decodiert.")
        catalog.Set(
            "`; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。",
                "`; Änderungen sollten unter „Software-Update-Schutz“ vorgenommen werden`; bearbeiten Sie die codierten Inhalte nicht direkt.")
        catalog.Set(
            "`; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。",
                "`; Überwachungsdatensätze, die nicht sicher gelesen werden können, werden vorübergehend hier abgelegt, damit sie nicht unbemerkt verloren gehen`; normalerweise ist keine manuelle Bearbeitung erforderlich.")
        catalog.Set(
            "`; 本区保存运行参数；以分号开头的注释不会参与软件读取。",
                "`; Dieser Abschnitt speichert Ausführungsparameter`; Kommentare, die mit einem Semikolon beginnen, werden vom Programm nicht eingelesen.")
        catalog.Set(
            "`; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
                "`; Format: aktiviert｜als Administrator ausführen｜Zielpfad｜Arbeitsverzeichnis｜Startargumente｜Umgebungsvariablen｜tatsächliches Verknüpfungsziel｜Kennzeichnung für manuelles Ziel｜Verknüpfungsargumente.")
        catalog.Set(
            "`; 每个 AppN 对应一个监控项，九个字段使用竖线分隔。",
                "`; Jeder AppN-Eintrag entspricht einem Überwachungseintrag`; die neun Felder werden durch senkrechte Striche getrennt.")
        catalog.Set(
            "DPI 变化后刷新图标失败：{1}",
                "Symbol konnte nach der DPI-Änderung nicht aktualisiert werden: {1}")
        catalog.Set(
            "DPI 变化后重建图标列表失败：{1}",
                "Symbolliste konnte nach der DPI-Änderung nicht neu aufgebaut werden: {1}")
        catalog.Set(
            "DPI 图标重建回调无效",
                "Ungültiger Rückruf zum Neuaufbau der Symbole bei DPI-Änderungen")
        catalog.Set(
            "{1} 条监控配置未载入，相关项目当前不会被守护。点击查看具体位置和原因。",
                "{1} Überwachungskonfigurationen wurden nicht geladen`; die zugehörigen Einträge werden derzeit nicht überwacht. Klicken Sie, um Ort und Ursache anzuzeigen.")
        catalog.Set(
            "• Ahk2Exe 只在发布服务器上用于生成 EXE，不随小助手安装，普通用户和源码运行用户都不需要维护它。",
                "• Ahk2Exe wird ausschließlich auf dem Veröffentlichungsserver zum Erstellen der EXE verwendet. Es wird nicht mit dem Assistenten installiert und muss weder von normalen Benutzern noch von Benutzern der Quellcodeversion gepflegt werden.")
        catalog.Set(
            "• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。",
                "• Strg+A wählt alles aus. Esc hebt zunächst die Auswahl auf`; ist nichts ausgewählt, blendet ein weiterer Druck auf Esc das Hauptfenster aus.")
        catalog.Set(
            "• EXE 版已内嵌该版本发布时验证通过的 AutoHotkey；更新完整小助手发行包时，内嵌运行时会一同更新，电脑无需另装 AutoHotkey。",
                "• Die EXE-Version enthält die bei ihrer Veröffentlichung geprüfte AutoHotkey-Version. Die eingebettete Laufzeit wird zusammen mit dem vollständigen Assistentenpaket aktualisiert`; AutoHotkey muss nicht separat installiert sein.")
        catalog.Set(
            "• EXE 版更新完整编译包；Git 源码版仅在受跟踪文件无修改且可快速前进时更新；其他源码版使用源码发行包。",
                "• Die EXE-Version aktualisiert das vollständige kompilierte Paket. Die Git-Quellcodeversion wird nur aktualisiert, wenn keine verfolgten Dateien geändert wurden und ein Fast-Forward möglich ist`; andere Quellcodeinstallationen verwenden das Quellcodepaket.")
        catalog.Set(
            "• “监控与启动”可控制是否在启动时后台检查新版；“通用”可随时手动检查。检查过程不会阻塞主界面。",
                "• Unter „Überwachung und Start“ können Sie die Hintergrundsuche nach neuen Versionen beim Start steuern`; unter „Allgemein“ kann jederzeit manuell gesucht werden. Die Prüfung blockiert das Hauptfenster nicht.")
        catalog.Set(
            "• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止”中的选项决定。",
                "• „Neu starten“ fordert das Ziel zunächst zum regulären Beenden auf. Wird die festgelegte Zeit überschritten, bestimmt die entsprechende Option unter „Beenden“, ob das Beenden erzwungen wird.")
        catalog.Set(
            "• 主界面的“日志”显示本次运行中的监控、重启、升级保护和操作记录，并会自动更新。",
                "• „Protokoll“ im Hauptfenster zeigt die Überwachungs-, Neustart-, Update-Schutz- und Bedienereignisse der aktuellen Sitzung an und wird automatisch aktualisiert.")
        catalog.Set(
            "• 也可将文件或文件夹直接拖放到主列表；已经存在的项目不会重复添加。",
                "• Dateien und Ordner können auch direkt auf die Hauptliste gezogen werden`; vorhandene Einträge werden nicht erneut hinzugefügt.")
        catalog.Set(
            "• 停止：设置窗口程序和命令行程序的退出等待，以及是否允许强制终止。",
                "• Beenden: Legen Sie die Wartezeit für Fenster- und Befehlszeilenprogramme sowie die Erlaubnis zum erzwungenen Beenden fest.")
        catalog.Set(
            "• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。",
                "• Nach dem Schließen des Hauptfensters läuft der Assistent im Infobereich weiter. Über das Menü des Symbols können Sie die Oberfläche erneut anzeigen, das Programm neu laden oder beenden.")
        catalog.Set(
            "• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。",
                "• Wenn die Update-Wartezeit abläuft oder ein Update falsch erkannt wurde, wählen Sie „Update-Wartezeit beenden und Überwachung fortsetzen“. Vor dem Fortsetzen wird weiterhin geprüft, ob das Ziel sicher gestartet werden kann.")
        catalog.Set(
            "• 单击选择项目；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。",
                "• Klicken Sie zum Auswählen auf einen Eintrag`; halten Sie Strg oder Umschalt gedrückt, um mehrere auszuwählen`; ziehen Sie Zeilen, um die Überwachungsreihenfolge zu ändern.")
        catalog.Set(
            "• 双击项目或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。",
                "• Doppelklicken Sie auf einen Eintrag oder drücken Sie F2, um den vollständigen Pfad zu bearbeiten. Entf löscht, Strg+Z macht rückgängig, Strg+Umschalt+Z oder Strg+Y stellt wieder her.")
        catalog.Set(
            "• 发现新版后会先询问；确认后校验完整发行包，退出当前实例、替换受管文件并自动重启，不会覆盖个人配置和升级保护会话。",
                "• Wenn eine neue Version gefunden wird, erfolgt zunächst eine Rückfrage. Danach wird das vollständige Veröffentlichungspaket geprüft, die aktuelle Instanz beendet, die verwalteten Dateien ersetzt und der Assistent automatisch neu gestartet. Persönliche Einstellungen und Update-Schutz-Sitzungen werden nicht überschrieben.")
        catalog.Set(
            "• 可控的更新脚本可显式发送维护指令：",
                "• Ein von Ihnen verwaltetes Update-Skript kann ausdrückliche Wartungsbefehle senden:")
        catalog.Set(
            "• 右键项目可自定义主窗口名称和图标，也可打开所在位置、重新启动、编辑路径、切换管理员运行、配置高级运行环境与软件升级保护，并查看批处理输出日志。要求管理员运行但当前权限不符时会显示警告；右键重新启动会按该设置提权启动。",
                "• Klicken Sie mit der rechten Maustaste auf einen Eintrag, um Namen und Symbol im Hauptfenster anzupassen, den Speicherort zu öffnen, ihn neu zu starten, den Pfad zu bearbeiten, die Ausführung als Administrator umzuschalten, die erweiterte Laufzeitumgebung und den Update-Schutz einzurichten oder das Stapelausgabeprotokoll anzuzeigen. Falls Administratorrechte verlangt werden, der aktuelle Prozess sie aber nicht besitzt, erscheint eine Warnung`; beim Neustart über das Kontextmenü werden die Rechte gemäß dieser Einstellung erhöht.")
        catalog.Set(
            "• 在项目右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。",
                "• Öffnen Sie im Kontextmenü eines Eintrags „Software-Update-Schutz“, um Installationsverzeichnis, Ausgangserkennungszeitraum, Dateistabilitätswartezeit und maximale Update-Wartezeit einzustellen oder erlernte Merkmale des Update-Programms zu löschen.")
        catalog.Set(
            "• 多选项目状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。",
                "• Haben alle ausgewählten Einträge denselben Status, werden sie über „Pausieren“ gemeinsam pausiert oder fortgesetzt`; bei gemischten Zuständen wird jeder Status einzeln umgekehrt.")
        catalog.Set(
            "• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。",
                "• Der Assistent gleicht Zielpfad oder Befehlszeile ab, um Fehlzuordnungen allein anhand des Prozessnamens zu vermeiden.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“通用”页会同时显示当前小助手版本、运行形态和实际运行时版本。",
                "• Die Versionen des Assistenten und von AutoHotkey sind unabhängig. Unter „Allgemein“ werden die aktuelle Assistentenversion, die Ausführungsart und die tatsächliche Laufzeitversion gemeinsam angezeigt.")
        catalog.Set(
            "• 程序搜索：仅使用 Everything 服务并显示全部匹配结果；使用前请保持 Everything 正在运行。",
                "• Programmsuche: verwendet ausschließlich den Everything-Dienst und zeigt alle Treffer an. Stellen Sie vor der Suche sicher, dass Everything ausgeführt wird.")
        catalog.Set(
            "• 日志：设置运行日志内存上限、批处理输出日志的保存目录、保留时间和启动时清理策略。",
                "• Protokolle: Legen Sie die maximale Anzahl der Ausführungsprotokolle im Speicher, das Verzeichnis für Stapelausgabeprotokolle, deren Aufbewahrungsdauer und die Bereinigung beim Start fest.")
        catalog.Set(
            "• 暂停项目会取消该项目的重试和升级检测；恢复后会重新检查目标状态。",
                "• Beim Pausieren eines Eintrags werden seine Wiederholungsversuche und die Update-Erkennung abgebrochen`; nach dem Fortsetzen wird der Zielstatus erneut geprüft.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“重启等待序列”依次重试；连续失败时采用后续等待时间，避免频繁拉起。",
                "• Wenn ein Ziel als beendet erkannt wird, wird der Status zunächst bestätigt. Danach folgen Wiederholungsversuche gemäß der „Wartefolge für Neustarts“. Nach mehreren Fehlern werden spätere Wartezeiten verwendet, damit das Ziel nicht zu häufig gestartet wird.")
        catalog.Set(
            "• 每次正式发布开始时都会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版（可能为预发布），冻结本次版本后完成全套测试；只有通过才生成发行包。",
                "• Zu Beginn jeder offiziellen Veröffentlichung werden die neueste stabile AutoHotkey-Version und die neueste Ahk2Exe-Veröffentlichung（möglicherweise eine Vorabversion）neu ausgewählt, für diese Veröffentlichung festgeschrieben und vollständig getestet. Nur bei bestandenen Tests wird das Paket erstellt.")
        catalog.Set(
            "• 源码版使用电脑当前安装的 AutoHotkey；小助手更新只更新项目源码，不会安装或升级本机解释器。",
                "• Die Quellcodeversion verwendet die aktuell auf dem Computer installierte AutoHotkey-Version. Ein Assistentenupdate aktualisiert nur den Projektquellcode und installiert oder aktualisiert den lokalen Interpreter nicht.")
        catalog.Set(
            "• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。",
                "• Klicken Sie auf „Hinzufügen“, um eine Anwendung zu suchen oder Programme, Skripte, Verknüpfungen und Ordner auszuwählen.")
        catalog.Set(
            "• 界面语言和字体可在“通用”中手动切换；保存后立即更新主窗口、菜单和托盘，无需重新启动。",
                "• Sprache und Schriftart der Oberfläche lassen sich unter „Allgemein“ ändern. Nach dem Speichern werden Hauptfenster, Menüs und Infobereich sofort und ohne Neustart aktualisiert.")
        catalog.Set(
            "• 监控与启动：设置状态检查间隔、重启等待序列、启动后是否显示主窗口、是否检查小助手更新，以及文件夹批量导入是否递归。",
                "• Überwachung und Start: Stellen Sie Prüfintervall, Wartefolge für Neustarts, Anzeige des Hauptfensters und Update-Prüfung beim Start sowie die rekursive Ordnersuche beim Stapelimport ein.")
        catalog.Set(
            "• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。",
                "• Nach Bestätigung eines Updates werden automatische Starts ausgesetzt. Wenn die zugehörige Aktivität beendet und die Zieldatei stabil ist, wird die Überwachung automatisch fortgesetzt. Bei echten Updates erkannte Merkmale des Update-Programms werden automatisch gespeichert.")
        catalog.Set(
            "• 程序：EXE、COM、MSC。",
                "• Programme: EXE, COM und MSC.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，并可立即检查小助手更新。",
                "• Allgemein: Erstellen Sie Verknüpfungen auf dem Desktop und im Startmenü, aktivieren oder deaktivieren Sie den Autostart per geplanter Aufgabe und suchen Sie sofort nach Assistentenupdates.")
        catalog.Set(
            "• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。",
                "• Skripte: AHK, Python, JavaScript, VBScript, PowerShell, Stapeldateien sowie Ruby, Perl, PHP, Lua, JAR, Shell und weitere.")
        catalog.Set(
            "• 软件升级保护默认关闭。需要时在项目右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。",
                "• Der Software-Update-Schutz ist standardmäßig deaktiviert. Öffnen Sie bei Bedarf im Kontextmenü „Software-Update-Schutz“, aktivieren Sie „Updates automatisch erkennen und den Startvorgang schützen“ und speichern Sie.")
        catalog.Set(
            "• 选中项目后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。",
                "• Ausgewählte Einträge können pausiert, fortgesetzt oder gelöscht werden. Das Pausieren beendet nur die Überwachung und schließt keine derzeit laufenden Ziele.")
        catalog.Set(
            "• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控与启动”控制。",
                "• Bei Auswahl eines Ordners werden darin enthaltene unterstützte Dateien stapelweise importiert. Ob Unterordner durchsucht werden, wird unter „Überwachung und Start“ in den „Einstellungen“ festgelegt.")
        catalog.Set(
            "• 项目右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。",
                "• „Ausführungsprotokoll anzeigen“ im Kontextmenü öffnet das von BAT/CMD-Zielen erzeugte Ausgabeprotokoll. Bei anderen Typen oder solange es noch nicht erstellt wurde, wird gemeldet, dass die Datei fehlt.")
        catalog.Set(
            "⏳ 停止原进程...",
                "⏳ Ursprünglicher Prozess wird beendet...")
        catalog.Set(
            "⏳ 判断是否正在升级",
                "⏳ Laufendes Update wird geprüft")
        catalog.Set(
            "⏳ 升级完成，准备恢复",
                "⏳ Update abgeschlossen`; Fortsetzung wird vorbereitet")
        catalog.Set(
            "⏳ 启动倒计时 {1} 秒",
                "⏳ Start in {1} Sekunden")
        catalog.Set(
            "⏳ 启动失败，稍后自动重试",
                "⏳ Start fehlgeschlagen`; später erfolgt automatisch ein neuer Versuch")
        catalog.Set(
            "⏳ 确认升级文件稳定",
                "⏳ Stabilität der Update-Dateien wird geprüft")
        catalog.Set(
            "⏳ 确认升级文件稳定 {1}s",
                "⏳ Stabilität der Update-Dateien wird geprüft: {1}s")
        catalog.Set(
            "⏳ 稍后自动重试 {1} 秒",
                "⏳ Automatischer neuer Versuch in {1} Sekunden")
        catalog.Set(
            "⏳ 等待安全启动条件",
                "⏳ Warten auf sichere Startbedingungen")
        catalog.Set(
            "⏳ 等待进程状态...",
                "⏳ Warten auf Prozessstatus...")
        catalog.Set(
            "⏳ 重试倒计时 {1} 秒",
                "⏳ Neuer Versuch in {1} Sekunden")
        catalog.Set(
            "⏳ 验证运行状态...",
                "⏳ Ausführungsstatus wird geprüft...")
        catalog.Set(
            "⏸️ 已暂停",
                "⏸️ Pausiert")
        catalog.Set(
            "⏸️ 暂停",
                "⏸️ Pausieren")
        catalog.Set(
            "▶️ 恢复",
                "▶️ Fortsetzen")
        catalog.Set(
            "⚙️ 启动参数：{1}`n",
                "⚙️ Startargumente: {1}`n")
        catalog.Set(
            "⚠️ 升级等待超时",
                "⚠️ Update-Wartezeit überschritten")
        catalog.Set(
            "⚠️ 疑似停止",
                "⚠️ Möglicherweise beendet")
        catalog.Set(
            "⚠️ 运行中（权限不符）",
                "⚠️ Wird ausgeführt（unzureichende Rechte）")
        catalog.Set(
            "✅ 已启动（非驻留目标）",
                "✅ Gestartet（nicht residentes Ziel）")
        catalog.Set(
            "✅ 运行中",
                "✅ Wird ausgeführt")
        catalog.Set(
            "✅ 运行：{1}   🚫 停止：{2}   ⏳ 恢复：{3}   🔄 升级：{4}   ⏸️ 暂停：{5}   ❌ 失效：{6}   ｜   🎯 总计：{7}",
                "✅ Aktiv: {1}   🚫 Beendet: {2}   ⏳ Wartend: {3}   🔄 Update: {4}   ⏸️ Pausiert: {5}   ❌ Ungültig: {6}   ｜   🎯 Gesamt: {7}")
        catalog.Set(
            "✒️ 编辑完整路径（F2）",
                "✒️ Vollständigen Pfad bearbeiten（F2）")
        catalog.Set(
            "确 定",
                "Bestätigen")
        catalog.Set(
            "取 消",
                "Abbrechen")
        catalog.Set(
            "❌ 无法停止原进程",
                "❌ Ursprünglicher Prozess konnte nicht beendet werden")
        catalog.Set(
            "❌ 目标不存在",
                "❌ Das Ziel ist nicht vorhanden")
        catalog.Set(
            "❌ 程序不存在",
                "❌ Das Programm ist nicht vorhanden")
        catalog.Set(
            "❌ 脚本不存在",
                "❌ Das Skript ist nicht vorhanden")
        catalog.Set(
            "➕ 添加",
                "➕ Hinzufügen")
        catalog.Set(
            "。",
                ".")
        catalog.Set(
            "一、快速上手",
                "1. Schnellstart")
        catalog.Set(
            "七、软件升级保护",
                "7. Software-Update-Schutz")
        catalog.Set(
            "三、主界面操作",
                "3. Bedienung des Hauptfensters")
        catalog.Set(
            "不允许的升级保护阶段转换：{1}",
                "Unzulässiger Übergang der Update-Schutzphase: {1}")
        catalog.Set(
            "不支持的启动规格类型",
                "Nicht unterstützter Startkonfigurationstyp")
        catalog.Set(
            "不支持的图标格式",
                "Nicht unterstütztes Symbolformat")
        catalog.Set(
            "不是当前 <HEX> 编码格式",
                "Entspricht nicht dem aktuellen <HEX>-Codierungsformat")
        catalog.Set(
            "与已加载项目重复，或目标格式无效",
                "Doppelter geladener Eintrag oder ungültiges Zielformat")
        catalog.Set(
            "主进程监控",
                "Überwachung des Hauptprozesses")
        catalog.Set(
            "主进程监控异常：{1}",
                "Fehler bei der Überwachung des Hauptprozesses: {1}")
        catalog.Set(
            "二、支持的目标",
                "2. Unterstützte Ziele")
        catalog.Set(
            "五、设置",
                "5. Einstellungen")
        catalog.Set(
            "代码热重载完毕，界面已恢复显示。",
                "Das dynamische Neuladen des Codes ist abgeschlossen`; die Oberfläche wird wieder angezeigt.")
        catalog.Set(
            "仲裁期间捕获到升级活动",
                "Während der Abstimmung wurde Update-Aktivität erkannt")
        catalog.Set(
            "使用说明",
                "Bedienungsanleitung")
        catalog.Set(
            "恢复默认",
                "Zurücksetzen")
        catalog.Set(
            "保存",
                "Speichern")
        catalog.Set(
            "保存升级保护恢复状态失败：{1}",
                "Wiederherstellungsstatus des Update-Schutzes konnte nicht gespeichert werden: {1}")
        catalog.Set(
            "保存失败",
                "Speichern fehlgeschlagen")
        catalog.Set(
            "保存显示设置失败，请查看运行日志。",
                "Anzeigeeinstellungen konnten nicht gespeichert werden. Weitere Informationen enthält das Ausführungsprotokoll.")
        catalog.Set(
            "保存监控配置失败：{1}",
                "Überwachungskonfiguration konnte nicht gespeichert werden: {1}")
        catalog.Set(
            "保存窗口布局失败：{1}",
                "Fensteranordnung konnte nicht gespeichert werden: {1}")
        catalog.Set(
            "保存设置失败，请查看运行日志。",
                "Einstellungen konnten nicht gespeichert werden. Weitere Informationen enthält das Ausführungsprotokoll.")
        catalog.Set(
            "保存软件升级保护设置失败，请查看运行日志。",
                "Einstellungen des Software-Update-Schutzes konnten nicht gespeichert werden. Weitere Informationen enthält das Ausführungsprotokoll.")
        catalog.Set(
            "保存运行参数失败：{1}",
                "Ausführungsparameter konnten nicht gespeichert werden: {1}")
        catalog.Set(
            "值不是 0 或 1",
                "Der Wert ist weder 0 noch 1")
        catalog.Set(
            "停止",
                "Beenden")
        catalog.Set(
            "八、日志与托盘",
                "8. Protokolle und Infobereich")
        catalog.Set(
            "六、版本与小助手自身更新",
                "6. Versionen und Aktualisierung des Assistenten")
        catalog.Set(
            "内容为空",
                "Der Inhalt ist leer")
        catalog.Set(
            "内容无法解析",
                "Der Inhalt kann nicht ausgewertet werden")
        catalog.Set(
            "创建快捷方式失败：{1}",
                "Verknüpfung konnte nicht erstellt werden: {1}")
        catalog.Set(
            "初始化...",
                "Initialisierung...")
        catalog.Set(
            "删除选中的守护项目（支持多选，可撤销）`n快捷键：Delete",
                "Ausgewählte Überwachungseinträge löschen（Mehrfachauswahl und Rückgängig unterstützt）`nTaste: Entf")
        catalog.Set(
            "刷新主窗口状态失败，已暂停界面倒计时刷新：{1}",
                "Status des Hauptfensters konnte nicht aktualisiert werden`; die Aktualisierung des Oberflächen-Countdowns wurde pausiert: {1}")
        catalog.Set(
            "刷新运行日志窗口失败，已暂停自动刷新：{1}",
                "Ausführungsprotokollfenster konnte nicht aktualisiert werden`; die automatische Aktualisierung wurde pausiert: {1}")
        catalog.Set(
            "升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。",
                "Der Update-Schutz unterstützt nur Programme und Skripte mit einem gültigen vollständigen Pfad. Das Installationsverzeichnis muss vorhanden sein und die Zieldatei enthalten.")
        catalog.Set(
            "升级保护仍在进行",
                "Der Update-Schutz ist weiterhin aktiv")
        catalog.Set(
            "升级保护初始化时无法建立进程基线，将在下一轮重试。",
                "Beim Initialisieren des Update-Schutzes konnte kein Prozessausgangszustand erstellt werden`; im nächsten Durchlauf erfolgt ein neuer Versuch.")
        catalog.Set(
            "升级保护协调器未能初始化，核心守护不会启动。",
                "Der Koordinator des Update-Schutzes konnte nicht initialisiert werden`; die Kernüberwachung wird nicht gestartet.")
        catalog.Set(
            "升级保护配置",
                "Konfiguration des Update-Schutzes")
        catalog.Set(
            "升级文件监听",
                "Überwachung der Update-Dateien")
        catalog.Set(
            "升级文件监听异常（{1}）：{2}",
                "Fehler bei der Überwachung der Update-Dateien（{1}）: {2}")
        catalog.Set(
            "升级文件监听异常：{1}",
                "Fehler bei der Überwachung der Update-Dateien: {1}")
        catalog.Set(
            "升级等待已超时",
                "Update-Wartezeit abgelaufen")
        catalog.Set(
            "升级进程扫描",
                "Suche nach Update-Prozessen")
        catalog.Set(
            "升级进程扫描异常：{1}",
                "Fehler bei der Suche nach Update-Prozessen: {1}")
        catalog.Set(
            "参数错误",
                "Parameterfehler")
        catalog.Set(
            "发现小助手新版本：{1}（当前版本：{2}）",
                "Neue Assistentenversion verfügbar: {1}（aktuelle Version: {2}）")
        catalog.Set(
            "发现新版本 {1}，当前版本为 {2}。{3}{3}{4}{3}{3}是否立即更新？",
                "Die neue Version {1} ist verfügbar`; aktuell ist Version {2} installiert.{3}{3}{4}{3}{3}Jetzt aktualisieren?")
        catalog.Set(
            "取消",
                "Abbrechen")
        catalog.Set(
            "名称",
                "Name")
        catalog.Set(
            "后台任务耗时较长：{1}，本次 {2} 毫秒",
                "Eine Hintergrundaufgabe dauerte zu lange: {1}`; dieser Durchlauf benötigte {2} ms")
        catalog.Set(
            "后台扫描进程未返回 PID",
                "Der Hintergrundsuchprozess hat keine PID zurückgegeben")
        catalog.Set(
            "后台调度任务异常（{1}）：{2}",
                "Fehler bei einer geplanten Hintergrundaufgabe（{1}）: {2}")
        catalog.Set(
            "后台进程快照为空或不完整，已忽略本次结果并安排重试。",
                "Die Hintergrundprozess-Momentaufnahme ist leer oder unvollständig`; das Ergebnis wurde ignoriert und ein neuer Versuch eingeplant.")
        catalog.Set(
            "后台进程快照已确认",
                "Hintergrundprozess-Momentaufnahme bestätigt")
        catalog.Set(
            "后台进程快照未及时返回，已等待完整检测窗口",
                "Die Hintergrundprozess-Momentaufnahme traf nicht rechtzeitig ein`; das vollständige Erkennungsfenster wurde abgewartet")
        catalog.Set(
            "启动前没有可用的启动目标，已停止重试：{1}{2}",
                "Vor dem Start ist kein verfügbares Startziel vorhanden`; weitere Versuche wurden beendet: {1}{2}")
        catalog.Set(
            "启动参数",
                "Startargumente")
        catalog.Set(
            "启动参数（Args）：",
                "Startargumente（Args）：")
        catalog.Set(
            "启动器需要 LaunchSpec",
                "Das Startmodul benötigt LaunchSpec")
        catalog.Set(
            "启动失败",
                "Start fehlgeschlagen")
        catalog.Set(
            "启动失败 [{1}/{2}]：{3} - {4}",
                "Start fehlgeschlagen [{1}/{2}]: {3} - {4}")
        catalog.Set(
            "启动成功且运行稳定：{1}",
                "Erfolgreich gestartet und stabil ausgeführt: {1}")
        catalog.Set(
            "启动批量导入失败",
                "Stapelimport konnte nicht gestartet werden")
        catalog.Set(
            "启动时检查小助手更新",
                "Beim Start nach Assistentenupdates suchen")
        catalog.Set(
            "启动时清空批处理日志",
                "Stapelprotokolle beim Start löschen")
        catalog.Set(
            "启动目标不可用",
                "Das Startziel ist nicht verfügbar")
        catalog.Set(
            "启动目标不存在",
                "Das Startziel ist nicht vorhanden")
        catalog.Set(
            "启用状态",
                "Aktivierungsstatus")
        catalog.Set(
            "四、守护与重启",
                "4. Überwachung und Neustart")
        catalog.Set(
            "图标来源无效",
                "Die Symbolquelle ist ungültig")
        catalog.Set(
            "图标来源：",
                "Symbolquelle：")
        catalog.Set(
            "图标缩放器",
                "Symbolskalierung")
        catalog.Set(
            "处理后台进程快照时发生错误：{1}",
                "Fehler beim Verarbeiten der Hintergrundprozess-Momentaufnahme: {1}")
        catalog.Set(
            "处理应用更新结果失败：{1}",
                "Ergebnis der Anwendungsaktualisierung konnte nicht verarbeitet werden: {1}")
        catalog.Set(
            "字段数量应为 {1}，实际为 {2}",
                "Erwartete Feldanzahl: {1}`; tatsächlich: {2}")
        catalog.Set(
            "守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！",
                "Überwachungsvorgänge benötigen erhöhte Lese- und Schreibrechte im System. Führen Sie dieses Programm als Administrator aus.")
        catalog.Set(
            "守护目标：",
                "Überwachtes Ziel：")
        catalog.Set(
            "安全启动门暂缓启动：{1}（{2}）",
                "Die Schutzschranke für sicheren Start hat den Start verschoben: {1}（{2}）")
        catalog.Set(
            "安装目录特征",
                "Merkmale des Installationsverzeichnisses")
        catalog.Set(
            "安装足迹目录：",
                "Installationsverzeichnis：")
        catalog.Set(
            "完整路径",
                "Vollständiger Pfad")
        catalog.Set(
            "完整路径：{1}",
                "Vollständiger Pfad: {1}")
        catalog.Set(
            "导出诊断包",
                "Diagnosepaket exportieren")
        catalog.Set(
            "导出诊断包失败：{1}",
                "Diagnosepaket konnte nicht exportiert werden: {1}")
        catalog.Set(
            "将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。",
                "Das vollständige Veröffentlichungspaket wird heruntergeladen und geprüft. Nach dem Beenden des Assistenten werden die Programmdateien ersetzt und der Assistent automatisch neu gestartet.")
        catalog.Set(
            "将下载并校验源码发行包，保留个人配置后替换源码并自动重启。",
                "Das Quellcodepaket wird heruntergeladen und geprüft. Anschließend wird der Quellcode unter Beibehaltung Ihrer persönlichen Einstellungen ersetzt und der Assistent automatisch neu gestartet.")
        catalog.Set(
            "将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。",
                "Zunächst wird sichergestellt, dass das Quellcoderepository keine nicht übernommenen Änderungen enthält. Danach wird per Fast-Forward zur offiziellen Veröffentlichungsmarke gewechselt und automatisch neu gestartet.")
        catalog.Set(
            "小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。",
                "Der Assistent prüft Programme, Skripte und Verknüpfungen im Hintergrund. Wird ein Ziel unerwartet beendet, startet er es gemäß der eingestellten Wartefolge neu. Das Schließen des Hauptfensters blendet es nur in den Infobereich aus und beendet die Überwachung nicht.")
        catalog.Set(
            "小助手已是最新版本：{1}",
                "Der Assistent ist bereits aktuell: {1}")
        catalog.Set(
            "小助手更新",
                "Assistentenupdate")
        catalog.Set(
            "小助手设置",
                "Assistenteneinstellungen")
        catalog.Set(
            "尚未从真实升级过程学习到更新程序特征。",
                "Es wurden noch keine Merkmale eines Update-Programms aus einem echten Update-Vorgang erlernt.")
        catalog.Set(
            "展示配置",
                "Anzeigekonfiguration")
        catalog.Set(
            "工作目录",
                "Arbeitsverzeichnis")
        catalog.Set(
            "工作目录（CWD）：",
                "Arbeitsverzeichnis（CWD）：")
        catalog.Set(
            "已从本次升级过程学习更新程序特征：{1}",
                "Bei diesem Update erlernte Merkmale des Update-Programms: {1}")
        catalog.Set(
            "已保存身份",
                "Identität gespeichert")
        catalog.Set(
            "已关闭以管理员身份运行：{1}",
                "Ausführung als Administrator deaktiviert: {1}")
        catalog.Set(
            "已创建最高权限的开机自启计划任务（Win10 配置，适配笔记本）。",
                "Eine Autostart-Aufgabe mit höchsten Rechten wurde erstellt（Windows-10-Konfiguration, für Notebooks geeignet）.")
        catalog.Set(
            "已创建桌面与开始菜单快捷方式。",
                "Verknüpfungen auf dem Desktop und im Startmenü wurden erstellt.")
        catalog.Set(
            "已删除自启计划任务。",
                "Die geplante Autostart-Aufgabe wurde gelöscht.")
        catalog.Set(
            "已刷新快捷方式内置参数：{1}",
                "Die integrierten Argumente der Verknüpfung wurden aktualisiert: {1}")
        catalog.Set(
            "已刷新快捷方式真实进程（{1}）：{2} -> {3}",
                "Der tatsächliche Prozess der Verknüpfung wurde aktualisiert（{1}）: {2} -> {3}")
        catalog.Set(
            "已发送启动指令：{1}{2}",
                "Startbefehl gesendet: {1}{2}")
        catalog.Set(
            "已取消监控：{1}",
                "Überwachung aufgehoben: {1}")
        catalog.Set(
            "已启动批处理并重定向输出到：{1}",
                "Stapelprozess gestartet`; Ausgabe wird umgeleitet nach: {1}")
        catalog.Set(
            "已启动非驻留目标：{1}",
                "Nicht residentes Ziel gestartet: {1}")
        catalog.Set(
            "已启用以管理员身份运行：{1}",
                "Ausführung als Administrator aktiviert: {1}")
        catalog.Set(
            "已导出本地诊断包：{1}",
                "Lokales Diagnosepaket exportiert: {1}")
        catalog.Set(
            "已恢复未完成的升级保护会话：{1}",
                "Eine nicht abgeschlossene Update-Schutz-Sitzung wurde wiederhergestellt: {1}")
        catalog.Set(
            "已撤销上一步操作。",
                "Der letzte Vorgang wurde rückgängig gemacht.")
        catalog.Set(
            "已更新主窗口显示设置：{1}",
                "Die Anzeigeeinstellungen des Hauptfensters wurden aktualisiert: {1}")
        catalog.Set(
            "已更新应用程序路径。",
                "Der Anwendungspfad wurde aktualisiert.")
        catalog.Set(
            "已更新软件升级保护设置：{1}",
                "Die Einstellungen des Software-Update-Schutzes wurden aktualisiert: {1}")
        catalog.Set(
            "已添加 {1} 个监控项。",
                "{1} Überwachungseinträge wurden hinzugefügt.")
        catalog.Set(
            "已用完快速重试，将每隔 {1} 秒继续尝试启动：{2}",
                "Die schnellen Versuche sind aufgebraucht`; der Start wird alle {1} Sekunden erneut versucht: {2}")
        catalog.Set(
            "已自动学习的更新程序特征：",
                "Automatisch erlernte Merkmale des Update-Programms:")
        catalog.Set(
            "已进入软件升级保护：{1}{2}",
                "Software-Update-Schutz aktiviert: {1}{2}")
        catalog.Set(
            "已重做操作。",
                "Der Vorgang wurde wiederhergestellt.")
        catalog.Set(
            "常规终止权限不足，已提权终止进程 PID：{1}",
                "Für das reguläre Beenden fehlten die Rechte`; der Prozess mit PID {1} wurde mit erhöhten Rechten beendet")
        catalog.Set(
            "序号",
                "Nr.")
        catalog.Set(
            "应用更新助手不存在",
                "Der Assistent zur Anwendungsaktualisierung ist nicht vorhanden")
        catalog.Set(
            "应用更新参数无效",
                "Ungültige Parameter für die Anwendungsaktualisierung")
        catalog.Set(
            "应用更新安装进程未返回 PID",
                "Der Installationsprozess des Updates hat keine PID zurückgegeben")
        catalog.Set(
            "应用更新本地化资源不存在",
                "Die Lokalisierungsressourcen der Anwendungsaktualisierung sind nicht vorhanden")
        catalog.Set(
            "应用更新检查进程未返回 PID",
                "Der Prozess zur Update-Prüfung hat keine PID zurückgegeben")
        catalog.Set(
            "应用程序",
                "Anwendung")
        catalog.Set(
            "应用资源",
                "Anwendungsressourcen")
        catalog.Set(
            "开机自动启动（计划任务）",
                "Automatisch beim Anmelden starten（geplante Aufgabe）")
        catalog.Set(
            "当前陪伴您的已经是最新版本的小助手啦！",
                "Ihr Assistent ist bereits auf dem neuesten Stand!")
        catalog.Set(
            "当前应用版本无效",
                "Die aktuelle Anwendungsversion ist ungültig")
        catalog.Set(
            "当前版本：{1}（EXE 版；内嵌 AutoHotkey {2} x64）",
                "Aktuelle Version: {1}（EXE-Version`; AutoHotkey {2} x64 eingebettet）")
        catalog.Set(
            "当前版本：{1}（源码版；本机 AutoHotkey {2} x64）",
                "Aktuelle Version: {1}（Quellcodeversion`; lokales AutoHotkey {2} x64）")
        catalog.Set(
            "当前状态：升级活动已结束，正在确认程序文件稳定",
                "Aktueller Status: Die Update-Aktivität ist beendet`; die Stabilität der Programmdateien wird geprüft")
        catalog.Set(
            "当前状态：升级等待超时，需要确认后恢复",
                "Aktueller Status: Die Update-Wartezeit ist abgelaufen`; zum Fortsetzen ist eine Bestätigung erforderlich")
        catalog.Set(
            "当前状态：已从上次运行恢复未完成的升级保护",
                "Aktueller Status: Der nicht abgeschlossene Update-Schutz des vorherigen Durchlaufs wurde wiederhergestellt")
        catalog.Set(
            "当前状态：已暂停自动启动，正在等待升级完成",
                "Aktueller Status: Der automatische Start ist pausiert, bis das Update abgeschlossen ist")
        catalog.Set(
            "当前状态：显式升级维护已开始，正在等待结束命令",
                "Aktueller Status: Die ausdrückliche Update-Wartung wurde begonnen`; der Abschlussbefehl wird erwartet")
        catalog.Set(
            "当前状态：正在判断本次退出是否由升级引起",
                "Aktueller Status: Es wird geprüft, ob dieses Beenden durch ein Update ausgelöst wurde")
        catalog.Set(
            "当前状态：正常守护",
                "Aktueller Status: normale Überwachung")
        catalog.Set(
            "快捷方式参数",
                "Verknüpfungsargumente")
        catalog.Set(
            "快捷方式及已解析目标均不可用",
                "Sowohl die Verknüpfung als auch das aufgelöste Ziel sind nicht verfügbar")
        catalog.Set(
            "快捷方式目标",
                "Verknüpfungsziel")
        catalog.Set(
            "快捷方式真实目标",
                "Tatsächliches Verknüpfungsziel")
        catalog.Set(
            "快捷方式真实进程刷新被拒绝，目标已由其它项目守护：{1} -> {2}",
                "Aktualisierung des tatsächlichen Verknüpfungsprozesses abgelehnt, da das Ziel bereits von einem anderen Eintrag überwacht wird: {1} -> {2}")
        catalog.Set(
            "恢复守护：{1}",
                "Überwachung fortsetzen: {1}")
        catalog.Set(
            "恢复记录列表无效",
                "Ungültige Liste von Wiederherstellungsdatensätzen")
        catalog.Set(
            "恢复记录无效",
                "Ungültiger Wiederherstellungsdatensatz")
        catalog.Set(
            "恢复记录缺少字段：{1}",
                "Im Wiederherstellungsdatensatz fehlt ein Feld: {1}")
        catalog.Set(
            "成功",
                "Erfolgreich")
        catalog.Set(
            "所选文件夹内未找到支持的程序、脚本或快捷方式。",
                "Im ausgewählten Ordner wurden keine unterstützten Programme, Skripte oder Verknüpfungen gefunden.")
        catalog.Set(
            "手动添加监控：{1}",
                "Überwachung manuell hinzugefügt: {1}")
        catalog.Set(
            "手动触发了重新启动：{1}",
                "Neustart manuell ausgelöst: {1}")
        catalog.Set(
            "手动重启已取消，原进程未能停止：{1}",
                "Der manuelle Neustart wurde abgebrochen, da der ursprüngliche Prozess nicht beendet werden konnte: {1}")
        catalog.Set(
            "托管窗口生命周期尚未配置",
                "Der Lebenszyklus des verwalteten Fensters wurde noch nicht eingerichtet")
        catalog.Set(
            "托管窗口生命周期适配器无效",
                "Ungültiger Adapter für den Lebenszyklus des verwalteten Fensters")
        catalog.Set(
            "扩展设置包含无效数值。`n`n窗口程序关闭等待：1-300 秒`n命令行程序退出等待：1-60 秒`n日志条数：50-10000`n日志保留：1-3650 天",
                "Mindestens eine erweiterte Einstellung ist ungültig.`n`nWartezeit beim Schließen von Fensterprogrammen: 1-300 Sekunden`nWartezeit beim Beenden von Befehlszeilenprogrammen: 1-60 Sekunden`nProtokolleinträge: 50-10000`nProtokollaufbewahrung: 1-3650 Tage")
        catalog.Set(
            "批处理启动需要输出日志路径",
                "Zum Starten eines Stapelprozesses ist ein Pfad für das Ausgabeprotokoll erforderlich")
        catalog.Set(
            "批量导入中断",
                "Stapelimport unterbrochen")
        catalog.Set(
            "批量导入完成",
                "Stapelimport abgeschlossen")
        catalog.Set(
            "批量导入已取消，已保留并保存此前添加的 {1} 个监控项。",
                "Der Stapelimport wurde abgebrochen. Die zuvor hinzugefügten {1} Überwachungseinträge wurden beibehalten und gespeichert.")
        catalog.Set(
            "拒绝修改路径，真实进程已由其它项目守护：{1}",
                "Pfadänderung abgelehnt, da der tatsächliche Prozess bereits von einem anderen Eintrag überwacht wird: {1}")
        catalog.Set(
            "拒绝将应用路径改为已存在的监控项：{1}",
                "Änderung des Anwendungspfads abgelehnt, da bereits ein Überwachungseintrag dafür vorhanden ist: {1}")
        catalog.Set(
            "按钮绘制器",
                "Schaltflächen-Renderer")
        catalog.Set(
            "捕获监控项历史失败：{1}",
                "Verlauf der Überwachungseinträge konnte nicht erfasst werden: {1}")
        catalog.Set(
            "提示",
                "Hinweis")
        catalog.Set(
            "⚡️搜索⚡️",
                "⚡️ Suche ⚡️")
        catalog.Set(
            "操作计划任务时发生错误！`n`n{1}",
                "Beim Bearbeiten der geplanten Aufgabe ist ein Fehler aufgetreten.`n`n{1}")
        catalog.Set(
            "支持的图标与图片",
                "Unterstützte Symbole und Bilder")
        catalog.Set(
            "支持的程序、脚本与快捷方式",
                "Unterstützte Programme, Skripte und Verknüpfungen")
        catalog.Set(
            "支持的程序与脚本",
                "Unterstützte Programme und Skripte")
        catalog.Set(
            "收到显式维护开始命令",
                "Ausdrücklicher Befehl zum Beginn der Wartung empfangen")
        catalog.Set(
            "收到显式维护结束命令，开始执行安全恢复检查：{1}",
                "Ausdrücklicher Befehl zum Ende der Wartung empfangen`; Prüfung für sicheres Fortsetzen beginnt: {1}")
        catalog.Set(
            "整条展示配置",
                "Vollständige Anzeigekonfiguration")
        catalog.Set(
            "整条记录",
                "Vollständiger Datensatz")
        catalog.Set(
            "文件稳定等待（秒）：",
                "Wartezeit für Dateistabilität（Sekunden）：")
        catalog.Set(
            "新脚本未通过 AutoHotkey 解析检查",
                "Das neue Skript hat die AutoHotkey-Syntaxprüfung nicht bestanden")
        catalog.Set(
            "无法从损坏记录中提取",
                "Aus dem beschädigten Datensatz konnten keine Daten extrahiert werden")
        catalog.Set(
            "无法停止进程 PID：{1}{2}",
                "Prozess mit PID {1} konnte nicht beendet werden{2}")
        catalog.Set(
            "无法写入诊断文件：{1}",
                "Diagnosedatei konnte nicht geschrieben werden: {1}")
        catalog.Set(
            "无法启动后台文件扫描：{1}",
                "Hintergrund-Dateisuche konnte nicht gestartet werden: {1}")
        catalog.Set(
            "无法启动后台进程快照任务：{1}",
                "Aufgabe für die Hintergrundprozess-Momentaufnahme konnte nicht gestartet werden: {1}")
        catalog.Set(
            "无法启动小助手更新安装：{1}",
                "Installation des Assistentenupdates konnte nicht gestartet werden: {1}")
        catalog.Set(
            "无法启动小助手更新检查：{1}",
                "Prüfung auf Assistentenupdates konnte nicht gestartet werden: {1}")
        catalog.Set(
            "无法导出诊断包：`n{1}",
                "Diagnosepaket konnte nicht exportiert werden:`n{1}")
        catalog.Set(
            "无法建立单实例运行锁，小助手将退出。",
                "Die Sperre für eine einzelne Instanz konnte nicht eingerichtet werden`; der Assistent wird beendet.")
        catalog.Set(
            "无法开始更新：{1}",
                "Update konnte nicht gestartet werden: {1}")
        catalog.Set(
            "无法收集此部分诊断信息：{1}",
                "Dieser Teil der Diagnoseinformationen konnte nicht erfasst werden: {1}")
        catalog.Set(
            "无法检查更新：{1}",
                "Updates konnten nicht geprüft werden: {1}")
        catalog.Set(
            "无法清理后台扫描临时文件：{1}",
                "Temporäre Datei der Hintergrundsuche konnte nicht bereinigt werden: {1}")
        catalog.Set(
            "无法清理后台扫描结果文件：{1}",
                "Ergebnisdatei der Hintergrundsuche konnte nicht bereinigt werden: {1}")
        catalog.Set(
            "无法生成监控项快照：{1}",
                "Momentaufnahme der Überwachungseinträge konnte nicht erstellt werden: {1}")
        catalog.Set(
            "日志",
                "Protokoll")
        catalog.Set(
            "日志文件不存在：{1}",
                "Die Protokolldatei ist nicht vorhanden: {1}")
        catalog.Set("📄 查看批处理输出日志", "📄 Batch-Ausgabeprotokoll anzeigen")
        catalog.Set("尚未生成批处理输出日志", "Noch kein Batch-Ausgabeprotokoll vorhanden")
        catalog.Set(
            "小助手只有在启动 BAT 或 CMD 项目时才会创建此文件。",
                "Diese Datei wird nur erstellt, wenn der Assistent einen BAT- oder CMD-Eintrag startet.")
        catalog.Set("日志保存位置：", "Speicherort des Protokolls:")
        catalog.Set("确定", "OK")
        catalog.Set(
            "时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间",
                "Die Zeiteinstellungen sind ungültig.`n`nAusgangserkennungszeitraum: 2-120 Sekunden`nWartezeit für Dateistabilität: 2-300 Sekunden`nMaximale Update-Wartezeit: 60-86400 Sekunden und größer als die Stabilitätswartezeit")
        catalog.Set(
            "显式升级维护命令执行异常：{1}",
                "Fehler beim Ausführen des ausdrücklichen Update-Wartungsbefehls: {1}")
        catalog.Set(
            "显式升级维护命令未找到监控目标：{1}",
                "Der ausdrückliche Update-Wartungsbefehl hat kein überwachtes Ziel gefunden: {1}")
        catalog.Set(
            "显式升级维护命令被忽略，目标未启用升级保护：{1}",
                "Der ausdrückliche Update-Wartungsbefehl wurde ignoriert, da der Update-Schutz für das Ziel nicht aktiviert ist: {1}")
        catalog.Set(
            "显示主界面",
                "Hauptoberfläche anzeigen")
        catalog.Set(
            "显示名称：",
                "Anzeigename：")
        catalog.Set(
            "暂停守护：{1}",
                "Überwachung pausieren: {1}")
        catalog.Set(
            "暂停或恢复选中项目的守护，不会退出目标`n支持多选；混合状态时逐项反转",
                "Überwachung der ausgewählten Einträge pausieren oder fortsetzen, ohne die Ziele zu beenden`nMehrfachauswahl unterstützt`; bei gemischten Zuständen wird jeder einzeln umgekehrt")
        catalog.Set(
            "暂时无法查询进程状态，稍后重试手动重启：{1}",
                "Der Prozessstatus kann vorübergehend nicht abgefragt werden`; der manuelle Neustart wird später erneut versucht: {1}")
        catalog.Set(
            "暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                "Vorhandene Prozesse können vorübergehend nicht geprüft werden`; der Start wird verzögert, um doppelte Instanzen zu vermeiden: {1}")
        catalog.Set(
            "暂时无法重新启动",
                "Neustart ist vorübergehend nicht möglich")
        catalog.Set(
            "更新助手已启动，小助手即将退出并完成更新。",
                "Der Update-Assistent wurde gestartet. Der Assistent wird nun beendet, um das Update abzuschließen.")
        catalog.Set(
            "更新应用搜索结果失败：{1}",
                "Anwendungssuchergebnisse konnten nicht aktualisiert werden: {1}")
        catalog.Set(
            "更新检查未返回结果",
                "Die Update-Prüfung hat kein Ergebnis geliefert")
        catalog.Set(
            "更新检查正在进行，请稍候。",
                "Eine Update-Prüfung wird bereits ausgeführt. Bitte warten.")
        catalog.Set(
            "更新检查返回了无法识别的状态：{1}",
                "Die Update-Prüfung hat einen unbekannten Status zurückgegeben: {1}")
        catalog.Set(
            "最长升级等待（秒）：",
                "Maximale Update-Wartezeit（Sekunden）：")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），恢复普通重启流程：{3}",
                "Keine Update-Aktivität erkannt（{1}, Dauer {2} Sekunden）`; der normale Neustartablauf wird fortgesetzt: {3}")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），目标仍不存在：{3}",
                "Keine Update-Aktivität erkannt（{1}, Dauer {2} Sekunden）und das Ziel fehlt weiterhin: {3}")
        catalog.Set(
            "未找到目标",
                "Ziel nicht gefunden")
        catalog.Set(
            "未添加",
                "Nicht hinzugefügt")
        catalog.Set(
            "未知升级保护阶段",
                "Unbekannte Update-Schutzphase")
        catalog.Set(
            "未知守护阶段",
                "Unbekannte Überwachungsphase")
        catalog.Set(
            "未知版本",
                "Unbekannte Version")
        catalog.Set(
            "未知解析错误",
                "Unbekannter Auswertungsfehler")
        catalog.Set(
            "未知错误",
                "Unbekannter Fehler")
        catalog.Set(
            "查看实时运行日志`n涵盖监控、重启、升级保护与操作记录",
                "Ausführungsprotokoll in Echtzeit anzeigen`nUmfasst Überwachung, Neustarts, Update-Schutz und Bedienvorgänge")
        catalog.Set(
            "查看支持类型、操作方法、守护设置`n以及升级保护说明",
                "Unterstützte Typen, Bedienung und Überwachungseinstellungen anzeigen`nEinschließlich Erläuterungen zum Update-Schutz")
        catalog.Set(
            "核心守护",
                "Kernüberwachung")
        catalog.Set(
            "核心守护计时器启动失败。",
                "Der Zeitgeber der Kernüberwachung konnte nicht gestartet werden.")
        catalog.Set(
            "桌面与开始菜单快捷方式",
                "Verknüpfungen auf dem Desktop und im Startmenü")
        catalog.Set(
            "创建桌面快捷方式，并将小助手加入开始菜单“所有”列表；是否固定到开始菜单由您决定。",
                "Erstellt eine Desktopverknüpfung und fügt den Assistenten unter „Alle Apps“ im Startmenü hinzu. Ob er an „Start“ angeheftet wird, entscheiden Sie selbst.")
        catalog.Set(
            "创建成功！",
                "Erstellt!")
        catalog.Set(
            "检查小助手更新",
                "Nach Assistentenupdates suchen")
        catalog.Set(
            "检查小助手更新失败：{1}",
                "Suche nach Assistentenupdates fehlgeschlagen: {1}")
        catalog.Set(
            "检查更新",
                "Nach Updates suchen")
        catalog.Set(
            "立即检查更新",
                "Jetzt nach Updates suchen")
        catalog.Set(
            "检查更新失败：{1}",
                "Update-Suche fehlgeschlagen: {1}")
        catalog.Set(
            "检查更新超时",
                "Zeitüberschreitung bei der Update-Suche")
        catalog.Set(
            "检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。",
                "Eine gleichnamige geplante Aufgabe wurde erkannt, aber nicht von diesem Programm erstellt. Um ein versehentliches Löschen zu vermeiden, bearbeiten Sie sie zunächst in der Aufgabenplanung.")
        catalog.Set(
            "检测到安装目录变化",
                "Änderung des Installationsverzeichnisses erkannt")
        catalog.Set(
            "检测到相关安装进程",
                "Zugehöriger Installationsprozess erkannt")
        catalog.Set(
            "检测到程序文件变化",
                "Änderung der Programmdateien erkannt")
        catalog.Set(
            "检测到运行中的目标未使用管理员权限：{1}",
                "Das laufende Ziel verwendet keine Administratorrechte: {1}")
        catalog.Set(
            "检测到进程停止，准备重启：{1}（将在 {2} 秒后启动）",
                "Prozessbeendigung erkannt`; Neustart wird vorbereitet: {1}（Start in {2} Sekunden）")
        catalog.Set(
            "正在扫描...",
                "Suche läuft...")
        catalog.Set(
            "正在扫描文件夹，可点击取消停止",
                "Ordner wird durchsucht`; klicken Sie zum Beenden auf „Abbrechen“")
        catalog.Set(
            "正在扫描：{1}",
                "Suche läuft: {1}")
        catalog.Set(
            "正在添加扫描结果...",
                "Suchergebnisse werden hinzugefügt...")
        catalog.Set(
            "正在添加：{1} / {2}",
                "Hinzufügen: {1} / {2}")
        catalog.Set(
            "正常关闭超时后允许强制终止",
                "Erzwungenes Beenden nach Zeitüberschreitung beim regulären Beenden zulassen")
        catalog.Set(
            "正常关闭超时，已强制终止进程 PID：{1}",
                "Zeitüberschreitung beim regulären Beenden`; Prozess mit PID {1} wurde zwangsweise beendet")
        catalog.Set(
            "正常关闭超时，已按设置跳过强制终止 PID：{1}",
                "Zeitüberschreitung beim regulären Beenden`; das erzwungene Beenden von PID {1} wurde gemäß der Einstellung übersprungen")
        catalog.Set(
            "没有可安装的应用更新",
                "Kein installierbares Anwendungsupdate vorhanden")
        catalog.Set(
            "浏览",
                "Durchsuchen")
        catalog.Set(
            "添加扫描结果失败",
                "Suchergebnisse konnten nicht hinzugefügt werden")
        catalog.Set(
            "添加监控项",
                "Überwachungseintrag hinzufügen")
        catalog.Set(
            "添加监控项失败，已回滚内存状态：{1}",
                "Überwachungseintrag konnte nicht hinzugefügt werden`; der Speicherzustand wurde zurückgesetzt: {1}")
        catalog.Set(
            "添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放",
                "Programm, Skript oder Verknüpfung hinzufügen`nUnterstützt Suche, Ordner-Stapelimport und das Ablegen von Dateien")
        catalog.Set(
            "清除记录",
                "Einträge löschen")
        catalog.Set(
            "状态",
                "Status")
        catalog.Set(
            "独立环境配置 💡`n",
                "Eigene Umgebungskonfiguration 💡`n")
        catalog.Set(
            "环境变量",
                "Umgebungsvariablen")
        catalog.Set(
            "环境变量（每行一个 KEY=VALUE）：",
                "Umgebungsvariablen（eine Angabe KEY=VALUE pro Zeile）：")
        catalog.Set(
            "用户指定",
                "Benutzerdefiniert")
        catalog.Set(
            "用户结束了升级等待，重新执行安全启动检查：{1}",
                "Der Benutzer hat die Update-Wartezeit beendet`; die sichere Startprüfung wird erneut ausgeführt: {1}")
        catalog.Set(
            "界面语言和字体已即时更新，无需重新启动小助手。",
                "Sprache und Schriftart der Oberfläche wurden sofort aktualisiert; ein Neustart des Assistenten ist nicht erforderlich.")
        catalog.Set(
            "更新配置注释语言失败：{1}",
                "Die Sprache der Konfigurationskommentare konnte nicht aktualisiert werden: {1}")
        catalog.Set(
            "；恢复配置失败：{1}",
                "; auch das Wiederherstellen der Konfiguration ist fehlgeschlagen: {1}")
        catalog.Set(
            "界面显示设置无法即时应用，已恢复原语言和字体：{1}",
                "Die Anzeigeeinstellungen konnten nicht sofort angewendet werden. Die vorherige Sprache und Schriftart wurden wiederhergestellt: {1}")
        catalog.Set(
            "无法即时切换界面语言或字体，原显示设置已恢复。`n`n{1}",
                "Sprache oder Schriftart der Oberfläche konnten nicht sofort geändert werden. Die vorherigen Anzeigeeinstellungen wurden wiederhergestellt.`n`n{1}")
        catalog.Set(
            "显示设置应用失败",
                "Anzeigeeinstellungen konnten nicht angewendet werden")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Standardschrift der Sprache verwenden（{1}）")
        catalog.Set(
            "正在检查更新…",
                "Suche nach Updates…")
        catalog.Set(
            "`; UiFont：界面字体；auto 表示使用当前语言的默认字体，也可填写本机已安装字体名称。",
                "`; UiFont: Oberflächenschriftart. auto verwendet die Standardschrift der aktuellen Sprache`; alternativ kann der Name einer installierten Schrift angegeben werden.")
        catalog.Set(
            "界面语言：",
                "Oberflächensprache：")
        catalog.Set(
            "界面资源",
                "Oberflächenressourcen")
        catalog.Set(
            "监控与启动",
                "Überwachung und Start")
        catalog.Set(
            "监控目标重复",
                "Doppeltes Überwachungsziel")
        catalog.Set(
            "监控配置加载异常",
                "Fehler beim Laden der Überwachungskonfiguration")
        catalog.Set(
            "监控配置加载异常：共 {1} 条记录未能载入。",
                "Fehler beim Laden der Überwachungskonfiguration: {1} Datensätze konnten nicht geladen werden.")
        catalog.Set(
            "监控配置尚未保存，请查看运行日志。",
                "Die Überwachungskonfiguration wurde noch nicht gespeichert. Weitere Informationen enthält das Ausführungsprotokoll.")
        catalog.Set(
            "监控项保存状态无效",
                "Ungültiger Speicherstatus des Überwachungseintrags")
        catalog.Set(
            "监控项注册回调无效",
                "Ungültiger Rückruf zur Registrierung des Überwachungseintrags")
        catalog.Set(
            "监控项路径无效：{1}",
                "Ungültiger Pfad des Überwachungseintrags: {1}")
        catalog.Set(
            "监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核：{1}",
                "Die Zieldatei ist nicht mehr vorhanden. Die Überwachung befindet sich nun im Zustand „Datei fehlt“ und prüft sie nach ihrer Rückkehr automatisch erneut: {1}")
        catalog.Set(
            "目标任务需要 WatchdogScheduler",
                "Die Zielaufgabe benötigt WatchdogScheduler")
        catalog.Set(
            "目标文件已恢复，重新核对运行状态：{1}",
                "Die Zieldatei ist wieder vorhanden`; der Ausführungsstatus wird erneut geprüft: {1}")
        catalog.Set(
            "目标文件缺失时检测到升级活动",
                "Update-Aktivität erkannt, während die Zieldatei fehlte")
        catalog.Set(
            "目标程序文件不存在",
                "Die Zieldatei des Programms ist nicht vorhanden")
        catalog.Set(
            "目标程序：{1}",
                "Zielprogramm: {1}")
        catalog.Set(
            "目标路径",
                "Zielpfad")
        catalog.Set(
            "目标退出时检测到升级信号",
                "Beim Beenden des Ziels wurde ein Update-Signal erkannt")
        catalog.Set(
            "真实目标来源标记",
                "Kennzeichnung der Quelle des tatsächlichen Ziels")
        catalog.Set(
            "真实进程路径无效",
                "Der Pfad des tatsächlichen Prozesses ist ungültig")
        catalog.Set(
            "确 定",
                "Bestätigen")
        catalog.Set(
            "程序文件刚刚发生变化",
                "Die Programmdatei wurde gerade geändert")
        catalog.Set(
            "程序文件尚未达到稳定等待时间",
                "Die Programmdatei hat die erforderliche Stabilitätsdauer noch nicht erreicht")
        catalog.Set(
            "程序文件正在写入或结构不完整",
                "Die Programmdatei wird geschrieben oder ihre Struktur ist unvollständig")
        catalog.Set(
            "稍后",
                "Später")
        catalog.Set(
            "窗口层级平台适配器无效",
                "Ungültiger Plattformadapter für die Fensterhierarchie")
        catalog.Set(
            "窗口层级管理器无效",
                "Ungültiger Verwalter der Fensterhierarchie")
        catalog.Set(
            "窗口布局字段不是整数：{1}",
                "Das Feld der Fensteranordnung ist keine ganze Zahl: {1}")
        catalog.Set(
            "窗口布局字段超出范围：{1}",
                "Das Feld der Fensteranordnung liegt außerhalb des gültigen Bereichs: {1}")
        catalog.Set(
            "窗口布局对象无效",
                "Ungültiges Objekt der Fensteranordnung")
        catalog.Set(
            "立即更新",
                "Jetzt aktualisieren")
        catalog.Set(
            "等待 {1} 秒后进行第 {2} 次尝试...",
                "Vor Versuch {2} noch {1} Sekunden warten...")
        catalog.Set(
            "管理员运行状态",
                "Status der Ausführung als Administrator")
        catalog.Set(
            "系统 PowerShell 不可用",
                "System-PowerShell ist nicht verfügbar")
        catalog.Set(
            "系统压缩工具未能创建诊断包",
                "Das Komprimierungswerkzeug des Systems konnte kein Diagnosepaket erstellen")
        catalog.Set(
            "系统权限拦截",
                "Durch Systemberechtigungen blockiert")
        catalog.Set(
            "通用",
                "Allgemein")
        catalog.Set(
            "结束升级等待并恢复守护",
                "Update-Wartezeit beenden und Überwachung fortsetzen")
        catalog.Set(
            "编码损坏",
                "Beschädigte Codierung")
        catalog.Set(
            "缺少窗口布局字段：{1}",
                "Feld der Fensteranordnung fehlt: {1}")
        catalog.Set(
            "缺少窗口生命周期回调：{1}",
                "Rückruf für den Fensterlebenszyklus fehlt: {1}")
        catalog.Set(
            "缺少诊断信息提供器：{1}",
                "Anbieter von Diagnoseinformationen fehlt: {1}")
        catalog.Set(
            "缺少运行参数：{1}",
                "Ausführungsparameter fehlt: {1}")
        catalog.Set(
            "自动",
                "Automatisch")
        catalog.Set(
            "自动识别升级并保护启动过程",
                "Updates automatisch erkennen und den Startvorgang schützen")
        catalog.Set(
            "自动识别进程",
                "Prozess automatisch erkennen")
        catalog.Set(
            "自定义名称",
                "Benutzerdefinierter Name")
        catalog.Set(
            "自定义图标",
                "Benutzerdefiniertes Symbol")
        catalog.Set(
            "计划任务冲突",
                "Konflikt mit geplanter Aufgabe")
        catalog.Set(
            "计划任务操作失败：{1}",
                "Vorgang für geplante Aufgabe fehlgeschlagen: {1}")
        catalog.Set(
            "设置已更新：轮询={1}ms，序列=[{2}]，日志上限={3}",
                "Einstellungen aktualisiert: Abfrage={1}ms, Folge=[{2}], Protokollgrenze={3}")
        catalog.Set(
            "设置无效",
                "Ungültige Einstellungen")
        catalog.Set(
            "诊断临时目录已存在",
                "Das temporäre Diagnoseverzeichnis ist bereits vorhanden")
        catalog.Set(
            "诊断包保存目录不存在",
                "Das Zielverzeichnis des Diagnosepakets ist nicht vorhanden")
        catalog.Set(
            "诊断包已导出到：`n{1}",
                "Diagnosepaket exportiert nach:`n{1}")
        catalog.Set(
            "诊断包目标文件名已被占用",
                "Der Zieldateiname des Diagnosepakets ist bereits belegt")
        catalog.Set(
            "诊断压缩包未生成",
                "Das komprimierte Diagnosepaket wurde nicht erstellt")
        catalog.Set(
            "该文件不是受支持的图标或图片格式。`n`n支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。",
                "Diese Datei hat kein unterstütztes Symbol- oder Bildformat.`n`nUnterstützt werden ICO, EXE, DLL, CPL, LNK, PNG, JPG, JPEG, JPE, JFIF, BMP, GIF, TIF, TIFF, WebP, SVG und ANI.")
        catalog.Set(
            "该目标已存在、无效或指向目录。",
                "Dieses Ziel ist bereits vorhanden, ungültig oder verweist auf einen Ordner.")
        catalog.Set(
            "该真实进程已由其他监控项守护。",
                "Dieser tatsächliche Prozess wird bereits von einem anderen Überwachungseintrag geschützt.")
        catalog.Set(
            "该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。",
                "Diese Software befindet sich im Update-Schutz. Warten Sie, bis das Update abgeschlossen ist, oder beenden Sie die Wartezeit unter „Software-Update-Schutz“, bevor Sie sie neu starten.")
        catalog.Set(
            "语义版本无效",
                "Ungültige semantische Version")
        catalog.Set(
            "请通过上方按钮搜索或选择，或在下方填写进程名或目标路径：`n【支持程序、脚本、快捷方式，以及文件夹批量导入】",
                "Nutzen Sie oben die Suche oder Auswahl.`nOder geben Sie unten einen Prozessnamen bzw. Zielpfad ein.`n【Programme, Skripte, Verknüpfungen und Ordner-Stapelimport】")
        catalog.Set(
            "请选择现有且可执行的真实程序或脚本路径。",
                "Wählen Sie einen vorhandenen und ausführbaren Pfad eines tatsächlichen Programms oder Skripts.")
        catalog.Set(
            "请选择现有的图标、程序、资源库或快捷方式文件。",
                "Wählen Sie eine vorhandene Symbol-, Programm-, Ressourcenbibliotheks- oder Verknüpfungsdatei.")
        catalog.Set(
            "读取后台扫描结果失败",
                "Ergebnisse der Hintergrundsuche konnten nicht gelesen werden")
        catalog.Set(
            "调度器已停止",
                "Der Planer wurde angehalten")
        catalog.Set(
            "跟随系统",
                "Systemeinstellung übernehmen")
        catalog.Set(
            "路径",
                "Pfad")
        catalog.Set(
            "轮询间隔必须为 500-86400000 毫秒的正整数！",
                "Das Abfrageintervall muss eine positive ganze Zahl zwischen 500 und 86400000 Millisekunden sein.")
        catalog.Set(
            "软件升级保护",
                "Software-Update-Schutz")
        catalog.Set(
            "软件升级保护超过最长等待时间，需要用户确认后恢复：{1}",
                "Der Software-Update-Schutz hat die maximale Wartezeit überschritten`; zum Fortsetzen ist eine Bestätigung erforderlich: {1}")
        catalog.Set(
            "软件升级完成，准备恢复启动：{1}",
                "Das Softwareupdate ist abgeschlossen`; die Fortsetzung des Starts wird vorbereitet: {1}")
        catalog.Set(
            "软件升级完成，已恢复正常守护：{1}",
                "Das Softwareupdate ist abgeschlossen`; die normale Überwachung wurde fortgesetzt: {1}")
        catalog.Set(
            "载入中...",
                "Wird geladen...")
        catalog.Set(
            "运行参数不是支持的界面语言：{1}",
                "Der Ausführungsparameter ist keine unterstützte Oberflächensprache: {1}")
        catalog.Set(
            "运行参数不是整数：{1}",
                "Der Ausführungsparameter ist keine ganze Zahl: {1}")
        catalog.Set(
            "运行参数不能为空：{1}",
                "Der Ausführungsparameter darf nicht leer sein: {1}")
        catalog.Set(
            "运行参数对象无效",
                "Ungültiges Objekt der Ausführungsparameter")
        catalog.Set(
            "运行参数超出范围：{1}",
                "Der Ausführungsparameter liegt außerhalb des gültigen Bereichs: {1}")
        catalog.Set(
            "运行日志",
                "Ausführungsprotokoll")
        catalog.Set(
            "进程仍在运行，忽略重复启动：{1}",
                "Der Prozess wird noch ausgeführt`; ein doppelter Start wird ignoriert: {1}")
        catalog.Set(
            "进程启动后迅速退出或未成功常驻后台",
                "Der Prozess wurde kurz nach dem Start beendet oder konnte nicht dauerhaft im Hintergrund ausgeführt werden")
        catalog.Set(
            "进程守护小助手",
                "Prozessüberwachungs-Assistent")
        catalog.Set(
            "持续守护重要程序与自动化任务，让日常工作稳定运行",
                "Hält wichtige Anwendungen und Automatisierungen zuverlässig am Laufen")
        catalog.Set(
            "进程守护小助手 - 开机自启守护程序",
                "Prozessüberwachungs-Assistent - Autostart-Überwachung")
        catalog.Set(
            "进程守护小助手已静默启动。",
                "Der Prozessüberwachungs-Assistent wurde im Hintergrund gestartet.")
        catalog.Set(
            "退出检测窗口（秒）：",
                "Ausgangserkennungszeitraum（Sekunden）：")
        catalog.Set(
            "退出清理异常（{1}）：{2}",
                "Fehler bei der Bereinigung beim Beenden（{1}）: {2}")
        catalog.Set(
            "退出程序",
                "Programm beenden")
        catalog.Set(
            "选择主窗口图标",
                "Symbol des Hauptfensters auswählen")
        catalog.Set(
            "选择工作目录",
                "Arbeitsverzeichnis auswählen")
        catalog.Set(
            "选择快捷方式对应的真实进程",
                "Tatsächlichen Prozess der Verknüpfung auswählen")
        catalog.Set(
            "选择批处理日志目录",
                "Verzeichnis für Stapelprotokolle auswählen")
        catalog.Set(
            "选择文件",
                "Datei auswählen")
        catalog.Set(
            "选择文件夹",
                "Ordner auswählen")
        catalog.Set(
            "选择要监控的文件",
                "Zu überwachende Datei auswählen")
        catalog.Set(
            "选择要监控的文件夹",
                "Zu überwachenden Ordner auswählen")
        catalog.Set(
            "选择诊断包保存位置",
                "Speicherort des Diagnosepakets auswählen")
        catalog.Set(
            "选择软件安装目录",
                "Installationsverzeichnis der Software auswählen")
        catalog.Set(
            "通过拖拽添加了 {1} 个监控项。",
                "{1} Überwachungseinträge wurden per Drag-and-drop hinzugefügt.")
        catalog.Set(
            "配置仓储无效",
                "Ungültiges Konfigurationsrepository")
        catalog.Set(
            "配置写入器无效",
                "Ungültiger Konfigurationsschreiber")
        catalog.Set(
            "配置文件写入事务正在进行",
                "Eine Transaktion zum Schreiben der Konfigurationsdatei wird ausgeführt")
        catalog.Set(
            "配置通用、监控与启动、停止`n以及日志选项",
                "Allgemein, Überwachung und Start, Beenden`nsowie Protokoll konfigurieren")
        catalog.Set(
            "重新加载",
                "Neu laden")
        catalog.Set(
            "重新加载失败",
                "Neuladen fehlgeschlagen")
        catalog.Set(
            "重新加载失败，已保留当前实例：{1}",
                "Neuladen fehlgeschlagen`; die aktuelle Instanz wurde beibehalten: {1}")
        catalog.Set(
            "重新加载失败，当前守护仍在运行。`n`n{1}",
                "Neuladen fehlgeschlagen`; die aktuelle Überwachung läuft weiter.`n`n{1}")
        catalog.Set(
            "重试序列不能为空！",
                "Die Wiederholungsfolge darf nicht leer sein.")
        catalog.Set(
            "重试序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "Das Format der Wiederholungsfolge ist ungültig. Geben Sie durch Kommas getrennte positive ganze Zahlen an（z. B. 1,10,60）, jeweils zwischen 1 und 86400 Sekunden.")
        catalog.Set(
            "重试延迟序列不能为空",
                "Die Folge der Wiederholungsverzögerungen darf nicht leer sein")
        catalog.Set(
            "重试延迟序列无效",
                "Ungültige Folge der Wiederholungsverzögerungen")
        catalog.Set(
            "错误",
                "Fehler")
        catalog.Set(
            "项目名称：{1}`n真实路径：{2}",
                "Eintragsname: {1}`nTatsächlicher Pfad: {2}")
        catalog.Set(
            "🌿 环境变量：{1} 项`n",
                "🌿 Umgebungsvariablen: {1}`n")
        catalog.Set(
            "🎨 自定义名称和图标",
                "🎨 Name und Symbol anpassen")
        catalog.Set(
            "📁 工作目录：{1}`n",
                "📁 Arbeitsverzeichnis: {1}`n")
        catalog.Set(
            "📂 打开所在位置",
                "📂 Speicherort öffnen")
        catalog.Set(
            "📂 浏览文件夹...",
                "📂 Ordner durchsuchen...")
        catalog.Set(
            "选择...",
                "Auswählen...")
        catalog.Set(
            "📄 查看运行日志",
                "📄 Ausführungsprotokoll anzeigen")
        catalog.Set(
            "📄 浏览文件...",
                "📄 Datei durchsuchen...")
        catalog.Set(
            "🔄 反转状态",
                "🔄 Status umkehren")
        catalog.Set(
            "🔄 恢复升级保护状态",
                "🔄 Wiederhergestellter Update-Schutzstatus")
        catalog.Set(
            "🔄 显式升级维护中",
                "🔄 Ausdrückliche Update-Wartung läuft")
        catalog.Set(
            "🔄 检查",
                "🔄 Prüfen")
        catalog.Set(
            "🔄 等待程序文件可用",
                "🔄 Warten auf verfügbare Programmdatei")
        catalog.Set(
            "🔄 等待程序文件恢复",
                "🔄 Warten auf Wiederherstellung der Programmdatei")
        catalog.Set(
            "🔄 软件升级中",
                "🔄 Softwareupdate läuft")
        catalog.Set(
            "🔄 软件升级保护",
                "🔄 Software-Update-Schutz")
        catalog.Set(
            "🔄 重新启动",
                "🔄 Neu starten")
        catalog.Set(
            "搜索...",
                "Suchen...")
        catalog.Set(
            "搜索：",
                "Suchen：")
        catalog.Set(
            "扩展名",
                "Dateiendung")
        catalog.Set(
            "🗑️ 删除",
                "🗑️ Löschen")
        catalog.Set(
            "🚀 正在启动...",
                "🚀 Wird gestartet...")
        catalog.Set(
            "🛡️ 以管理员身份运行",
                "🛡️ Als Administrator ausführen")
        catalog.Set(
            "（{1}）",
                "（{1}）")
        catalog.Set(
            "（第 {1} 行）",
                "（Zeile {1}）")
        catalog.Set(
            "（管理员权限）",
                "（Administratorrechte）")
        catalog.Set(
            "：{1}",
                "：{1}")
        catalog.Set(
            "Everything 搜索不可用，请确认 Everything 正在运行。",
                "Die Everything-Suche ist nicht verfügbar. Stellen Sie sicher, dass Everything ausgeführt wird.")
        catalog.Set(
            "正在载入 Everything 搜索结果：{1}／{2}",
                "Everything-Suchergebnisse werden geladen: {1}/{2}")
        catalog.Set(
            "Everything 搜索结果：{1} 项",
                "Everything-Suchergebnisse: {1} Einträge")
        catalog.Set("{1}（EXE 版）", "{1}（EXE-Version）")
        catalog.Set("{1}（源码版）", "{1}（Quellcode-Version）")
        catalog.Set("• “关于”页可控制是否在启动时后台检查新版，也可随时手动检查。检查过程不会阻塞主界面。", "• Auf der Seite „Info“ lässt sich die Suche nach neuen Versionen beim Start im Hintergrund aktivieren oder jederzeit manuell ausführen. Die Prüfung blockiert das Hauptfenster nicht.")
        catalog.Set("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• „Neu starten“ fordert das Ziel zunächst zum normalen Beenden auf. Nach Ablauf des Zeitlimits bestimmt die Option unter „Beendigungsrichtlinie“, ob es zwangsweise beendet wird.")
        catalog.Set("• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。", "• Info: Anwendungsversion und AutoHotkey-Laufzeitumgebung anzeigen, manuell nach Updates suchen oder das Open-Source-Projekt öffnen.")
        catalog.Set("• 监控与启动：设置进程状态检查间隔、崩溃自动重启延迟序列，以及导入文件夹时是否包含子目录。", "• Überwachung & Start: Prüfintervall für Prozesse, Verzögerungsfolge für automatische Neustarts nach einem Absturz und Einbeziehung von Unterordnern beim Ordnerimport festlegen.")
        catalog.Set("• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。", "• Wird ein Ziel als beendet erkannt, bestätigt der Assistent zunächst dessen Zustand und versucht es dann gemäß der „Verzögerungsfolge für automatische Neustarts nach einem Absturz“ erneut. Bei wiederholten Fehlern verhindern die folgenden Verzögerungen zu häufige Neustarts.")
        catalog.Set("• 界面语言和内容字体保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Nach dem Speichern der Oberflächensprache oder Inhaltsschriftart werden Hauptfenster, Menüs und Infobereich sofort und ohne Neustart aktualisiert.")
        catalog.Set("• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。", "• Protokolle: Anzeigelimit des Laufzeitprotokolls, Speicherort und Aufbewahrungsdauer der Stapelausgabeprotokolle sowie die Bereinigung beim Start festlegen.")
        catalog.Set("• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。", "• Beendigungsrichtlinie: Zeitlimits zum Beenden von GUI- und CLI-Anwendungen festlegen und bestimmen, ob nach Überschreitung des normalen Beendens zwangsweise beendet werden darf.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时是否显示主窗口，以及界面语言和内容字体。", "• Allgemein: Verknüpfungen auf Desktop und im Startmenü erstellen, den Start über eine geplante Aufgabe ein- oder ausschalten, die Anzeige des Hauptfensters beim Start wählen sowie Oberflächensprache und Inhaltsschriftart festlegen.")
        catalog.Set("• 小助手版本与 AutoHotkey 版本彼此独立；“关于”页会分别显示当前小助手版本、运行形态和实际运行时版本。", "• Die Versionen des Assistenten und von AutoHotkey sind voneinander unabhängig. Die Seite „Info“ zeigt die aktuelle Assistentenversion, die Auslieferungsform und die tatsächlich verwendete Laufzeitversion getrennt an.")
        catalog.Set("CLI 程序关闭超时（秒）：", "Zeitlimit zum Beenden von CLI-Anwendungen（Sekunden）:")
        catalog.Set("GUI 程序关闭超时（秒）：", "Zeitlimit zum Beenden von GUI-Anwendungen（Sekunden）:")
        catalog.Set("崩溃自动重启延迟序列（秒）：", "Neustartverzögerungen nach einem Absturz（Sekunden）:")
        catalog.Set("崩溃自动重启延迟序列不能为空！", "Die Verzögerungsfolge für automatische Neustarts nach einem Absturz darf nicht leer sein!")
        catalog.Set("崩溃自动重启延迟序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。", "Die Verzögerungsfolge für automatische Neustarts nach einem Absturz ist ungültig! Geben Sie durch Kommas getrennte positive Ganzzahlen ein（zum Beispiel: 1,10,60）, jeweils zwischen 1 und 86400 Sekunden.")
        catalog.Set("当前版本：", "Aktuelle Version:")
        catalog.Set("导入文件夹时包含子目录", "Unterordner beim Importieren eines Ordners einbeziehen")
        catalog.Set("开源地址", "Open-Source-Projekt")
        catalog.Set("关于", "Info")
        catalog.Set("界面内容字体：", "Schriftart für Oberflächeninhalte:")
        catalog.Set("进程状态检查间隔（毫秒）：", "Prüfintervall für Prozesse（Millisekunden）:")
        catalog.Set("进程状态检查间隔必须为 500-86400000 毫秒的正整数！", "Das Prüfintervall für Prozesse muss eine positive Ganzzahl zwischen 500 und 86400000 Millisekunden sein!")
        catalog.Set("扩展设置包含无效数值。`n`nGUI 程序关闭超时：1-300 秒`nCLI 程序关闭超时：1-60 秒`n运行日志显示上限：50-10000 条`n批处理日志保留天数：1-3650 天", "Die erweiterten Einstellungen enthalten ungültige Werte.`n`nZeitlimit für GUI-Anwendungen: 1-300 Sekunden`nZeitlimit für CLI-Anwendungen: 1-60 Sekunden`nAnzeigelimit des Laufzeitprotokolls: 50-10000 Einträge`nAufbewahrung der Stapelausgabeprotokolle: 1-3650 Tage")
        catalog.Set("配置通用、监控与启动、停止策略、日志`n以及关于选项", "Allgemein, Überwachung & Start, Beendigungsrichtlinie,`nProtokolle und Info konfigurieren")
        catalog.Set("批处理日志保存路径：", "Speicherort der Stapelausgabeprotokolle:")
        catalog.Set("批处理日志保留天数：", "Aufbewahrung der Stapelausgabeprotokolle（Tage）:")
        catalog.Set("启动时显示主窗口", "Hauptfenster beim Start anzeigen")
        catalog.Set("设置已更新：进程检查间隔={1}ms，重启延迟序列=[{2}]，日志显示上限={3}", "Einstellungen aktualisiert: Prozessintervall={1} ms, Neustartverzögerungen=[{2}], Protokoll-Anzeigelimit={3}")
        catalog.Set("停止策略", "Beendigungsrichtlinie")
        catalog.Set("运行环境：", "Laufzeitumgebung:")
        catalog.Set("运行日志显示上限（条）：", "Anzeigelimit des Laufzeitprotokolls（Einträge）:")
        catalog.Set("; Theme：界面主题；auto 表示跟随 Windows 系统，light 表示浅色，dark 表示深色。", "; Theme: Oberflächendesign`; auto übernimmt die Windows-Einstellung, light verwendet das helle und dark das dunkle Design.")
        catalog.Set("主题：", "Design:")
        catalog.Set("浅色", "Hell")
        catalog.Set("深色", "Dunkel")
        catalog.Set("运行参数不是支持的界面主题：{1}", "Die Laufzeiteinstellung enthält kein unterstütztes Oberflächendesign: {1}")
        catalog.Set("界面显示设置无法即时应用，已恢复原语言、字体和主题：{1}", "Die Anzeigeeinstellungen konnten nicht sofort angewendet werden; Sprache, Schriftart und Design wurden auf die vorherigen Werte zurückgesetzt: {1}")
        catalog.Set("无法即时切换界面语言、字体或主题，原显示设置已恢复。`n`n{1}", "Sprache, Schriftart oder Design der Oberfläche konnten nicht sofort gewechselt werden. Die vorherigen Anzeigeeinstellungen wurden wiederhergestellt.`n`n{1}")
        catalog.Set("界面语言、字体和主题已即时更新，无需重新启动小助手。", "Sprache, Schriftart und Design der Oberfläche wurden sofort aktualisiert; ein Neustart des Assistenten ist nicht erforderlich.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。", "• Allgemein: Desktop- und Startmenüverknüpfungen erstellen, den geplanten Autostart ein- oder ausschalten, die Anzeige des Hauptfensters und die Updateprüfung beim Start festlegen sowie Sprache, Inhaltsschriftart und Design auswählen.")
        catalog.Set("• 界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Nach dem Speichern von Sprache, Inhaltsschriftart oder Design werden Hauptfenster, Menüs und Infobereich sofort ohne Neustart aktualisiert.")
        catalog.Set("打开帮助信息`n可选择查看使用说明、运行日志或提交反馈", "Hilfe öffnen`nBenutzerhandbuch oder Laufzeitprotokoll öffnen oder Feedback senden")
        catalog.Set("支持开源项目`n可使用微信支付或支付宝扫码捐赠", "Open-Source-Projekt unterstützen`nÜber WeChat Pay oder Alipay spenden")
        catalog.Set("帮助信息", "Hilfe")
        catalog.Set("提交反馈", "Feedback senden")
        catalog.Set("支持开源项目", "Open-Source-Projekt unterstützen")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n进程守护小助手持续保持开源，项目的长期维护有赖于您的支持和鼓励~", "Wenn Ihnen der Assistent Zeit bei der Fehlersuche und Wiederherstellung von Programmen erspart hat, unterstützen Sie den Autor gern über die QR-Codes unten!`nProcess Watchdog bleibt dauerhaft Open Source; die langfristige Pflege des Projekts ist auf Ihre Unterstützung und Ermutigung angewiesen.")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "QR-Code-Bild nicht gefunden")
        catalog.Set("• 主界面的“帮助信息”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。", "• Öffnen Sie Hilfe im Hauptfenster, um das Benutzerhandbuch, das Laufzeitprotokoll dieser Sitzung oder die Feedbackseite des Projekts aufzurufen. Das Protokoll enthält Überwachung, Neustarts, Update-Schutz und Benutzeraktionen und wird automatisch aktualisiert.")
        catalog.Set("⚙️ 进程识别与启动设置", "⚙️ Prozesserkennung und Starteinstellungen")
        catalog.Set("进程识别与启动设置", "Prozesserkennung und Starteinstellungen")
        catalog.Set("进程识别", "Prozesserkennung")
        catalog.Set("启动环境", "Startumgebung")
        catalog.Set("快捷方式仍用于启动；真实进程用于判断程序是否正在运行。", "Die Verknüpfung bleibt der Starteinstieg; anhand des tatsächlichen Prozesses wird ermittelt, ob die Anwendung läuft.")
        catalog.Set("该项目直接启动并监控同一个目标，无需额外识别真实进程。", "Dieser Eintrag startet und überwacht direkt dasselbe Ziel, daher ist keine gesonderte Erkennung des tatsächlichen Prozesses erforderlich.")
        catalog.Set("用于判断运行状态的真实进程：", "Tatsächlicher Prozess für die Statusprüfung:")
        catalog.Set("用于判断运行状态的目标：", "Ziel für die Statusprüfung:")
        catalog.Set("重新识别", "Erneut erkennen")
        catalog.Set("选择程序", "Programm auswählen")
        catalog.Set("识别依据：{1}", "Erkennungsquelle: {1}")
        catalog.Set("识别依据：暂无可靠结果", "Erkennungsquelle: kein verlässliches Ergebnis")
        catalog.Set("识别状态：路径有效。", "Erkennungsstatus: Der Pfad ist gültig.")
        catalog.Set("识别状态：路径暂时不可用，已保留上次可靠结果。", "Erkennungsstatus: Der Pfad ist vorübergehend nicht verfügbar; das letzte verlässliche Ergebnis wurde beibehalten.")
        catalog.Set("识别状态：路径暂时不可用，将保留此身份等待恢复。", "Erkennungsstatus: Der Pfad ist vorübergehend nicht verfügbar; diese Identität bleibt bis zur Wiederherstellung erhalten.")
        catalog.Set("识别状态：未找到可靠目标，请改为手动指定。", "Erkennungsstatus: Es wurde kein verlässliches Ziel gefunden. Geben Sie es manuell an.")
        catalog.Set("识别状态：手动指定，保存时将验证路径。", "Erkennungsstatus: Manuell angegeben; der Pfad wird beim Speichern geprüft.")
        catalog.Set("识别状态：启动入口与监控目标一致。", "Erkennungsstatus: Starteinstieg und überwachtes Ziel sind identisch.")
        catalog.Set("这些设置仅在小助手下次启动目标时生效，不会重启当前进程。", "Diese Einstellungen gelten beim nächsten Start des Ziels durch den Assistenten und starten den bereits laufenden Prozess nicht neu.")
        catalog.Set("留空时使用快捷方式工作目录或程序所在目录。", "Leer lassen, um den Arbeitsordner der Verknüpfung oder den Programmordner zu verwenden.")
        catalog.Set("留空时不附加额外参数。", "Leer lassen, um keine zusätzlichen Argumente anzuhängen.")
        catalog.Set("留空时继承小助手当前环境。", "Leer lassen, um die aktuelle Umgebung des Assistenten zu übernehmen.")
        catalog.Set("工作目录不存在或不可访问：{1}", "Der Arbeitsordner ist nicht vorhanden oder nicht zugänglich: {1}")
        catalog.Set("工作目录无效", "Ungültiger Arbeitsordner")
        catalog.Set("环境变量第 {1} 行缺少等号（KEY=VALUE）。", "In Zeile {1} der Umgebungsvariablen fehlt ein Gleichheitszeichen（KEY=VALUE）.")
        catalog.Set("环境变量第 {1} 行的名称无效：{2}", "Zeile {1} der Umgebungsvariablen enthält einen ungültigen Namen: {2}")
        catalog.Set("环境变量第 {1} 行重复定义了 {2}。", "In Zeile {1} der Umgebungsvariablen wird {2} erneut definiert.")
        catalog.Set("环境变量配置无法解析。", "Die Konfiguration der Umgebungsvariablen konnte nicht ausgewertet werden.")
        catalog.Set("环境变量配置无效", "Ungültige Umgebungsvariablen")
        catalog.Set("设置已应用到当前运行，但暂未写入配置文件；小助手将在后台自动重试。", "Die Einstellungen sind in dieser Sitzung bereits aktiv, wurden aber noch nicht in die Konfigurationsdatei geschrieben. Der Assistent versucht es im Hintergrund automatisch erneut.")
        catalog.Set("配置暂未写入", "Konfiguration noch nicht geschrieben")
        catalog.Set("已更新进程识别与启动设置：{1}", "Prozesserkennung und Starteinstellungen wurden aktualisiert: {1}")
        catalog.Set("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。", "• Verknüpfungen: LNK, URL und APPREF-MS, einschließlich MSI-Verknüpfungen, deren tatsächliches Ziel ermittelt werden kann. Bei besonderen Verknüpfungen können Sie den tatsächlichen Prozess unter Prozesserkennung und Starteinstellungen manuell angeben.")
        catalog.Set("• 右键项目可自定义主窗口名称和图标，也可打开所在位置、重新启动、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。要求管理员运行但当前权限不符时会显示警告；右键重新启动会按该设置提权启动。", "• Klicken Sie mit der rechten Maustaste auf einen Eintrag, um seinen Namen und sein Symbol im Hauptfenster anzupassen, den Speicherort zu öffnen, ihn neu zu starten, den Pfad zu bearbeiten, den Administratorstart umzuschalten, Prozesserkennung, Starteinstellungen und Updateschutz zu konfigurieren oder das Ausgabeprotokoll von Batchdateien anzuzeigen. Wenn Administratorrechte verlangt werden, der laufende Prozess aber nicht erhöht ist, erscheint eine Warnung; ein Neustart über das Kontextmenü startet das Programm entsprechend dieser Einstellung mit erhöhten Rechten.")
        catalog.Set("添加", "Hinzufügen")
        catalog.Set("暂停", "Pausieren")
        catalog.Set("恢复", "Fortsetzen")
        catalog.Set("删除", "Löschen")
        catalog.Set("设置", "Einstellungen")
        catalog.Set("捐赠", "Spenden")
        catalog.Set("保存", "Speichern")
        catalog.Set("取消", "Abbrechen")
        catalog.Set("反转状态", "Status umkehren")
        catalog.Set("统计：运行", "In Betrieb")
        catalog.Set("统计：停止", "Beendet")
        catalog.Set("统计：恢复", "Wird wiederhergestellt")
        catalog.Set("统计：升级", "Wird aktualisiert")
        catalog.Set("统计：暂停", "Pausiert")
        catalog.Set("统计：失效", "Ungültig")
        catalog.Set("统计：总计", "Gesamt")
        catalog.Set("配置未保存", "Konfiguration nicht gespeichert")
        catalog.Set("创建", "Erstellen")
        catalog.Set("开启", "Einschalten")
        catalog.Set("关闭", "Ausschalten")
        catalog.Set("切换", "Umschalten")
        catalog.Set("冲突", "Konflikt")
        catalog.Set("浏览", "Durchsuchen")
        catalog.Set("监控配置", "Überwachungskonfiguration")
        catalog.Set("管理员运行状态", "Als Administrator ausführen")
        catalog.Set("调整守护顺序", "Überwachungsliste neu anordnen")
        catalog.Set("编辑完整路径", "Vollständigen Pfad bearbeiten")
        catalog.Set("自定义名称和图标", "Name und Symbol anpassen")
        catalog.Set("已撤销：{1}", "Rückgängig gemacht: {1}")
        catalog.Set("已重做：{1}", "Wiederholt: {1}")
        catalog.Set("Everything 搜索暂时不可用，请稍后重试。", "Die Everything-Suche ist vorübergehend nicht verfügbar. Versuchen Sie es später erneut.")
        catalog.Set("Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。", "Die Everything-Suchkomponente fehlt oder konnte nicht geladen werden. Entpacken Sie den Assistenten vollständig oder installieren Sie ihn erneut.")
        catalog.Set("已找到 Everything，但无法后台启动，请手动启动后重试。", "Everything wurde gefunden, konnte aber nicht im Hintergrund gestartet werden. Starten Sie es manuell und versuchen Sie es erneut.")
        catalog.Set("后台启动 Everything 失败：{1}", "Everything konnte nicht im Hintergrund gestartet werden: {1}")
        catalog.Set("正在后台启动 Everything 并等待搜索服务就绪...", "Everything wird im Hintergrund gestartet; der Suchdienst wird vorbereitet...")
        catalog.Set("已在后台启动 Everything：{1}", "Everything wurde im Hintergrund gestartet: {1}")
        catalog.Set("等待 Everything 搜索服务就绪超时：{1}", "Zeitüberschreitung beim Warten auf den Everything-Suchdienst: {1}")
        catalog.Set("未找到 Everything，点击前往官网下载最新版：{1}", "Everything wurde nicht gefunden. Klicken Sie hier, um die neueste Version von der offiziellen Website herunterzuladen: {1}")
        catalog.Set("本机未找到 Everything；程序搜索需要 Everything 后台服务。", "Everything wurde auf diesem Computer nicht gefunden; die Programmsuche benötigt den Everything-Hintergrunddienst.")
        catalog.Set("• 程序搜索：使用 Everything 服务并显示全部匹配结果；未运行时会尝试在本机查找并后台启动，未找到时提供官网最新版下载地址。", "• Programmsuche: Verwendet den Everything-Dienst und zeigt alle Treffer an. Wenn Everything nicht läuft, sucht der Assistent es auf diesem Computer und startet es im Hintergrund; wird es nicht gefunden, erscheint der offizielle Downloadlink zur neuesten Version.")
        catalog.Set("• 小助手随包的 Everything64.dll 只是连接 Everything 后台实例的 SDK 客户端，不负责扫描磁盘或建立索引，不能替代 Everything 本体。", "• Die mitgelieferte Everything64.dll ist lediglich ein SDK-Client, der eine Verbindung zur Everything-Hintergrundinstanz herstellt. Sie durchsucht keine Datenträger, erstellt keinen Index und ersetzt nicht die Everything-Anwendung.")
        catalog.Set("六、进程识别与启动设置", "6. Prozesserkennung und Starteinstellungen")
        catalog.Set("• 此设置只作用于当前守护项，并将“用什么启动”和“用什么判断正在运行”分开处理。启动环境只在小助手下次启动目标时生效，不会重启当前进程。", "• Diese Einstellungen gelten nur für den aktuellen Überwachungseintrag und trennen die Startmethode von den Merkmalen, mit denen ein laufender Prozess erkannt wird. Die Startumgebung gilt erst beim nächsten Start des Ziels durch den Assistenten und startet den aktuellen Prozess nicht neu.")
        catalog.Set("• 直接添加程序或脚本时，启动入口与监控目标相同；EXE 按完整路径识别，脚本按宿主进程命令行中的脚本路径识别。", "• Wird ein Programm oder Skript direkt hinzugefügt, sind Starteintrag und Überwachungsziel identisch. EXE-Dateien werden anhand des vollständigen Pfads erkannt, Skripte anhand des Skriptpfads in der Befehlszeile des Hostprozesses.")
        catalog.Set("• 添加 LNK 快捷方式时，快捷方式始终作为启动入口；自动识别出的真实程序或脚本只用于判断运行状态。", "• Bei einer LNK-Verknüpfung bleibt die Verknüpfung stets der Starteintrag. Das automatisch ermittelte tatsächliche Programm oder Skript dient nur zur Erkennung des Ausführungszustands.")
        catalog.Set("• 自动识别会综合快捷方式目标、参数、Windows Installer 信息、安装目录、文件版本信息和已观察进程；证据不唯一时不会随意绑定。", "• Die automatische Erkennung berücksichtigt Ziel und Argumente der Verknüpfung, Windows-Installer-Daten, Installationsordner, Dateiversionsinformationen und beobachtete Prozesse. Bei uneindeutigen Anhaltspunkten wird kein Ziel willkürlich gebunden.")
        catalog.Set("• 自动结果不正确时改用“用户指定”，选择程序正常运行期间持续存在的主程序或脚本；不要选择启动器、更新器或短暂子进程。", "• Ist das automatische Ergebnis falsch, wählen Sie Benutzerdefiniert und geben Sie das Hauptprogramm oder Skript an, das während des normalen Betriebs dauerhaft vorhanden ist. Wählen Sie keinen Launcher, Updater oder kurzlebigen untergeordneten Prozess.")
        catalog.Set("启动程序或解释器：", "Startprogramm oder Interpreter:")
        catalog.Set("留空时按目标类型自动启动；可选择 Python、AutoHotkey、PowerShell、Node.js、Java 等运行时。", "Leer lassen, um entsprechend dem Zieltyp zu starten, oder eine Laufzeitumgebung wie Python, AutoHotkey, PowerShell, Node.js oder Java auswählen.")
        catalog.Set("启动程序参数：", "Argumente des Startprogramms:")
        catalog.Set("参数顺序为：启动程序参数、目标路径、目标参数；例如 Java 使用 -jar。", "Die Reihenfolge lautet: Argumente des Startprogramms, Zielpfad, Zielargumente. Für Java wird beispielsweise -jar verwendet.")
        catalog.Set("目标参数（Args）：", "Zielargumente（Args）:")
        catalog.Set("留空时继承小助手当前环境；值中可用 %变量名% 引用已有环境变量。", "Leer lassen, um die aktuelle Umgebung des Assistenten zu übernehmen. Mit %VARIABLE% kann in einem Wert auf eine vorhandene Umgebungsvariable verwiesen werden.")
        catalog.Set("选择启动程序或解释器", "Startprogramm oder Interpreter auswählen")
        catalog.Set("可执行程序", "Ausführbare Programme")
        catalog.Set("请先选择启动程序或解释器，再填写它的参数。", "Wählen Sie zuerst ein Startprogramm oder einen Interpreter aus und geben Sie anschließend dessen Argumente ein.")
        catalog.Set("启动程序未设置", "Startprogramm nicht festgelegt")
        catalog.Set("启动程序或解释器不存在：{1}", "Das Startprogramm oder der Interpreter ist nicht vorhanden: {1}")
        catalog.Set("启动程序无效", "Ungültiges Startprogramm")
        catalog.Set("整条启动配置", "gesamte Startkonfiguration")
        catalog.Set("启动程序或解释器", "Startprogramm oder Interpreter")
        catalog.Set("解释器参数", "Interpreterargumente")
        catalog.Set("• 直接脚本可指定“启动程序或解释器”，选择实际执行脚本的可执行文件，例如 Python、AutoHotkey、PowerShell、Node.js、Ruby、Perl、PHP、Lua、Java 或 Bash；留空时沿用系统默认启动方式。", "• Für ein direkt hinzugefügtes Skript kann unter Startprogramm oder Interpreter die ausführbare Datei gewählt werden, die das Skript tatsächlich ausführt, etwa Python, AutoHotkey, PowerShell, Node.js, Ruby, Perl, PHP, Lua, Java oder Bash. Bleibt das Feld leer, wird die Standardstartmethode des Systems verwendet.")
        catalog.Set("• “启动程序参数”位于目标路径之前，“目标参数（Args）”位于目标路径之后。Java 可填写 -jar；PowerShell 可填写 -NoProfile -ExecutionPolicy Bypass -File。", "• Die Argumente des Startprogramms stehen vor dem Zielpfad, die Zielargumente（Args）danach. Für Java kann -jar verwendet werden; für PowerShell -NoProfile -ExecutionPolicy Bypass -File.")
        catalog.Set("• Python 虚拟环境请选择该环境的 Scripts\python.exe；其他语言也可选择项目要求的确切运行时版本。进程识别仍以目标脚本路径为准，不会误把解释器本身当成守护目标。", "• Wählen Sie für eine virtuelle Python-Umgebung deren Scripts\python.exe aus. Auch bei anderen Sprachen kann genau die vom Projekt benötigte Laufzeitversion gewählt werden. Die Prozesserkennung richtet sich weiterhin nach dem Pfad des Zielskripts, sodass der Interpreter selbst nicht mit dem Überwachungsziel verwechselt wird.")
        catalog.Set("• 工作目录（CWD）用于解析相对路径；留空时使用快捷方式工作目录或目标所在目录。", "• Das Arbeitsverzeichnis（CWD）dient zum Auflösen relativer Pfade. Bleibt es leer, wird das Arbeitsverzeichnis der Verknüpfung oder der Ordner des Ziels verwendet.")
        catalog.Set("• 环境变量每行填写一个 KEY=VALUE，只覆盖列出的变量；值中可用 %变量名% 引用已有环境变量。启动完成后小助手会恢复自身环境。", "• Geben Sie pro Zeile eine Umgebungsvariable im Format KEY=VALUE ein. Nur die aufgeführten Variablen werden überschrieben; mit %VARIABLE% kann auf einen vorhandenen Wert verwiesen werden. Nach dem Start stellt der Assistent seine eigene Umgebung wieder her.")
        catalog.Set("; AppN 与 [Apps] 中同名项目一一对应，依次保存启动程序或解释器路径及其参数。", "; Jeder AppN-Eintrag entspricht dem gleichnamigen Eintrag unter [Apps] und speichert nacheinander den Pfad des Startprogramms oder Interpreters sowie dessen Argumente.")
        catalog.Set("; 两个字段均为 <HEX> 编码；留空时由小助手按目标类型使用默认启动方式。", "; Beide Felder sind als <HEX> codiert. Sind sie leer, verwendet der Assistent die Standardstartmethode des jeweiligen Zieltyps.")
        return catalog
    }
}

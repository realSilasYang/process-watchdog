; it-IT 本地化词条目录。
; 本目录由模型直接依据简体中文稳定键逐条翻译；生成步骤仅处理转义与格式。

class ItalianStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Premi")
        catalog.Set(
            "`n位置：{1}",
                "`nPosizione: {1}")
        catalog.Set(
            "`r`n      影响：该守护对象本次未加入守护列表。",
                "`r`n      Conseguenza: questo elemento non è stato aggiunto all'elenco di monitoraggio.")
        catalog.Set(
            "`r`n      目标：{1}",
                "`r`n      Destinazione: {1}")
        catalog.Set(
            "`r`n      问题：{1}：{2}",
                "`r`n      Problema: {1}: {2}")
        catalog.Set(
            "`r`n  [{1}] 位置：[{2}] {3}",
                "`r`n  [{1}] Posizione: [{2}] {3}")
        catalog.Set(
            "`r`n  处理建议：确认目标路径后，可在主界面重新添加该守护对象；也可退出小助手后检查上述配置位置。后续保存配置时，损坏记录会转存到 [Recovery]，不会被静默删除。",
                "`r`n  Intervento consigliato: verificare il percorso di destinazione e aggiungere di nuovo l'elemento dalla finestra principale. È anche possibile chiudere l'assistente e controllare la posizione di configurazione indicata sopra. Al prossimo salvataggio, i record danneggiati verranno spostati in [Recovery] e non eliminati senza preavviso.")
        catalog.Set(
            "`r`n  配置文件：{1}",
                "`r`n  File di configurazione: {1}")
        catalog.Set(
            "   ⚠️ 配置未保存",
                "   ⚠️ Configurazione non salvata")
        catalog.Set(
            "  --maintenance-begin `"目标完整路径`"    开始维护",
                "  --maintenance-begin `"percorso completo della destinazione`"    Avvia manutenzione")
        catalog.Set(
            "  --maintenance-end `"目标完整路径`"      结束维护",
                "  --maintenance-end `"percorso completo della destinazione`"      Termina manutenzione")
        catalog.Set(
            " 已保留并保存此前添加的 {1} 个守护对象。",
                " Sono stati mantenuti e salvati i {1} elementi di monitoraggio aggiunti in precedenza.")
        catalog.Set(
            " 扫描达到时间或数量上限，结果已截断。",
                " La scansione ha raggiunto il limite di tempo o di risultati`; i risultati sono stati troncati.")
        catalog.Set(
            "`; AllowForceTerminate：正常退出超时后是否允许强制结束进程。",
                "`; AllowForceTerminate: indica se è consentito terminare forzatamente il processo allo scadere dell'attesa per l'uscita normale.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应，值为软件升级保护的 <HEX> 编码结构。",
                "`; Ogni AppN corrisponde all'elemento omonimo in [Apps]`; il valore contiene la struttura di protezione degli aggiornamenti codificata come <HEX>.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应；留空时使用目标自身的名称和图标。",
                "`; Ogni AppN corrisponde all'elemento omonimo in [Apps]`; gli elementi vuoti usano il nome e l'icona della destinazione.")
        catalog.Set(
            "`; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。",
                "`; CheckInterval: intervallo di controllo dello stato in millisecondi`; valori da 500 a 86400000.")
        catalog.Set(
            "`; CheckUpdatesOnStartup：启动后是否在后台检查小助手新版。",
                "`; CheckUpdatesOnStartup: indica se cercare in background una nuova versione dell'assistente dopo l'avvio.")
        catalog.Set(
            "`; ClearLogsOnStartup：启动时是否清空历史日志。",
                "`; ClearLogsOnStartup: indica se cancellare i registri precedenti all'avvio.")
        catalog.Set(
            "`; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col1W: larghezza della prima colonna dell'elenco principale, salvata in pixel logici a 96 DPI.")
        catalog.Set(
            "`; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col2W: larghezza della seconda colonna dell'elenco principale, salvata in pixel logici a 96 DPI.")
        catalog.Set(
            "`; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。",
                "`; CtrlCWaitSeconds: attesa massima, in secondi, dopo che un programma da riga di comando riceve Ctrl+C`; valori da 1 a 60.")
        catalog.Set(
            "`; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。",
                "`; GracefulStopSeconds: attesa massima, in secondi, per la chiusura normale di un programma con finestra`; valori da 1 a 300.")
        catalog.Set(
            "`; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。",
                "`; GuiH: altezza della finestra principale, salvata in pixel logici a 96 DPI.")
        catalog.Set(
            "`; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。",
                "`; GuiW: larghezza della finestra principale, salvata in pixel logici a 96 DPI.")
        catalog.Set(
            "`; LogDirectory：留空时使用系统临时目录下的 ProcessWatchdogLogs。",
                "`; LogDirectory: se vuoto, viene usata la cartella ProcessWatchdogLogs nella directory temporanea di sistema.")
        catalog.Set(
            "`; LogMaxEntries：日志界面保留条数，范围 50～10000。",
                "`; LogMaxEntries: numero di voci mantenute nella finestra del registro`; valori da 50 a 10000.")
        catalog.Set(
            "`; LogRetentionDays：日志文件保留天数，范围 1～3650。",
                "`; LogRetentionDays: giorni di conservazione dei file di registro`; valori da 1 a 3650.")
        catalog.Set(
            "`; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。",
                "`; RecursiveBatchImport: indica se esaminare le sottocartelle durante l'importazione in blocco di una cartella.")
        catalog.Set(
            "`; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。",
                "`; RetrySequence: attese prima del riavvio, in secondi e separate da virgole`; massimo 10 valori, ciascuno da 1 a 86400.")
        catalog.Set(
            "`; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。",
                "`; ShowAfterReload: indicatore interno di ricaricamento`; torna automaticamente a 0 al termine.")
        catalog.Set(
            "`; ShowAtStartup：启动后是否显示主窗口。",
                "`; ShowAtStartup: indica se mostrare la finestra principale dopo l'avvio.")
        catalog.Set(
            "`; UiLanguage：界面语言；auto 表示跟随系统，也可填写受支持的语言代码。",
                "`; UiLanguage: lingua dell'interfaccia`; auto segue il sistema, ma è anche possibile specificare un codice lingua supportato.")
        catalog.Set(
            "`; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。",
                "`; Salva solo il nome visualizzato e l'origine dell'icona nella finestra principale`; non influisce sul riconoscimento del processo, sull'avvio o sulla protezione degli aggiornamenti.")
        catalog.Set(
            "`; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
                "`; I campi interni includono Enabled, RootIsCustom, DetectionSeconds, StableSeconds, MaxWaitSeconds, InstallRoot e Actor.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。",
                "`; I valori booleani usano 1 per attivare e 0 per disattivare`; è consigliabile modificarli dalla finestra delle impostazioni.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。",
                "`; I valori booleani usano 1 per attivare e 0 per disattivare`; il programma codifica e decodifica automaticamente il contenuto <HEX>.")
        catalog.Set(
            "`; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。",
                "`; È consigliabile apportare le modifiche in “Protezione aggiornamenti software” senza modificare direttamente il contenuto codificato.")
        catalog.Set(
            "`; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。",
                "`; I record di monitoraggio che non possono essere analizzati in sicurezza vengono conservati temporaneamente qui per evitare perdite silenziose`; normalmente non è necessario modificarli a mano.")
        catalog.Set(
            "`; 本区保存运行参数；以分号开头的注释不会参与软件读取。",
                "`; Questa sezione conserva i parametri di esecuzione`; i commenti che iniziano con un punto e virgola non vengono letti dal programma.")
        catalog.Set(
            "`; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
                "`; Formato: stato attivo｜esecuzione come amministratore｜percorso di destinazione｜directory di lavoro｜argomenti di avvio｜variabili d'ambiente｜destinazione reale del collegamento｜indicatore di destinazione manuale｜argomenti del collegamento.")
        catalog.Set(
            "`; 每个 AppN 对应一个守护对象，九个字段使用竖线分隔。",
                "`; Ogni AppN corrisponde a un elemento di monitoraggio`; i nove campi sono separati da barre verticali.")
        catalog.Set(
            "DPI 变化后刷新图标失败：{1}",
                "Impossibile aggiornare l'icona dopo la modifica dei DPI: {1}")
        catalog.Set(
            "DPI 变化后重建图标列表失败：{1}",
                "Impossibile ricostruire l'elenco delle icone dopo la modifica dei DPI: {1}")
        catalog.Set(
            "DPI 图标重建回调无效",
                "Callback non valida per la ricostruzione delle icone alla modifica dei DPI")
        catalog.Set(
            "{1} 条监控配置未载入，相关守护对象当前不会被守护。点击查看具体位置和原因。",
                "{1} configurazioni di monitoraggio non sono state caricate`; gli elementi corrispondenti non sono sorvegliati. Fare clic per vedere posizione e motivo.")
        catalog.Set(
            "• Ahk2Exe 只在发布服务器上用于生成 EXE，不随小助手安装，普通用户和源码运行用户都不需要维护它。",
                "• Ahk2Exe viene usato solo sul server di pubblicazione per generare l'EXE. Non viene installato con l'assistente e non deve essere gestito né dagli utenti normali né da chi esegue la versione sorgente.")
        catalog.Set(
            "• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。",
                "• Ctrl+A seleziona tutto. Esc prima annulla la selezione`; se non è selezionato nulla, premendo di nuovo Esc si nasconde la finestra principale.")
        catalog.Set(
            "• EXE 版已内嵌该版本发布时验证通过的 AutoHotkey；更新完整小助手发行包时，内嵌运行时会一同更新，电脑无需另装 AutoHotkey。",
                "• La versione EXE include la versione di AutoHotkey verificata al momento della pubblicazione. Il runtime incluso viene aggiornato insieme al pacchetto completo dell'assistente e non occorre installare AutoHotkey sul computer.")
        catalog.Set(
            "• EXE 版更新完整编译包；Git 源码版仅在受跟踪文件无修改且可快速前进时更新；其他源码版使用源码发行包。",
                "• La versione EXE aggiorna l'intero pacchetto compilato. La versione sorgente da Git viene aggiornata solo se i file tracciati non sono stati modificati ed è possibile un avanzamento rapido`; le altre installazioni sorgente usano l'archivio del codice sorgente.")
        catalog.Set(
            "• “监控与启动”可控制是否在启动时后台检查新版；“通用”可随时手动检查。检查过程不会阻塞主界面。",
                "• In “Monitoraggio e avvio” si può scegliere se cercare nuove versioni in background all'avvio`; in “Generale” è sempre possibile avviare un controllo manuale. Il controllo non blocca la finestra principale.")
        catalog.Set(
            "• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止”中的选项决定。",
                "• “Riavvia” chiede prima alla destinazione di chiudersi normalmente. Se il tempo impostato scade, l'opzione corrispondente in “Arresto” determina se forzare la terminazione.")
        catalog.Set(
            "• 主界面的“日志”显示本次运行中的监控、重启、升级保护和操作记录，并会自动更新。",
                "• “Registro” nella finestra principale mostra e aggiorna automaticamente gli eventi di monitoraggio, riavvio, protezione degli aggiornamenti e utilizzo della sessione corrente.")
        catalog.Set(
            "• 也可将文件或文件夹直接拖放到主列表；已经存在的守护对象不会重复添加。",
                "• È anche possibile trascinare file o cartelle direttamente nell'elenco principale`; gli elementi già presenti non vengono aggiunti di nuovo.")
        catalog.Set(
            "• 停止：设置窗口程序和命令行程序的退出等待，以及是否允许强制终止。",
                "• Arresto: impostare i tempi di attesa per l'uscita dei programmi con finestra e da riga di comando, e se consentire la terminazione forzata.")
        catalog.Set(
            "• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。",
                "• Quando si chiude la finestra principale, l'assistente continua a funzionare nell'area di notifica. Il relativo menu permette di riaprire l'interfaccia, ricaricare o uscire.")
        catalog.Set(
            "• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。",
                "• Se l'attesa di un aggiornamento scade o il rilevamento non è corretto, scegliere “Termina l'attesa dell'aggiornamento e riprendi il monitoraggio”`; prima di riprendere verrà comunque verificato che la destinazione possa essere avviata in sicurezza.")
        catalog.Set(
            "• 单击选择守护对象；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。",
                "• Fare clic per selezionare un elemento`; tenere premuto Ctrl o Maiusc per selezionarne più di uno`; trascinare le righe per modificare l'ordine di monitoraggio.")
        catalog.Set(
            "• 双击守护对象或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。",
                "• Fare doppio clic su un elemento o premere F2 per modificare il percorso completo. Canc elimina, Ctrl+Z annulla e Ctrl+Maiusc+Z o Ctrl+Y ripete.")
        catalog.Set(
            "• 发现新版后会先询问；确认后校验完整发行包，退出当前实例、替换受管文件并自动重启，不会覆盖个人配置和升级保护会话。",
                "• Quando viene trovata una nuova versione, viene prima chiesta conferma. Il pacchetto completo viene quindi verificato, l'istanza corrente viene chiusa, i file gestiti vengono sostituiti e l'assistente si riavvia automaticamente, senza sovrascrivere le impostazioni personali o le sessioni di protezione degli aggiornamenti.")
        catalog.Set(
            "• 可控的更新脚本可显式发送维护指令：",
                "• Uno script di aggiornamento sotto il proprio controllo può inviare comandi di manutenzione espliciti:")
        catalog.Set(
            "• 右键守护对象可自定义主窗口名称和图标，也可打开所在位置、重新启动、编辑路径、切换管理员运行、配置高级运行环境与软件升级保护，并查看批处理输出日志。要求管理员运行但当前权限不符时会显示警告；右键重新启动会按该设置提权启动。",
                "• Fare clic con il pulsante destro su un elemento per personalizzare nome e icona nella finestra principale, aprirne la posizione, riavviarlo, modificarne il percorso, cambiare l'esecuzione come amministratore, configurare l'ambiente di esecuzione avanzato e la protezione degli aggiornamenti oppure vedere il registro dell'output batch. Se è richiesta l'esecuzione come amministratore ma il processo corrente non dispone dei privilegi necessari, viene mostrato un avviso`; il riavvio dal menu contestuale eleva i privilegi in base a questa impostazione.")
        catalog.Set(
            "• 在守护对象右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。",
                "• Aprire “Protezione aggiornamenti software” dal menu contestuale dell'elemento per regolare la directory di installazione, l'intervallo di rilevamento dell'uscita, l'attesa di stabilità del file e l'attesa massima dell'aggiornamento, oppure per cancellare le caratteristiche apprese del programma di aggiornamento.")
        catalog.Set(
            "• 多个守护对象状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。",
                "• Se tutti gli elementi selezionati hanno lo stesso stato, “Pausa” li sospende o li riprende insieme`; se gli stati sono misti, ciascuno viene invertito.")
        catalog.Set(
            "• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。",
                "• L'assistente confronta il percorso o la riga di comando della destinazione per evitare riconoscimenti errati basati solo sul nome del processo.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“通用”页会同时显示当前小助手版本、运行形态和实际运行时版本。",
                "• La versione dell'assistente e quella di AutoHotkey sono indipendenti. “Generale” mostra insieme versione corrente dell'assistente, modalità di esecuzione e versione effettiva del runtime.")
        catalog.Set(
            "• 程序搜索：仅使用 Everything 服务并显示全部匹配结果；使用前请保持 Everything 正在运行。",
                "• Ricerca programmi: usa esclusivamente il servizio Everything e mostra tutti i risultati corrispondenti. Prima della ricerca, assicurarsi che Everything sia in esecuzione.")
        catalog.Set(
            "• 日志：设置运行日志内存上限、批处理输出日志的保存目录、保留时间和启动时清理策略。",
                "• Registri: impostare il limite del registro di esecuzione in memoria, la directory dei registri di output batch, il periodo di conservazione e la pulizia all'avvio.")
        catalog.Set(
            "• 暂停守护对象会取消它的重试和升级检测；恢复后会重新检查目标状态。",
                "• La sospensione di un elemento ne annulla i nuovi tentativi e il rilevamento degli aggiornamenti`; alla ripresa, lo stato della destinazione viene ricontrollato.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“重启等待序列”依次重试；连续失败时采用后续等待时间，避免频繁拉起。",
                "• Quando viene rilevato l'arresto della destinazione, lo stato viene prima confermato, quindi i tentativi seguono la “Sequenza di attesa per il riavvio”. Dopo errori consecutivi vengono usate le attese successive per evitare avvii troppo frequenti.")
        catalog.Set(
            "• 每次正式发布开始时都会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版（可能为预发布），冻结本次版本后完成全套测试；只有通过才生成发行包。",
                "• All'inizio di ogni pubblicazione ufficiale vengono selezionate di nuovo l'ultima versione stabile di AutoHotkey e l'ultima versione pubblicata di Ahk2Exe（che può essere una versione preliminare）, fissate per quella pubblicazione e sottoposte a tutti i test. Il pacchetto viene creato solo se tutti hanno esito positivo.")
        catalog.Set(
            "• 源码版使用电脑当前安装的 AutoHotkey；小助手更新只更新项目源码，不会安装或升级本机解释器。",
                "• La versione sorgente usa l'installazione corrente di AutoHotkey sul computer. L'aggiornamento dell'assistente aggiorna solo il codice del progetto e non installa né aggiorna l'interprete locale.")
        catalog.Set(
            "• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。",
                "• Fare clic su “Aggiungi” per cercare un'applicazione o selezionare programmi, script, collegamenti e cartelle.")
        catalog.Set(
            "• 界面语言和字体可在“通用”中手动切换；保存后立即更新主窗口、菜单和托盘，无需重新启动。",
                "• La lingua e il carattere dell'interfaccia si possono cambiare in “Generale”. Al salvataggio, la finestra principale, i menu e l'area di notifica vengono aggiornati subito, senza riavvio.")
        catalog.Set(
            "• 监控与启动：设置状态检查间隔、重启等待序列、启动后是否显示主窗口、是否检查小助手更新，以及文件夹批量导入是否递归。",
                "• Monitoraggio e avvio: impostare intervallo di controllo, sequenza di attesa per il riavvio, visualizzazione della finestra principale e controllo degli aggiornamenti all'avvio, oltre alla scansione ricorsiva delle cartelle durante l'importazione in blocco.")
        catalog.Set(
            "• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。",
                "• Dopo la conferma di un aggiornamento, gli avvii automatici vengono sospesi. Quando l'attività correlata termina e il file di destinazione è stabile, il monitoraggio riprende automaticamente. Le caratteristiche del programma di aggiornamento rilevate durante un aggiornamento reale vengono registrate automaticamente.")
        catalog.Set(
            "• 程序：EXE、COM、MSC。",
                "• Programmi: EXE, COM e MSC.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，并可立即检查小助手更新。",
                "• Generale: creare collegamenti sul desktop e nel menu Start, attivare o disattivare l'avvio automatico tramite attività pianificata e controllare subito gli aggiornamenti dell'assistente.")
        catalog.Set(
            "• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。",
                "• Script: AHK, Python, JavaScript, VBScript, PowerShell, file batch, oltre a Ruby, Perl, PHP, Lua, JAR, Shell e altri.")
        catalog.Set(
            "• 软件升级保护默认关闭。需要时在守护对象右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。",
                "• La protezione degli aggiornamenti software è disattivata per impostazione predefinita. Quando serve, aprire “Protezione aggiornamenti software” dal menu contestuale, selezionare “Rileva automaticamente gli aggiornamenti e proteggi il processo di avvio” e salvare.")
        catalog.Set(
            "• 选中守护对象后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。",
                "• Dopo aver selezionato gli elementi è possibile sospenderli, riprenderli o eliminarli. La sospensione interrompe solo il monitoraggio e non chiude le destinazioni già in esecuzione.")
        catalog.Set(
            "• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控与启动”控制。",
                "• Selezionando una cartella vengono importati in blocco i file supportati al suo interno. L'opzione “Monitoraggio e avvio” in “Impostazioni” stabilisce se esaminare anche le sottocartelle.")
        catalog.Set(
            "• 守护对象右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。",
                "• “Visualizza registro di esecuzione” nel menu contestuale apre il registro di output generato dalle destinazioni BAT/CMD. Per gli altri tipi o se non è ancora stato creato, viene segnalato che il file non esiste.")
        catalog.Set(
            "⏳ 停止原进程...",
                "⏳ Arresto del processo originale...")
        catalog.Set(
            "⏳ 判断是否正在升级",
                "⏳ Verifica di un aggiornamento in corso")
        catalog.Set(
            "⏳ 升级完成，准备恢复",
                "⏳ Aggiornamento completato`; preparazione della ripresa")
        catalog.Set(
            "⏳ 启动倒计时 {1} 秒",
                "⏳ Avvio tra {1} secondi")
        catalog.Set(
            "⏳ 启动失败，稍后自动重试",
                "⏳ Avvio non riuscito`; nuovo tentativo automatico più tardi")
        catalog.Set(
            "⏳ 确认升级文件稳定",
                "⏳ Verifica della stabilità dei file di aggiornamento")
        catalog.Set(
            "⏳ 确认升级文件稳定 {1}s",
                "⏳ Verifica della stabilità dei file di aggiornamento {1}s")
        catalog.Set(
            "⏳ 稍后自动重试 {1} 秒",
                "⏳ Nuovo tentativo automatico tra {1} secondi")
        catalog.Set(
            "⏳ 等待安全启动条件",
                "⏳ Attesa di condizioni di avvio sicure")
        catalog.Set(
            "⏳ 等待进程状态...",
                "⏳ Attesa dello stato del processo...")
        catalog.Set(
            "⏳ 重试倒计时 {1} 秒",
                "⏳ Nuovo tentativo tra {1} secondi")
        catalog.Set(
            "⏳ 验证运行状态...",
                "⏳ Verifica dello stato di esecuzione...")
        catalog.Set(
            "⏸️ 已暂停",
                "⏸️ In pausa")
        catalog.Set(
            "⏸️ 暂停",
                "⏸️ Pausa")
        catalog.Set(
            "▶️ 恢复",
                "▶️ Riprendi")
        catalog.Set(
            "⚙️ 启动参数：{1}`n",
                "⚙️ Argomenti di avvio: {1}`n")
        catalog.Set(
            "⚠️ 升级等待超时",
                "⚠️ Attesa dell'aggiornamento scaduta")
        catalog.Set(
            "⚠️ 疑似停止",
                "⚠️ Probabile arresto")
        catalog.Set(
            "⚠️ 运行中（权限不符）",
                "⚠️ In esecuzione（privilegi non corretti）")
        catalog.Set(
            "✅ 已启动（非驻留目标）",
                "✅ Avviato（destinazione non residente）")
        catalog.Set(
            "✅ 运行中",
                "✅ In esecuzione")
        catalog.Set(
            "✅ 运行：{1}   🚫 停止：{2}   ⏳ 恢复：{3}   🔄 升级：{4}   ⏸️ 暂停：{5}   ❌ 失效：{6}   ｜   🎯 总计：{7}",
                "✅ In esecuzione: {1}   🚫 Arrestati: {2}   ⏳ In attesa: {3}   🔄 Aggiornamento: {4}   ⏸️ In pausa: {5}   ❌ Non validi: {6}   ｜   🎯 Totale: {7}")
        catalog.Set(
            "✒️ 编辑完整路径（F2）",
                "✒️ Modifica il percorso completo（F2）")
        catalog.Set(
            "确 定",
                "Conferma")
        catalog.Set(
            "取 消",
                "Annulla")
        catalog.Set(
            "❌ 无法停止原进程",
                "❌ Impossibile arrestare il processo originale")
        catalog.Set(
            "❌ 目标不存在",
                "❌ La destinazione non esiste")
        catalog.Set(
            "❌ 程序不存在",
                "❌ Il programma non esiste")
        catalog.Set(
            "❌ 脚本不存在",
                "❌ Lo script non esiste")
        catalog.Set(
            "➕ 添加",
                "➕ Aggiungi")
        catalog.Set(
            "。",
                ".")
        catalog.Set(
            "一、快速上手",
                "1. Guida rapida")
        catalog.Set(
            "七、软件升级保护",
                "7. Protezione aggiornamenti software")
        catalog.Set(
            "三、主界面操作",
                "3. Operazioni nella finestra principale")
        catalog.Set(
            "不允许的升级保护阶段转换：{1}",
                "Passaggio di fase della protezione degli aggiornamenti non consentito: {1}")
        catalog.Set(
            "不支持的启动规格类型",
                "Tipo di specifica di avvio non supportato")
        catalog.Set(
            "不支持的图标格式",
                "Formato icona non supportato")
        catalog.Set(
            "不是当前 <HEX> 编码格式",
                "Il contenuto non usa il formato di codifica <HEX> corrente")
        catalog.Set(
            "与已加载守护对象重复，或目标格式无效",
                "Elemento duplicato rispetto a quelli caricati o formato della destinazione non valido")
        catalog.Set(
            "主进程监控",
                "Monitoraggio del processo principale")
        catalog.Set(
            "主进程监控异常：{1}",
                "Errore nel monitoraggio del processo principale: {1}")
        catalog.Set(
            "二、支持的守护对象",
                "2. Destinazioni supportate")
        catalog.Set(
            "五、设置",
                "5. Impostazioni")
        catalog.Set(
            "代码热重载完毕，界面已恢复显示。",
                "Il ricaricamento dinamico del codice è terminato e l'interfaccia è di nuovo visibile.")
        catalog.Set(
            "仲裁期间捕获到升级活动",
                "Rilevata attività di aggiornamento durante l'arbitraggio")
        catalog.Set(
            "使用说明",
                "Guida all'uso")
        catalog.Set(
            "恢复默认",
                "Ripristina")
        catalog.Set(
            "保存",
                "Salva")
        catalog.Set(
            "保存升级保护恢复状态失败：{1}",
                "Impossibile salvare lo stato di ripresa della protezione degli aggiornamenti: {1}")
        catalog.Set(
            "保存失败",
                "Salvataggio non riuscito")
        catalog.Set(
            "保存显示设置失败，请查看运行日志。",
                "Impossibile salvare le impostazioni di visualizzazione. Consultare il registro di esecuzione.")
        catalog.Set(
            "保存监控配置失败：{1}",
                "Impossibile salvare la configurazione di monitoraggio: {1}")
        catalog.Set(
            "保存窗口布局失败：{1}",
                "Impossibile salvare la disposizione della finestra: {1}")
        catalog.Set(
            "保存设置失败，请查看运行日志。",
                "Impossibile salvare le impostazioni. Consultare il registro di esecuzione.")
        catalog.Set(
            "保存软件升级保护设置失败，请查看运行日志。",
                "Impossibile salvare le impostazioni di protezione degli aggiornamenti software. Consultare il registro di esecuzione.")
        catalog.Set(
            "保存运行参数失败：{1}",
                "Impossibile salvare i parametri di esecuzione: {1}")
        catalog.Set(
            "值不是 0 或 1",
                "Il valore non è né 0 né 1")
        catalog.Set(
            "停止",
                "Arresto")
        catalog.Set(
            "八、日志与托盘",
                "8. Registri e area di notifica")
        catalog.Set(
            "六、版本与小助手自身更新",
                "6. Versioni e aggiornamento dell'assistente")
        catalog.Set(
            "内容为空",
                "Il contenuto è vuoto")
        catalog.Set(
            "内容无法解析",
                "Impossibile analizzare il contenuto")
        catalog.Set(
            "创建快捷方式失败：{1}",
                "Impossibile creare il collegamento: {1}")
        catalog.Set(
            "初始化...",
                "Inizializzazione...")
        catalog.Set(
            "删除选中的守护对象（支持多选，可撤销）`n快捷键：Delete",
                "Elimina gli elementi di monitoraggio selezionati（selezione multipla e annullamento supportati）`nTasto: Canc")
        catalog.Set(
            "刷新主窗口状态失败，已暂停界面倒计时刷新：{1}",
                "Impossibile aggiornare lo stato della finestra principale`; l'aggiornamento del conto alla rovescia dell'interfaccia è stato sospeso: {1}")
        catalog.Set(
            "刷新运行日志窗口失败，已暂停自动刷新：{1}",
                "Impossibile aggiornare la finestra del registro di esecuzione`; l'aggiornamento automatico è stato sospeso: {1}")
        catalog.Set(
            "升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。",
                "La protezione degli aggiornamenti supporta solo programmi o script con un percorso completo valido. La directory di installazione deve esistere e contenere il file di destinazione.")
        catalog.Set(
            "升级保护仍在进行",
                "La protezione degli aggiornamenti è ancora attiva")
        catalog.Set(
            "升级保护初始化时无法建立进程基线，将在下一轮重试。",
                "Impossibile creare lo stato di riferimento dei processi durante l'inizializzazione della protezione degli aggiornamenti`; verrà eseguito un nuovo tentativo al ciclo successivo.")
        catalog.Set(
            "升级保护协调器未能初始化，核心守护不会启动。",
                "Impossibile inizializzare il coordinatore della protezione degli aggiornamenti`; il monitoraggio principale non verrà avviato.")
        catalog.Set(
            "升级保护配置",
                "Configurazione della protezione degli aggiornamenti")
        catalog.Set(
            "升级文件监听",
                "Monitoraggio dei file di aggiornamento")
        catalog.Set(
            "升级文件监听异常（{1}）：{2}",
                "Errore nel monitoraggio dei file di aggiornamento（{1}）: {2}")
        catalog.Set(
            "升级文件监听异常：{1}",
                "Errore nel monitoraggio dei file di aggiornamento: {1}")
        catalog.Set(
            "升级等待已超时",
                "Attesa dell'aggiornamento scaduta")
        catalog.Set(
            "升级进程扫描",
                "Scansione dei processi di aggiornamento")
        catalog.Set(
            "升级进程扫描异常：{1}",
                "Errore nella scansione dei processi di aggiornamento: {1}")
        catalog.Set(
            "参数错误",
                "Errore nei parametri")
        catalog.Set(
            "发现小助手新版本：{1}（当前版本：{2}）",
                "Nuova versione dell'assistente disponibile: {1}（versione corrente: {2}）")
        catalog.Set(
            "发现新版本 {1}，当前版本为 {2}。{3}{3}{4}{3}{3}是否立即更新？",
                "È disponibile la nuova versione {1}`; la versione corrente è {2}.{3}{3}{4}{3}{3}Aggiornare ora?")
        catalog.Set(
            "取消",
                "Annulla")
        catalog.Set(
            "名称",
                "Nome")
        catalog.Set(
            "后台任务耗时较长：{1}，本次 {2} 毫秒",
                "Un'attività in background ha richiesto troppo tempo: {1}`; questa esecuzione è durata {2} ms")
        catalog.Set(
            "后台扫描进程未返回 PID",
                "Il processo di scansione in background non ha restituito un PID")
        catalog.Set(
            "后台调度任务异常（{1}）：{2}",
                "Errore in un'attività pianificata in background（{1}）: {2}")
        catalog.Set(
            "后台进程快照为空或不完整，已忽略本次结果并安排重试。",
                "L'istantanea dei processi in background è vuota o incompleta`; il risultato è stato ignorato ed è stato pianificato un nuovo tentativo.")
        catalog.Set(
            "后台进程快照已确认",
                "Istantanea dei processi in background confermata")
        catalog.Set(
            "后台进程快照未及时返回，已等待完整检测窗口",
                "L'istantanea dei processi in background non è arrivata in tempo`; è stata attesa l'intera finestra di rilevamento")
        catalog.Set(
            "启动前没有可用的启动目标，已停止重试：{1}{2}",
                "Prima dell'avvio non è disponibile alcuna destinazione di avvio`; i nuovi tentativi sono stati interrotti: {1}{2}")
        catalog.Set(
            "启动参数",
                "Argomenti di avvio")
        catalog.Set(
            "启动参数（Args）：",
                "Argomenti di avvio（Args）：")
        catalog.Set(
            "启动器需要 LaunchSpec",
                "Il modulo di avvio richiede LaunchSpec")
        catalog.Set(
            "启动失败",
                "Avvio non riuscito")
        catalog.Set(
            "启动失败 [{1}/{2}]：{3} - {4}",
                "Avvio non riuscito [{1}/{2}]: {3} - {4}")
        catalog.Set(
            "启动成功且运行稳定：{1}",
                "Avvio riuscito ed esecuzione stabile: {1}")
        catalog.Set(
            "启动批量导入失败",
                "Impossibile avviare l'importazione in blocco")
        catalog.Set(
            "启动时检查小助手更新",
                "Controlla gli aggiornamenti dell'assistente all'avvio")
        catalog.Set(
            "启动时清空批处理日志",
                "Cancella i registri batch all'avvio")
        catalog.Set(
            "启动目标不可用",
                "La destinazione di avvio non è disponibile")
        catalog.Set(
            "启动目标不存在",
                "La destinazione di avvio non esiste")
        catalog.Set(
            "启用状态",
                "Stato di attivazione")
        catalog.Set(
            "四、守护与重启",
                "4. Monitoraggio e riavvio")
        catalog.Set(
            "图标来源无效",
                "L'origine dell'icona non è valida")
        catalog.Set(
            "图标来源：",
                "Origine dell'icona：")
        catalog.Set(
            "图标缩放器",
                "Ridimensionamento icone")
        catalog.Set(
            "处理后台进程快照时发生错误：{1}",
                "Errore durante l'elaborazione dell'istantanea dei processi in background: {1}")
        catalog.Set(
            "处理应用更新结果失败：{1}",
                "Impossibile elaborare il risultato di aggiornamento dell'applicazione: {1}")
        catalog.Set(
            "字段数量应为 {1}，实际为 {2}",
                "Campi previsti: {1}`; campi effettivi: {2}")
        catalog.Set(
            "守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！",
                "Le operazioni di monitoraggio richiedono privilegi di sistema elevati in lettura e scrittura. Eseguire questo programma come amministratore.")
        catalog.Set(
            "守护对象：",
                "Obiettivo monitorato:")
        catalog.Set(
            "安全启动门暂缓启动：{1}（{2}）",
                "La barriera di avvio sicuro ha rinviato l'avvio: {1}（{2}）")
        catalog.Set(
            "安装目录特征",
                "Caratteristiche della directory di installazione")
        catalog.Set(
            "安装足迹目录：",
                "Directory di installazione：")
        catalog.Set(
            "完整路径",
                "Percorso completo")
        catalog.Set(
            "完整路径：{1}",
                "Percorso completo: {1}")
        catalog.Set(
            "导出诊断包",
                "Esporta pacchetto di diagnostica")
        catalog.Set(
            "导出诊断包失败：{1}",
                "Impossibile esportare il pacchetto di diagnostica: {1}")
        catalog.Set(
            "将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。",
                "Il pacchetto di distribuzione completo verrà scaricato e verificato. Dopo la chiusura dell'assistente, i file del programma verranno sostituiti e l'assistente si riavvierà automaticamente.")
        catalog.Set(
            "将下载并校验源码发行包，保留个人配置后替换源码并自动重启。",
                "Il pacchetto del codice sorgente verrà scaricato e verificato. Il codice verrà quindi sostituito conservando le impostazioni personali e l'assistente si riavvierà automaticamente.")
        catalog.Set(
            "将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。",
                "Verrà verificato che il repository del codice sorgente non contenga modifiche non sottoposte a commit, quindi verrà eseguito un avanzamento rapido fino al tag di pubblicazione ufficiale seguito dal riavvio automatico.")
        catalog.Set(
            "小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。",
                "L'assistente controlla programmi, script e collegamenti in background. Se una destinazione termina in modo anomalo, viene riavviata in base alla sequenza di attesa impostata. Chiudere la finestra principale la nasconde solo nell'area di notifica e non interrompe il monitoraggio.")
        catalog.Set(
            "小助手已是最新版本：{1}",
                "L'assistente è già aggiornato: {1}")
        catalog.Set(
            "小助手更新",
                "Aggiornamento dell'assistente")
        catalog.Set(
            "小助手设置",
                "Impostazioni dell'assistente")
        catalog.Set(
            "尚未从真实升级过程学习到更新程序特征。",
                "Non sono ancora state apprese caratteristiche del programma di aggiornamento da un aggiornamento reale.")
        catalog.Set(
            "展示配置",
                "Configurazione di visualizzazione")
        catalog.Set(
            "工作目录",
                "Directory di lavoro")
        catalog.Set(
            "工作目录（CWD）：",
                "Directory di lavoro（CWD）：")
        catalog.Set(
            "已从本次升级过程学习更新程序特征：{1}",
                "Caratteristiche del programma di aggiornamento apprese durante questo aggiornamento: {1}")
        catalog.Set(
            "已保存身份",
                "Identità salvata")
        catalog.Set(
            "已关闭以管理员身份运行：{1}",
                "Esecuzione come amministratore disattivata: {1}")
        catalog.Set(
            "已创建最高权限的开机自启计划任务（Win10 配置，适配笔记本）。",
                "È stata creata un'attività pianificata di avvio automatico con privilegi massimi（configurazione Windows 10 adatta ai portatili）.")
        catalog.Set(
            "已创建桌面与开始菜单快捷方式。",
                "Sono stati creati i collegamenti sul desktop e nel menu Start.")
        catalog.Set(
            "已删除自启计划任务。",
                "L'attività pianificata di avvio automatico è stata eliminata.")
        catalog.Set(
            "已刷新快捷方式内置参数：{1}",
                "Gli argomenti incorporati nel collegamento sono stati aggiornati: {1}")
        catalog.Set(
            "已刷新快捷方式真实进程（{1}）：{2} -> {3}",
                "Il processo reale del collegamento è stato aggiornato（{1}）: {2} -> {3}")
        catalog.Set(
            "已发送启动指令：{1}{2}",
                "Comando di avvio inviato: {1}{2}")
        catalog.Set(
            "已取消监控：{1}",
                "Monitoraggio annullato: {1}")
        catalog.Set(
            "已启动批处理并重定向输出到：{1}",
                "Processo batch avviato`; output reindirizzato a: {1}")
        catalog.Set(
            "已启动非驻留目标：{1}",
                "Destinazione non residente avviata: {1}")
        catalog.Set(
            "已启用以管理员身份运行：{1}",
                "Esecuzione come amministratore attivata: {1}")
        catalog.Set(
            "已导出本地诊断包：{1}",
                "Pacchetto di diagnostica locale esportato: {1}")
        catalog.Set(
            "已恢复未完成的升级保护会话：{1}",
                "È stata ripristinata una sessione incompleta di protezione degli aggiornamenti: {1}")
        catalog.Set(
            "已撤销上一步操作。",
                "L'ultima operazione è stata annullata.")
        catalog.Set(
            "已更新主窗口显示设置：{1}",
                "Le impostazioni di visualizzazione della finestra principale sono state aggiornate: {1}")
        catalog.Set(
            "已更新守护对象路径。",
                "Il percorso dell'obiettivo monitorato è stato aggiornato.")
        catalog.Set(
            "已更新软件升级保护设置：{1}",
                "Le impostazioni di protezione degli aggiornamenti software sono state aggiornate: {1}")
        catalog.Set(
            "已添加 {1} 个守护对象。",
                "Sono stati aggiunti {1} elementi di monitoraggio.")
        catalog.Set(
            "已用完快速重试，将每隔 {1} 秒继续尝试启动：{2}",
                "I tentativi rapidi sono esauriti`; l'avvio verrà ritentato ogni {1} secondi: {2}")
        catalog.Set(
            "已自动学习的更新程序特征：",
                "Caratteristiche del programma di aggiornamento apprese automaticamente:")
        catalog.Set(
            "已进入软件升级保护：{1}{2}",
                "Protezione aggiornamenti software attivata: {1}{2}")
        catalog.Set(
            "已重做操作。",
                "L'operazione è stata ripetuta.")
        catalog.Set(
            "常规终止权限不足，已提权终止进程 PID：{1}",
                "Privilegi insufficienti per la terminazione normale`; il processo con PID {1} è stato terminato con privilegi elevati")
        catalog.Set(
            "序号",
                "N.")
        catalog.Set(
            "应用更新助手不存在",
                "L'assistente di aggiornamento dell'applicazione non esiste")
        catalog.Set(
            "应用更新参数无效",
                "I parametri di aggiornamento dell'applicazione non sono validi")
        catalog.Set(
            "应用更新安装进程未返回 PID",
                "Il processo di installazione dell'aggiornamento non ha restituito un PID")
        catalog.Set(
            "应用更新本地化资源不存在",
                "Le risorse di localizzazione dell'aggiornamento dell'applicazione non esistono")
        catalog.Set(
            "应用更新检查进程未返回 PID",
                "Il processo di controllo degli aggiornamenti non ha restituito un PID")
        catalog.Set(
            "守护对象",
                "Obiettivo monitorato")
        catalog.Set(
            "应用资源",
                "Risorse dell'applicazione")
        catalog.Set(
            "开机自动启动（计划任务）",
                "Avvio automatico all'accesso（attività pianificata）")
        catalog.Set(
            "当前陪伴您的已经是最新版本的小助手啦！",
                "L'assistente che ti accompagna è già aggiornato all'ultima versione!")
        catalog.Set(
            "当前应用版本无效",
                "La versione corrente dell'applicazione non è valida")
        catalog.Set(
            "当前版本：{1}（EXE 版；内嵌 AutoHotkey {2} x64）",
                "Versione corrente: {1}（versione EXE`; AutoHotkey {2} x64 incluso）")
        catalog.Set(
            "当前版本：{1}（源码版；本机 AutoHotkey {2} x64）",
                "Versione corrente: {1}（versione sorgente`; AutoHotkey locale {2} x64）")
        catalog.Set(
            "当前状态：升级活动已结束，正在确认程序文件稳定",
                "Stato corrente: l'attività di aggiornamento è terminata`; verifica della stabilità dei file del programma")
        catalog.Set(
            "当前状态：升级等待超时，需要确认后恢复",
                "Stato corrente: attesa dell'aggiornamento scaduta`; è necessaria una conferma per riprendere")
        catalog.Set(
            "当前状态：已从上次运行恢复未完成的升级保护",
                "Stato corrente: ripristinata la protezione degli aggiornamenti rimasta incompleta nell'esecuzione precedente")
        catalog.Set(
            "当前状态：已暂停自动启动，正在等待升级完成",
                "Stato corrente: avvio automatico sospeso in attesa del completamento dell'aggiornamento")
        catalog.Set(
            "当前状态：显式升级维护已开始，正在等待结束命令",
                "Stato corrente: manutenzione esplicita dell'aggiornamento avviata`; attesa del comando di conclusione")
        catalog.Set(
            "当前状态：正在判断本次退出是否由升级引起",
                "Stato corrente: verifica se questa uscita è stata causata da un aggiornamento")
        catalog.Set(
            "当前状态：正常守护",
                "Stato corrente: monitoraggio normale")
        catalog.Set(
            "快捷方式参数",
                "Argomenti del collegamento")
        catalog.Set(
            "快捷方式及已解析目标均不可用",
                "Il collegamento e la destinazione risolta non sono disponibili")
        catalog.Set(
            "快捷方式目标",
                "Destinazione del collegamento")
        catalog.Set(
            "快捷方式真实目标",
                "Destinazione reale del collegamento")
        catalog.Set(
            "快捷方式真实进程刷新被拒绝，目标已由其它守护对象守护：{1} -> {2}",
                "Aggiornamento del processo reale del collegamento rifiutato perché la destinazione è già monitorata da un altro elemento: {1} -> {2}")
        catalog.Set(
            "恢复守护：{1}",
                "Riprendi monitoraggio: {1}")
        catalog.Set(
            "恢复记录列表无效",
                "Elenco dei record di ripristino non valido")
        catalog.Set(
            "恢复记录无效",
                "Record di ripristino non valido")
        catalog.Set(
            "恢复记录缺少字段：{1}",
                "Campo mancante nel record di ripristino: {1}")
        catalog.Set(
            "成功",
                "Operazione riuscita")
        catalog.Set(
            "所选文件夹内未找到支持的程序、脚本或快捷方式。",
                "Nella cartella selezionata non sono stati trovati programmi, script o collegamenti supportati.")
        catalog.Set(
            "手动添加守护对象：{1}",
                "Monitoraggio aggiunto manualmente: {1}")
        catalog.Set(
            "手动触发了重新启动：{1}",
                "Riavvio avviato manualmente: {1}")
        catalog.Set(
            "手动重启已取消，原进程未能停止：{1}",
                "Il riavvio manuale è stato annullato perché non è stato possibile arrestare il processo originale: {1}")
        catalog.Set(
            "托管窗口生命周期尚未配置",
                "Il ciclo di vita della finestra gestita non è ancora configurato")
        catalog.Set(
            "托管窗口生命周期适配器无效",
                "Adattatore del ciclo di vita della finestra gestita non valido")
        catalog.Set(
            "扩展设置包含无效数值。`n`n窗口程序关闭等待：1-300 秒`n命令行程序退出等待：1-60 秒`n日志条数：50-10000`n日志保留：1-3650 天",
                "Una o più impostazioni avanzate non sono valide.`n`nAttesa chiusura applicazioni con finestra: 1-300 secondi`nAttesa uscita applicazioni da riga di comando: 1-60 secondi`nVoci di registro: 50-10000`nConservazione registri: 1-3650 giorni")
        catalog.Set(
            "批处理启动需要输出日志路径",
                "L'avvio batch richiede un percorso per il registro di output")
        catalog.Set(
            "批量导入中断",
                "Importazione in blocco interrotta")
        catalog.Set(
            "批量导入完成",
                "Importazione in blocco completata")
        catalog.Set(
            "批量导入已取消，已保留并保存此前添加的 {1} 个守护对象。",
                "L'importazione in blocco è stata annullata. Sono stati mantenuti e salvati i {1} elementi di monitoraggio aggiunti in precedenza.")
        catalog.Set(
            "拒绝修改路径，真实进程已由其它守护对象守护：{1}",
                "Modifica del percorso rifiutata perché il processo reale è già monitorato da un altro elemento: {1}")
        catalog.Set(
            "拒绝更新路径，已存在相同的守护对象：{1}",
                "Modifica del percorso rifiutata perché esiste già un obiettivo monitorato identico: {1}")
        catalog.Set(
            "按钮绘制器",
                "Renderer dei pulsanti")
        catalog.Set(
            "捕获守护对象历史失败：{1}",
                "Impossibile acquisire la cronologia degli elementi di monitoraggio: {1}")
        catalog.Set(
            "提示",
                "Avviso")
        catalog.Set(
            "⚡️搜索⚡️",
                "⚡️ Ricerca ⚡️")
        catalog.Set(
            "操作计划任务时发生错误！`n`n{1}",
                "Si è verificato un errore durante l'operazione sull'attività pianificata.`n`n{1}")
        catalog.Set(
            "支持的图标与图片",
                "Icone e immagini supportate")
        catalog.Set(
            "支持的程序、脚本与快捷方式",
                "Programmi, script e collegamenti supportati")
        catalog.Set(
            "支持的程序与脚本",
                "Programmi e script supportati")
        catalog.Set(
            "收到显式维护开始命令",
                "Ricevuto il comando esplicito di avvio della manutenzione")
        catalog.Set(
            "收到显式维护结束命令，开始执行安全恢复检查：{1}",
                "Ricevuto il comando esplicito di fine della manutenzione`; avvio del controllo per la ripresa sicura: {1}")
        catalog.Set(
            "整条展示配置",
                "Configurazione di visualizzazione completa")
        catalog.Set(
            "整条记录",
                "Record completo")
        catalog.Set(
            "文件稳定等待（秒）：",
                "Attesa di stabilità del file（secondi）：")
        catalog.Set(
            "新脚本未通过 AutoHotkey 解析检查",
                "Il nuovo script non ha superato il controllo di sintassi di AutoHotkey")
        catalog.Set(
            "无法从损坏记录中提取",
                "Impossibile estrarre dati dal record danneggiato")
        catalog.Set(
            "无法停止进程 PID：{1}{2}",
                "Impossibile terminare il processo con PID {1}{2}")
        catalog.Set(
            "无法写入诊断文件：{1}",
                "Impossibile scrivere il file di diagnostica: {1}")
        catalog.Set(
            "无法启动后台文件扫描：{1}",
                "Impossibile avviare la scansione dei file in background: {1}")
        catalog.Set(
            "无法启动后台进程快照任务：{1}",
                "Impossibile avviare l'attività di istantanea dei processi in background: {1}")
        catalog.Set(
            "无法启动小助手更新安装：{1}",
                "Impossibile avviare l'installazione dell'aggiornamento dell'assistente: {1}")
        catalog.Set(
            "无法启动小助手更新检查：{1}",
                "Impossibile avviare il controllo degli aggiornamenti dell'assistente: {1}")
        catalog.Set(
            "无法导出诊断包：`n{1}",
                "Impossibile esportare il pacchetto di diagnostica:`n{1}")
        catalog.Set(
            "无法建立单实例运行锁，小助手将退出。",
                "Impossibile ottenere il blocco per l'istanza singola`; l'assistente verrà chiuso.")
        catalog.Set(
            "无法开始更新：{1}",
                "Impossibile avviare l'aggiornamento: {1}")
        catalog.Set(
            "无法收集此部分诊断信息：{1}",
                "Impossibile raccogliere questa parte delle informazioni di diagnostica: {1}")
        catalog.Set(
            "无法检查更新：{1}",
                "Impossibile controllare gli aggiornamenti: {1}")
        catalog.Set(
            "无法清理后台扫描临时文件：{1}",
                "Impossibile pulire il file temporaneo della scansione in background: {1}")
        catalog.Set(
            "无法清理后台扫描结果文件：{1}",
                "Impossibile pulire il file dei risultati della scansione in background: {1}")
        catalog.Set(
            "无法生成守护对象快照：{1}",
                "Impossibile creare l'istantanea degli elementi di monitoraggio: {1}")
        catalog.Set(
            "日志",
                "Registro")
        catalog.Set(
            "日志文件不存在：{1}",
                "Il file di registro non esiste: {1}")
        catalog.Set("📄 查看批处理输出日志", "📄 Visualizza log di output batch")
        catalog.Set("尚未生成批处理输出日志", "Nessun log di output batch disponibile")
        catalog.Set(
            "小助手只有在启动 BAT 或 CMD 守护对象时才会创建此文件。",
                "Questo file viene creato solo quando l’assistente avvia un elemento BAT o CMD.")
        catalog.Set("日志保存位置：", "Posizione del log:")
        catalog.Set("确定", "OK")
        catalog.Set(
            "时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间",
                "Le impostazioni temporali non sono valide.`n`nIntervallo di rilevamento dell'uscita: 2-120 secondi`nAttesa di stabilità del file: 2-300 secondi`nAttesa massima dell'aggiornamento: 60-86400 secondi e deve essere maggiore dell'attesa di stabilità")
        catalog.Set(
            "显式升级维护命令执行异常：{1}",
                "Errore durante l'esecuzione del comando esplicito di manutenzione dell'aggiornamento: {1}")
        catalog.Set(
            "显式升级维护命令未找到监控目标：{1}",
                "Il comando esplicito di manutenzione dell'aggiornamento non ha trovato la destinazione monitorata: {1}")
        catalog.Set(
            "显式升级维护命令被忽略，目标未启用升级保护：{1}",
                "Il comando esplicito di manutenzione dell'aggiornamento è stato ignorato perché la destinazione non ha attivato la protezione degli aggiornamenti: {1}")
        catalog.Set(
            "显示主界面",
                "Mostra l'interfaccia principale")
        catalog.Set(
            "显示名称：",
                "Nome visualizzato：")
        catalog.Set(
            "暂停守护：{1}",
                "Sospendi monitoraggio: {1}")
        catalog.Set(
            "暂停或恢复选中守护对象，不会退出目标`n支持多选；混合状态时逐项反转",
                "Sospendi o riprendi il monitoraggio degli elementi selezionati senza chiudere le destinazioni`nSupporta la selezione multipla`; con stati misti, ciascuno viene invertito")
        catalog.Set(
            "暂时无法查询进程状态，稍后重试手动重启：{1}",
                "Al momento non è possibile interrogare lo stato del processo`; il riavvio manuale verrà ritentato più tardi: {1}")
        catalog.Set(
            "暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                "Al momento non è possibile verificare i processi esistenti`; l'avvio viene ritardato per evitare istanze duplicate: {1}")
        catalog.Set(
            "暂时无法重新启动",
                "Al momento non è possibile riavviare")
        catalog.Set(
            "更新助手已启动，小助手即将退出并完成更新。",
                "L'assistente di aggiornamento è stato avviato. L'assistente verrà chiuso per completare l'aggiornamento.")
        catalog.Set(
            "更新应用搜索结果失败：{1}",
                "Impossibile aggiornare i risultati della ricerca delle applicazioni: {1}")
        catalog.Set(
            "更新检查未返回结果",
                "Il controllo degli aggiornamenti non ha restituito alcun risultato")
        catalog.Set(
            "更新检查正在进行，请稍候。",
                "È già in corso un controllo degli aggiornamenti. Attendere.")
        catalog.Set(
            "更新检查返回了无法识别的状态：{1}",
                "Il controllo degli aggiornamenti ha restituito uno stato sconosciuto: {1}")
        catalog.Set(
            "最长升级等待（秒）：",
                "Attesa massima dell'aggiornamento（secondi）：")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），恢复普通重启流程：{3}",
                "Nessuna attività di aggiornamento rilevata（{1}, durata {2} secondi）`; ripresa della normale procedura di riavvio: {3}")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），目标仍不存在：{3}",
                "Nessuna attività di aggiornamento rilevata（{1}, durata {2} secondi）e la destinazione è ancora assente: {3}")
        catalog.Set(
            "未找到目标",
                "Destinazione non trovata")
        catalog.Set(
            "未添加",
                "Non aggiunto")
        catalog.Set(
            "未知升级保护阶段",
                "Fase sconosciuta della protezione degli aggiornamenti")
        catalog.Set(
            "未知守护阶段",
                "Fase di monitoraggio sconosciuta")
        catalog.Set(
            "未知版本",
                "Versione sconosciuta")
        catalog.Set(
            "未知解析错误",
                "Errore di analisi sconosciuto")
        catalog.Set(
            "未知错误",
                "Errore sconosciuto")
        catalog.Set(
            "查看实时运行日志`n涵盖监控、重启、升级保护与操作记录",
                "Visualizza il registro di esecuzione in tempo reale`nInclude monitoraggio, riavvii, protezione degli aggiornamenti e operazioni")
        catalog.Set(
            "查看支持类型、操作方法、守护设置`n以及升级保护说明",
                "Visualizza tipi supportati, modalità d'uso e impostazioni di monitoraggio`nInclude le istruzioni per la protezione degli aggiornamenti")
        catalog.Set(
            "核心守护",
                "Monitoraggio principale")
        catalog.Set(
            "核心守护计时器启动失败。",
                "Impossibile avviare il timer del monitoraggio principale.")
        catalog.Set(
            "桌面与开始菜单快捷方式",
                "Collegamenti sul desktop e nel menu Start")
        catalog.Set(
            "创建桌面快捷方式，并将小助手加入开始菜单“所有”列表；是否固定到开始菜单由您决定。",
                "Crea un collegamento sul desktop e aggiunge l'assistente all'elenco Tutte le app del menu Start. Puoi scegliere se aggiungerlo anche agli elementi fissati in Start.")
        catalog.Set(
            "创建成功！",
                "Creati!")
        catalog.Set(
            "检查小助手更新",
                "Controlla gli aggiornamenti dell'assistente")
        catalog.Set(
            "检查小助手更新失败：{1}",
                "Controllo degli aggiornamenti dell'assistente non riuscito: {1}")
        catalog.Set(
            "检查更新",
                "Controlla aggiornamenti")
        catalog.Set(
            "立即检查更新",
                "Controlla subito gli aggiornamenti")
        catalog.Set(
            "检查更新失败：{1}",
                "Controllo degli aggiornamenti non riuscito: {1}")
        catalog.Set(
            "检查更新超时",
                "Tempo scaduto durante il controllo degli aggiornamenti")
        catalog.Set(
            "检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。",
                "È stata rilevata un'attività pianificata con lo stesso nome, ma non è stata creata da questo programma. Per evitare di eliminarla per errore, gestirla prima nell'Utilità di pianificazione.")
        catalog.Set(
            "检测到安装目录变化",
                "Rilevata una modifica alla directory di installazione")
        catalog.Set(
            "检测到相关安装进程",
                "Rilevato un processo di installazione correlato")
        catalog.Set(
            "检测到程序文件变化",
                "Rilevata una modifica ai file del programma")
        catalog.Set(
            "检测到运行中的目标未使用管理员权限：{1}",
                "La destinazione in esecuzione non usa privilegi di amministratore: {1}")
        catalog.Set(
            "检测到进程停止，准备重启：{1}（将在 {2} 秒后启动）",
                "Rilevato l'arresto del processo`; preparazione del riavvio: {1}（avvio tra {2} secondi）")
        catalog.Set(
            "正在扫描...",
                "Scansione in corso...")
        catalog.Set(
            "正在扫描文件夹，可点击取消停止",
                "Scansione della cartella in corso`; fare clic su Annulla per interrompere")
        catalog.Set(
            "正在扫描：{1}",
                "Scansione: {1}")
        catalog.Set(
            "正在添加扫描结果...",
                "Aggiunta dei risultati della scansione...")
        catalog.Set(
            "正在添加：{1} / {2}",
                "Aggiunta: {1} / {2}")
        catalog.Set(
            "正常关闭超时后允许强制终止",
                "Consenti la terminazione forzata allo scadere dell'uscita normale")
        catalog.Set(
            "正常关闭超时，已强制终止进程 PID：{1}",
                "Tempo scaduto per l'uscita normale`; il processo con PID {1} è stato terminato forzatamente")
        catalog.Set(
            "正常关闭超时，已按设置跳过强制终止 PID：{1}",
                "Tempo scaduto per l'uscita normale`; in base all'impostazione, la terminazione forzata del PID {1} è stata ignorata")
        catalog.Set(
            "没有可安装的应用更新",
                "Nessun aggiornamento dell'applicazione disponibile per l'installazione")
        catalog.Set(
            "浏览",
                "Sfoglia")
        catalog.Set(
            "添加扫描结果失败",
                "Impossibile aggiungere i risultati della scansione")
        catalog.Set(
            "添加守护对象",
                "Aggiungi elemento di monitoraggio")
        catalog.Set(
            "添加守护对象失败，已回滚内存状态：{1}",
                "Impossibile aggiungere l'elemento di monitoraggio`; lo stato in memoria è stato ripristinato: {1}")
        catalog.Set(
            "添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放",
                "Aggiungi un programma, uno script o un collegamento`nSupporta ricerca, importazione in blocco di cartelle e trascinamento di file")
        catalog.Set(
            "清除记录",
                "Cancella record")
        catalog.Set(
            "状态",
                "Stato")
        catalog.Set(
            "独立环境配置 💡`n",
                "Configurazione di ambiente separata 💡`n")
        catalog.Set(
            "环境变量",
                "Variabili d'ambiente")
        catalog.Set(
            "环境变量（每行一个 KEY=VALUE）：",
                "Variabili d'ambiente（una voce KEY=VALUE per riga）：")
        catalog.Set(
            "用户指定",
                "Specificato dall'utente")
        catalog.Set(
            "用户结束了升级等待，重新执行安全启动检查：{1}",
                "L'utente ha terminato l'attesa dell'aggiornamento`; ripetizione del controllo di avvio sicuro: {1}")
        catalog.Set(
            "界面语言和字体已即时更新，无需重新启动小助手。",
                "La lingua e il carattere dell'interfaccia sono stati aggiornati immediatamente; non è necessario riavviare l'assistente.")
        catalog.Set(
            "更新配置注释语言失败：{1}",
                "Impossibile aggiornare la lingua dei commenti di configurazione: {1}")
        catalog.Set(
            "；恢复配置失败：{1}",
                "; anche il ripristino della configurazione non è riuscito: {1}")
        catalog.Set(
            "界面显示设置无法即时应用，已恢复原语言和字体：{1}",
                "Impossibile applicare subito le impostazioni di visualizzazione. Sono stati ripristinati la lingua e il carattere precedenti: {1}")
        catalog.Set(
            "无法即时切换界面语言或字体，原显示设置已恢复。`n`n{1}",
                "Impossibile cambiare subito la lingua o il carattere dell'interfaccia. Sono state ripristinate le impostazioni di visualizzazione precedenti.`n`n{1}")
        catalog.Set(
            "显示设置应用失败",
                "Impossibile applicare le impostazioni di visualizzazione")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Usa il carattere predefinito della lingua（{1}）")
        catalog.Set(
            "正在检查更新…",
                "Ricerca di aggiornamenti…")
        catalog.Set(
            "`; UiFont：界面字体；auto 表示使用当前语言的默认字体，也可填写本机已安装字体名称。",
                "`; UiFont: carattere dell'interfaccia. auto usa il carattere predefinito della lingua corrente`; in alternativa si può indicare il nome di un carattere installato.")
        catalog.Set(
            "界面语言：",
                "Lingua dell'interfaccia：")
        catalog.Set(
            "界面资源",
                "Risorse dell'interfaccia")
        catalog.Set(
            "监控与启动",
                "Monitoraggio e avvio")
        catalog.Set(
            "守护对象重复",
                "Destinazione di monitoraggio duplicata")
        catalog.Set(
            "监控配置加载异常",
                "Errore durante il caricamento della configurazione di monitoraggio")
        catalog.Set(
            "监控配置加载异常：共 {1} 条记录未能载入。",
                "Errore durante il caricamento della configurazione di monitoraggio: impossibile caricare {1} record.")
        catalog.Set(
            "监控配置尚未保存，请查看运行日志。",
                "La configurazione di monitoraggio non è ancora stata salvata. Consultare il registro di esecuzione.")
        catalog.Set(
            "守护对象保存状态无效",
                "Stato di salvataggio dell'elemento di monitoraggio non valido")
        catalog.Set(
            "守护对象注册回调无效",
                "Callback di registrazione dell'elemento di monitoraggio non valida")
        catalog.Set(
            "守护对象路径无效：{1}",
                "Percorso dell'elemento di monitoraggio non valido: {1}")
        catalog.Set(
            "监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核：{1}",
                "Il file di destinazione non esiste più. Il monitoraggio è passato allo stato di file assente e lo ricontrollerà automaticamente quando ricomparirà: {1}")
        catalog.Set(
            "目标任务需要 WatchdogScheduler",
                "L'attività di destinazione richiede WatchdogScheduler")
        catalog.Set(
            "目标文件已恢复，重新核对运行状态：{1}",
                "Il file di destinazione è ricomparso`; nuovo controllo dello stato di esecuzione: {1}")
        catalog.Set(
            "目标文件缺失时检测到升级活动",
                "Rilevata attività di aggiornamento mentre il file di destinazione era assente")
        catalog.Set(
            "目标程序文件不存在",
                "Il file del programma di destinazione non esiste")
        catalog.Set(
            "目标程序：{1}",
                "Programma di destinazione: {1}")
        catalog.Set(
            "目标路径",
                "Percorso di destinazione")
        catalog.Set(
            "目标退出时检测到升级信号",
                "Rilevato un segnale di aggiornamento all'uscita della destinazione")
        catalog.Set(
            "真实目标来源标记",
                "Indicatore dell'origine della destinazione reale")
        catalog.Set(
            "真实进程路径无效",
                "Il percorso del processo reale non è valido")
        catalog.Set(
            "确 定",
                "Conferma")
        catalog.Set(
            "程序文件刚刚发生变化",
                "Il file del programma è appena cambiato")
        catalog.Set(
            "程序文件尚未达到稳定等待时间",
                "Il file del programma non ha ancora raggiunto il tempo di stabilità richiesto")
        catalog.Set(
            "程序文件正在写入或结构不完整",
                "Il file del programma è in fase di scrittura o ha una struttura incompleta")
        catalog.Set(
            "稍后",
                "Più tardi")
        catalog.Set(
            "窗口层级平台适配器无效",
                "Adattatore di piattaforma della gerarchia delle finestre non valido")
        catalog.Set(
            "窗口层级管理器无效",
                "Gestore della gerarchia delle finestre non valido")
        catalog.Set(
            "窗口布局字段不是整数：{1}",
                "Il campo della disposizione della finestra non è un numero intero: {1}")
        catalog.Set(
            "窗口布局字段超出范围：{1}",
                "Il campo della disposizione della finestra è fuori intervallo: {1}")
        catalog.Set(
            "窗口布局对象无效",
                "Oggetto della disposizione della finestra non valido")
        catalog.Set(
            "立即更新",
                "Aggiorna ora")
        catalog.Set(
            "等待 {1} 秒后进行第 {2} 次尝试...",
                "Attendere {1} secondi prima del tentativo {2}...")
        catalog.Set(
            "管理员运行状态",
                "Stato dell'esecuzione come amministratore")
        catalog.Set(
            "系统 PowerShell 不可用",
                "PowerShell di sistema non è disponibile")
        catalog.Set(
            "系统压缩工具未能创建诊断包",
                "Lo strumento di compressione del sistema non è riuscito a creare il pacchetto di diagnostica")
        catalog.Set(
            "系统权限拦截",
                "Bloccato dai privilegi di sistema")
        catalog.Set(
            "通用",
                "Generale")
        catalog.Set(
            "结束升级等待并恢复守护",
                "Termina l'attesa dell'aggiornamento e riprendi il monitoraggio")
        catalog.Set(
            "编码损坏",
                "Codifica danneggiata")
        catalog.Set(
            "缺少窗口布局字段：{1}",
                "Campo della disposizione della finestra mancante: {1}")
        catalog.Set(
            "缺少窗口生命周期回调：{1}",
                "Callback del ciclo di vita della finestra mancante: {1}")
        catalog.Set(
            "缺少诊断信息提供器：{1}",
                "Provider delle informazioni di diagnostica mancante: {1}")
        catalog.Set(
            "缺少运行参数：{1}",
                "Parametro di esecuzione mancante: {1}")
        catalog.Set(
            "自动",
                "Automatico")
        catalog.Set(
            "自动识别升级并保护启动过程",
                "Rileva automaticamente gli aggiornamenti e proteggi il processo di avvio")
        catalog.Set(
            "自动识别进程",
                "Riconosci automaticamente il processo")
        catalog.Set(
            "自定义名称",
                "Nome personalizzato")
        catalog.Set(
            "自定义图标",
                "Icona personalizzata")
        catalog.Set(
            "计划任务冲突",
                "Conflitto di attività pianificata")
        catalog.Set(
            "计划任务操作失败：{1}",
                "Operazione sull'attività pianificata non riuscita: {1}")
        catalog.Set(
            "设置已更新：轮询={1}ms，序列=[{2}]，日志上限={3}",
                "Impostazioni aggiornate: polling={1}ms, sequenza=[{2}], limite registro={3}")
        catalog.Set(
            "设置无效",
                "Impostazioni non valide")
        catalog.Set(
            "诊断临时目录已存在",
                "La directory temporanea di diagnostica esiste già")
        catalog.Set(
            "诊断包保存目录不存在",
                "La directory di salvataggio del pacchetto di diagnostica non esiste")
        catalog.Set(
            "诊断包已导出到：`n{1}",
                "Pacchetto di diagnostica esportato in:`n{1}")
        catalog.Set(
            "诊断包目标文件名已被占用",
                "Il nome del file di destinazione del pacchetto di diagnostica è già in uso")
        catalog.Set(
            "诊断压缩包未生成",
                "L'archivio di diagnostica non è stato generato")
        catalog.Set(
            "该文件不是受支持的图标或图片格式。`n`n支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。",
                "Il file non usa un formato di icona o immagine supportato.`n`nSono supportati ICO, EXE, DLL, CPL, LNK, PNG, JPG, JPEG, JPE, JFIF, BMP, GIF, TIF, TIFF, WebP, SVG e ANI.")
        catalog.Set(
            "该目标已存在、无效或指向目录。",
                "La destinazione esiste già, non è valida o punta a una cartella.")
        catalog.Set(
            "该真实进程已由其他守护对象守护。",
                "Il processo reale è già protetto da un altro elemento di monitoraggio.")
        catalog.Set(
            "该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。",
                "Il software è sottoposto a protezione durante l'aggiornamento. Attendere il completamento o terminare l'attesa in “Protezione aggiornamenti software” prima di riavviarlo.")
        catalog.Set(
            "语义版本无效",
                "Versione semantica non valida")
        catalog.Set(
            "请通过上方按钮搜索或选择，或在下方填写进程名或目标路径：`n【支持程序、脚本、快捷方式，以及文件夹批量导入】",
                "Usare i pulsanti in alto per cercare o selezionare.`nIn alternativa, inserire in basso il nome del processo o il percorso di destinazione.`n【Programmi, script, collegamenti e importazione di cartelle in blocco】")
        catalog.Set(
            "请选择现有且可执行的真实程序或脚本路径。",
                "Selezionare il percorso esistente ed eseguibile di un programma o script reale.")
        catalog.Set(
            "请选择现有的图标、程序、资源库或快捷方式文件。",
                "Selezionare un file esistente di icona, programma, libreria di risorse o collegamento.")
        catalog.Set(
            "读取后台扫描结果失败",
                "Impossibile leggere i risultati della scansione in background")
        catalog.Set(
            "调度器已停止",
                "L'utilità di pianificazione è stata arrestata")
        catalog.Set(
            "跟随系统",
                "Segui il sistema")
        catalog.Set(
            "路径",
                "Percorso")
        catalog.Set(
            "轮询间隔必须为 500-86400000 毫秒的正整数！",
                "L'intervallo di polling deve essere un numero intero positivo compreso tra 500 e 86400000 millisecondi.")
        catalog.Set(
            "软件升级保护",
                "Protezione aggiornamenti software")
        catalog.Set(
            "软件升级保护超过最长等待时间，需要用户确认后恢复：{1}",
                "La protezione degli aggiornamenti software ha superato l'attesa massima`; è richiesta la conferma dell'utente per riprendere: {1}")
        catalog.Set(
            "软件升级完成，准备恢复启动：{1}",
                "L'aggiornamento software è terminato`; preparazione della ripresa dell'avvio: {1}")
        catalog.Set(
            "软件升级完成，已恢复正常守护：{1}",
                "L'aggiornamento software è terminato`; il monitoraggio normale è ripreso: {1}")
        catalog.Set(
            "载入中...",
                "Caricamento...")
        catalog.Set(
            "运行参数不是支持的界面语言：{1}",
                "Il parametro di esecuzione non è una lingua dell'interfaccia supportata: {1}")
        catalog.Set(
            "运行参数不是整数：{1}",
                "Il parametro di esecuzione non è un numero intero: {1}")
        catalog.Set(
            "运行参数不能为空：{1}",
                "Il parametro di esecuzione non può essere vuoto: {1}")
        catalog.Set(
            "运行参数对象无效",
                "Oggetto dei parametri di esecuzione non valido")
        catalog.Set(
            "运行参数超出范围：{1}",
                "Il parametro di esecuzione è fuori intervallo: {1}")
        catalog.Set(
            "运行日志",
                "Registro di esecuzione")
        catalog.Set(
            "进程仍在运行，忽略重复启动：{1}",
                "Il processo è ancora in esecuzione`; l'avvio duplicato viene ignorato: {1}")
        catalog.Set(
            "进程启动后迅速退出或未成功常驻后台",
                "Il processo è terminato poco dopo l'avvio o non è riuscito a rimanere attivo in background")
        catalog.Set(
            "进程守护小助手",
                "Assistente di monitoraggio dei processi")
        catalog.Set(
            "持续守护重要程序与自动化任务，让日常工作稳定运行",
                "Mantieni stabili ogni giorno le applicazioni e le automazioni essenziali")
        catalog.Set(
            "进程守护小助手 - 开机自启守护程序",
                "Assistente di monitoraggio dei processi - Monitoraggio dell'avvio automatico")
        catalog.Set(
            "进程守护小助手已静默启动。",
                "L'Assistente di monitoraggio dei processi è stato avviato in modalità invisibile.")
        catalog.Set(
            "退出检测窗口（秒）：",
                "Intervallo di rilevamento dell'uscita（secondi）：")
        catalog.Set(
            "退出清理异常（{1}）：{2}",
                "Errore di pulizia all'uscita（{1}）: {2}")
        catalog.Set(
            "退出程序",
                "Esci dal programma")
        catalog.Set(
            "选择主窗口图标",
                "Seleziona l'icona della finestra principale")
        catalog.Set(
            "选择工作目录",
                "Seleziona la directory di lavoro")
        catalog.Set(
            "选择快捷方式对应的真实进程",
                "Seleziona il processo reale corrispondente al collegamento")
        catalog.Set(
            "选择批处理日志目录",
                "Seleziona la directory dei registri batch")
        catalog.Set(
            "选择文件",
                "Seleziona file")
        catalog.Set(
            "选择文件夹",
                "Seleziona cartella")
        catalog.Set(
            "选择要监控的文件",
                "Seleziona il file da monitorare")
        catalog.Set(
            "选择要监控的文件夹",
                "Seleziona la cartella da monitorare")
        catalog.Set(
            "选择诊断包保存位置",
                "Seleziona la posizione di salvataggio del pacchetto di diagnostica")
        catalog.Set(
            "选择软件安装目录",
                "Seleziona la directory di installazione del software")
        catalog.Set(
            "通过拖拽添加了 {1} 个守护对象。",
                "Sono stati aggiunti {1} elementi di monitoraggio tramite trascinamento.")
        catalog.Set(
            "配置仓储无效",
                "Repository di configurazione non valido")
        catalog.Set(
            "配置写入器无效",
                "Componente di scrittura della configurazione non valido")
        catalog.Set(
            "配置文件写入事务正在进行",
                "È in corso una transazione di scrittura del file di configurazione")
        catalog.Set(
            "配置通用、监控与启动、停止`n以及日志选项",
                "Configura Generali, Monitoraggio e avvio, Arresto`ne Registro")
        catalog.Set(
            "重新加载",
                "Ricarica")
        catalog.Set(
            "重新加载失败",
                "Ricaricamento non riuscito")
        catalog.Set(
            "重新加载失败，已保留当前实例：{1}",
                "Ricaricamento non riuscito`; l'istanza corrente è stata mantenuta: {1}")
        catalog.Set(
            "重新加载失败，当前守护仍在运行。`n`n{1}",
                "Ricaricamento non riuscito`; il monitoraggio corrente continua a funzionare.`n`n{1}")
        catalog.Set(
            "重试序列不能为空！",
                "La sequenza dei nuovi tentativi non può essere vuota.")
        catalog.Set(
            "重试序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "Il formato della sequenza dei nuovi tentativi non è valido. Deve contenere numeri interi positivi separati da virgole（ad esempio: 1,10,60）, ciascuno compreso tra 1 e 86400 secondi.")
        catalog.Set(
            "重试延迟序列不能为空",
                "La sequenza dei ritardi per i nuovi tentativi non può essere vuota")
        catalog.Set(
            "重试延迟序列无效",
                "La sequenza dei ritardi per i nuovi tentativi non è valida")
        catalog.Set(
            "错误",
                "Errore")
        catalog.Set(
            "名称：{1}`n真实路径：{2}",
                "Nome: {1}`nPercorso reale: {2}")
        catalog.Set(
            "🌿 环境变量：{1} 项`n",
                "🌿 Variabili d'ambiente: {1}`n")
        catalog.Set(
            "🎨 自定义名称和图标",
                "🎨 Personalizza nome e icona")
        catalog.Set(
            "📁 工作目录：{1}`n",
                "📁 Directory di lavoro: {1}`n")
        catalog.Set(
            "📂 打开所在位置",
                "📂 Apri percorso")
        catalog.Set(
            "📂 浏览文件夹...",
                "📂 Sfoglia cartella...")
        catalog.Set(
            "选择...",
                "Seleziona...")
        catalog.Set(
            "📄 查看运行日志",
                "📄 Visualizza registro di esecuzione")
        catalog.Set(
            "📄 浏览文件...",
                "📄 Sfoglia file...")
        catalog.Set(
            "🔄 反转状态",
                "🔄 Inverti stato")
        catalog.Set(
            "🔄 恢复升级保护状态",
                "🔄 Stato ripristinato della protezione degli aggiornamenti")
        catalog.Set(
            "🔄 显式升级维护中",
                "🔄 Manutenzione esplicita dell'aggiornamento in corso")
        catalog.Set(
            "🔄 检查",
                "🔄 Controlla")
        catalog.Set(
            "🔄 等待程序文件可用",
                "🔄 Attesa della disponibilità del file del programma")
        catalog.Set(
            "🔄 等待程序文件恢复",
                "🔄 Attesa del ripristino del file del programma")
        catalog.Set(
            "🔄 软件升级中",
                "🔄 Aggiornamento software in corso")
        catalog.Set(
            "🔄 软件升级保护",
                "🔄 Protezione aggiornamenti software")
        catalog.Set(
            "🔄 重新启动",
                "🔄 Riavvia")
        catalog.Set(
            "搜索...",
                "Cerca...")
        catalog.Set(
            "搜索：",
                "Cerca：")
        catalog.Set(
            "扩展名",
                "Estensione")
        catalog.Set(
            "🗑️ 删除",
                "🗑️ Elimina")
        catalog.Set(
            "🚀 正在启动...",
                "🚀 Avvio in corso...")
        catalog.Set(
            "🛡️ 以管理员身份运行",
                "🛡️ Esegui come amministratore")
        catalog.Set(
            "（{1}）",
                "（{1}）")
        catalog.Set(
            "（第 {1} 行）",
                "（riga {1}）")
        catalog.Set(
            "（管理员权限）",
                "（privilegi di amministratore）")
        catalog.Set(
            "：{1}",
                "：{1}")
        catalog.Set(
            "Everything 搜索不可用，请确认 Everything 正在运行。",
                "La ricerca Everything non è disponibile. Assicurarsi che Everything sia in esecuzione.")
        catalog.Set(
            "正在载入 Everything 搜索结果：{1}／{2}",
                "Caricamento dei risultati di ricerca Everything: {1}/{2}")
        catalog.Set(
            "Everything 搜索结果：{1} 项",
                "Risultati di ricerca Everything: {1}")
        catalog.Set("{1}（EXE 版）", "{1}（versione EXE）")
        catalog.Set("{1}（源码版）", "{1}（versione sorgente）")
        catalog.Set("• “关于”页可控制是否在启动时后台检查新版，也可随时手动检查。检查过程不会阻塞主界面。", "• La pagina “Informazioni” consente di cercare nuove versioni in background all'avvio o di avviare manualmente il controllo in qualsiasi momento. Il controllo non blocca la finestra principale.")
        catalog.Set("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• “Riavvia” chiede prima all'applicazione di chiudersi normalmente. Se il tempo scade, l'opzione in “Criteri di arresto” stabilisce se terminarla forzatamente.")
        catalog.Set("• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。", "• Informazioni: visualizza la versione dell'applicazione e l'ambiente di esecuzione AutoHotkey, cerca manualmente gli aggiornamenti o apri il progetto open source.")
        catalog.Set("• 监控与启动：设置进程状态检查间隔、崩溃自动重启延迟序列，以及导入文件夹时是否包含子目录。", "• Monitoraggio e avvio: imposta l'intervallo di controllo dei processi, la sequenza di ritardi per il riavvio automatico dopo un arresto anomalo e l'inclusione delle sottocartelle durante l'importazione di una cartella.")
        catalog.Set("• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。", "• Quando rileva che un'applicazione si è arrestata, l'assistente ne conferma lo stato e riprova secondo la “Sequenza di ritardi per il riavvio automatico dopo un arresto anomalo”. In caso di errori consecutivi usa i ritardi successivi, evitando riavvii troppo frequenti.")
        catalog.Set("• 界面语言和内容字体保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Salvando la lingua dell'interfaccia o il carattere dei contenuti, la finestra principale, i menu e l'area di notifica si aggiornano immediatamente senza riavviare.")
        catalog.Set("• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。", "• Registri: imposta il limite di visualizzazione del registro di esecuzione, il percorso e i giorni di conservazione dei registri di output batch e la pulizia all'avvio.")
        catalog.Set("• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。", "• Criteri di arresto: imposta il tempo massimo per chiudere le applicazioni GUI e CLI e scegli se consentire la terminazione forzata quando la chiusura normale supera tale limite.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时是否显示主窗口，以及界面语言和内容字体。", "• Generale: crea collegamenti sul desktop e nel menu Start, attiva o disattiva l'avvio tramite attività pianificata, scegli se mostrare la finestra principale all'avvio e imposta la lingua e il carattere dei contenuti dell'interfaccia.")
        catalog.Set("• 小助手版本与 AutoHotkey 版本彼此独立；“关于”页会分别显示当前小助手版本、运行形态和实际运行时版本。", "• Le versioni dell'assistente e di AutoHotkey sono indipendenti. La pagina “Informazioni” mostra separatamente la versione corrente dell'assistente, il tipo di distribuzione e la versione effettiva dell'ambiente di esecuzione.")
        catalog.Set("CLI 程序关闭超时（秒）：", "Tempo massimo di chiusura delle applicazioni CLI（secondi）:")
        catalog.Set("GUI 程序关闭超时（秒）：", "Tempo massimo di chiusura delle applicazioni GUI（secondi）:")
        catalog.Set("崩溃自动重启延迟序列（秒）：", "Ritardi per il riavvio automatico dopo un arresto anomalo（secondi）:")
        catalog.Set("崩溃自动重启延迟序列不能为空！", "La sequenza di ritardi per il riavvio automatico dopo un arresto anomalo non può essere vuota.")
        catalog.Set("崩溃自动重启延迟序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。", "La sequenza di ritardi per il riavvio automatico dopo un arresto anomalo non è valida. Immetti numeri interi positivi separati da virgole（ad esempio: 1,10,60）, ciascuno compreso tra 1 e 86400 secondi.")
        catalog.Set("当前版本：", "Versione corrente:")
        catalog.Set("导入文件夹时包含子目录", "Includi le sottocartelle durante l'importazione di una cartella")
        catalog.Set("开源地址", "Progetto open source")
        catalog.Set("关于", "Informazioni")
        catalog.Set("界面内容字体：", "Carattere dei contenuti dell'interfaccia:")
        catalog.Set("进程状态检查间隔（毫秒）：", "Intervallo di controllo dei processi（millisecondi）:")
        catalog.Set("进程状态检查间隔必须为 500-86400000 毫秒的正整数！", "L'intervallo di controllo dei processi deve essere un numero intero positivo compreso tra 500 e 86400000 millisecondi.")
        catalog.Set("扩展设置包含无效数值。`n`nGUI 程序关闭超时：1-300 秒`nCLI 程序关闭超时：1-60 秒`n运行日志显示上限：50-10000 条`n批处理日志保留天数：1-3650 天", "Le impostazioni avanzate contengono valori non validi.`n`nTempo massimo di chiusura delle applicazioni GUI: 1-300 secondi`nTempo massimo di chiusura delle applicazioni CLI: 1-60 secondi`nLimite di visualizzazione del registro di esecuzione: 50-10000 voci`nConservazione dei registri di output batch: 1-3650 giorni")
        catalog.Set("配置通用、监控与启动、停止策略、日志`n以及关于选项", "Configura Generale, Monitoraggio e avvio, Criteri di arresto,`nRegistri e Informazioni")
        catalog.Set("批处理日志保存路径：", "Percorso dei registri di output batch:")
        catalog.Set("批处理日志保留天数：", "Giorni di conservazione dei registri di output batch:")
        catalog.Set("启动时显示主窗口", "Mostra la finestra principale all'avvio")
        catalog.Set("设置已更新：进程检查间隔={1}ms，重启延迟序列=[{2}]，日志显示上限={3}", "Impostazioni aggiornate: intervallo dei processi={1} ms, sequenza dei ritardi di riavvio=[{2}], limite di visualizzazione del registro={3}")
        catalog.Set("停止策略", "Criteri di arresto")
        catalog.Set("运行环境：", "Ambiente di esecuzione:")
        catalog.Set("运行日志显示上限（条）：", "Limite di visualizzazione del registro di esecuzione（voci）:")
        catalog.Set("; Theme：界面主题；auto 表示跟随 Windows 系统，light 表示浅色，dark 表示深色。", "; Theme: tema dell'interfaccia`; auto segue le impostazioni di Windows, light usa il tema chiaro e dark quello scuro.")
        catalog.Set("主题：", "Tema:")
        catalog.Set("浅色", "Chiaro")
        catalog.Set("深色", "Scuro")
        catalog.Set("运行参数不是支持的界面主题：{1}", "L'impostazione di esecuzione non specifica un tema dell'interfaccia supportato: {1}")
        catalog.Set("界面显示设置无法即时应用，已恢复原语言、字体和主题：{1}", "Non è stato possibile applicare subito le impostazioni di visualizzazione; sono stati ripristinati lingua, carattere e tema precedenti: {1}")
        catalog.Set("无法即时切换界面语言、字体或主题，原显示设置已恢复。`n`n{1}", "Non è stato possibile cambiare subito la lingua, il carattere o il tema dell'interfaccia. Le impostazioni di visualizzazione precedenti sono state ripristinate.`n`n{1}")
        catalog.Set("界面语言、字体和主题已即时更新，无需重新启动小助手。", "La lingua, il carattere e il tema dell'interfaccia sono stati aggiornati subito; non è necessario riavviare l'assistente.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。", "• Generale: crea collegamenti sul desktop e nel menu Start, attiva o disattiva l'avvio pianificato, scegli se mostrare la finestra principale e controllare gli aggiornamenti all'avvio e imposta lingua, carattere dei contenuti e tema dell'interfaccia.")
        catalog.Set("• 界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Salvando la lingua, il carattere dei contenuti o il tema, la finestra principale, i menu e l'area di notifica vengono aggiornati subito senza riavvio.")
        catalog.Set("打开帮助信息`n可选择查看使用说明、运行日志或提交反馈", "Apri Aiuto`nScegli la guida utente, il registro di esecuzione o l’invio di feedback")
        catalog.Set("快揭不开锅了（≥Д≤）", "La cassa è quasi vuota（≥Д≤）")
        catalog.Set("帮助信息", "Aiuto")
        catalog.Set("提交反馈", "Invia feedback")
        catalog.Set("支持开源项目", "Sostieni il progetto open source")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式：", "Se l’assistente ti ha fatto risparmiare tempo nella diagnosi dei problemi e nel ripristino dei programmi, puoi sostenere l’autore tramite i codici QR qui sotto!`nScegli come vuoi contribuire:")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Immagine del codice QR non trovata")
        catalog.Set("• 主界面的“帮助信息”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。", "• Apri Aiuto nella finestra principale per consultare la guida utente, il registro di questa sessione o la pagina dei feedback del progetto. Il registro include monitoraggio, riavvii, protezione degli aggiornamenti e azioni dell’utente, e si aggiorna automaticamente.")
        catalog.Set("⚙️ 进程识别与启动设置", "⚙️ Identificazione del processo e impostazioni di avvio")
        catalog.Set("进程识别与启动设置", "Identificazione del processo e impostazioni di avvio")
        catalog.Set("进程识别", "Identificazione del processo")
        catalog.Set("启动环境", "Ambiente di avvio")
        catalog.Set("快捷方式仍用于启动；真实进程用于判断程序是否正在运行。", "Il collegamento resta il punto di avvio; il processo effettivo viene usato per stabilire se l'applicazione è in esecuzione.")
        catalog.Set("该守护对象直接启动并监控同一个目标，无需额外识别真实进程。", "Questo elemento avvia e monitora direttamente la stessa destinazione, quindi non occorre identificare separatamente il processo effettivo.")
        catalog.Set("用于判断运行状态的真实进程：", "Processo effettivo usato per verificare lo stato:")
        catalog.Set("用于判断运行状态的目标：", "Destinazione usata per verificare lo stato:")
        catalog.Set("重新识别", "Identifica di nuovo")
        catalog.Set("选择程序", "Scegli programma")
        catalog.Set("识别依据：{1}", "Origine dell'identificazione: {1}")
        catalog.Set("识别依据：暂无可靠结果", "Origine dell'identificazione: nessun risultato affidabile")
        catalog.Set("识别状态：路径有效。", "Stato dell'identificazione: il percorso è valido.")
        catalog.Set("识别状态：路径暂时不可用，已保留上次可靠结果。", "Stato dell'identificazione: il percorso è temporaneamente non disponibile; è stato mantenuto l'ultimo risultato affidabile.")
        catalog.Set("识别状态：路径暂时不可用，将保留此身份等待恢复。", "Stato dell'identificazione: il percorso è temporaneamente non disponibile; questa identità verrà mantenuta in attesa del ripristino.")
        catalog.Set("识别状态：未找到可靠目标，请改为手动指定。", "Stato dell'identificazione: non è stata trovata una destinazione affidabile. Specificarla manualmente.")
        catalog.Set("识别状态：手动指定，保存时将验证路径。", "Stato dell'identificazione: specificato manualmente; il percorso verrà verificato al salvataggio.")
        catalog.Set("识别状态：启动入口与监控目标一致。", "Stato dell'identificazione: il punto di avvio e la destinazione monitorata coincidono.")
        catalog.Set("这些设置仅在小助手下次启动目标时生效，不会重启当前进程。", "Queste impostazioni avranno effetto al prossimo avvio della destinazione da parte dell'assistente e non riavvieranno il processo già in esecuzione.")
        catalog.Set("留空时使用快捷方式工作目录或程序所在目录。", "Lasciare vuoto per usare la cartella di lavoro del collegamento o la cartella del programma.")
        catalog.Set("留空时不附加额外参数。", "Lasciare vuoto per non aggiungere argomenti.")
        catalog.Set("留空时继承小助手当前环境。", "Lasciare vuoto per ereditare l'ambiente corrente dell'assistente.")
        catalog.Set("工作目录不存在或不可访问：{1}", "La cartella di lavoro non esiste o non è accessibile: {1}")
        catalog.Set("工作目录无效", "Cartella di lavoro non valida")
        catalog.Set("环境变量第 {1} 行缺少等号（KEY=VALUE）。", "Alla riga {1} delle variabili d'ambiente manca il segno di uguale（KEY=VALUE）.")
        catalog.Set("环境变量第 {1} 行的名称无效：{2}", "La riga {1} delle variabili d'ambiente contiene un nome non valido: {2}")
        catalog.Set("环境变量第 {1} 行重复定义了 {2}。", "La riga {1} delle variabili d'ambiente definisce nuovamente {2}.")
        catalog.Set("环境变量配置无法解析。", "Impossibile interpretare la configurazione delle variabili d'ambiente.")
        catalog.Set("环境变量配置无效", "Variabili d'ambiente non valide")
        catalog.Set("设置已应用到当前运行，但暂未写入配置文件；小助手将在后台自动重试。", "Le impostazioni sono già attive nella sessione corrente, ma non sono ancora state scritte nel file di configurazione. L'assistente riproverà automaticamente in background.")
        catalog.Set("配置暂未写入", "Configurazione non ancora scritta")
        catalog.Set("已更新进程识别与启动设置：{1}", "Identificazione del processo e impostazioni di avvio aggiornate: {1}")
        catalog.Set("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。", "• Collegamenti: LNK, URL e APPREF-MS, inclusi i collegamenti MSI di cui è possibile individuare la destinazione effettiva. Per i collegamenti particolari, specificare manualmente il processo effettivo in Identificazione del processo e impostazioni di avvio.")
        catalog.Set("• 右键守护对象可自定义主窗口名称和图标，也可打开所在位置、重新启动、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。要求管理员运行但当前权限不符时会显示警告；右键重新启动会按该设置提权启动。", "• Fare clic con il pulsante destro su un elemento per personalizzarne nome e icona nella finestra principale, aprire il percorso, riavviarlo, modificarne il percorso, attivare o disattivare l'avvio come amministratore, configurare identificazione del processo, avvio e protezione degli aggiornamenti oppure consultare il registro di output dei file batch. Se è richiesto l'avvio come amministratore ma il processo corrente non dispone dei privilegi necessari, verrà mostrato un avviso; riavviando dal menu contestuale il programma verrà elevato secondo questa impostazione.")
        catalog.Set("添加", "Aggiungi")
        catalog.Set("暂停", "Pausa")
        catalog.Set("恢复", "Riprendi")
        catalog.Set("删除", "Elimina")
        catalog.Set("设置", "Impostazioni")
        catalog.Set("捐赠", "Dona")
        catalog.Set("保存", "Salva")
        catalog.Set("取消", "Annulla")
        catalog.Set("反转状态", "Inverti stato")
        catalog.Set("统计：运行", "In esecuzione")
        catalog.Set("统计：停止", "Arrestati")
        catalog.Set("统计：恢复", "Ripristino in corso")
        catalog.Set("统计：升级", "Aggiornamento")
        catalog.Set("统计：暂停", "In pausa")
        catalog.Set("统计：失效", "Non validi")
        catalog.Set("统计：总计", "Totale")
        catalog.Set("配置未保存", "Configurazione non salvata")
        catalog.Set("创建", "Crea")
        catalog.Set("开启", "Attiva")
        catalog.Set("关闭", "Disattiva")
        catalog.Set("切换", "Cambia")
        catalog.Set("冲突", "Conflitto")
        catalog.Set("浏览", "Sfoglia")
        catalog.Set("监控配置", "Configurazione del monitoraggio")
        catalog.Set("管理员运行状态", "Esecuzione come amministratore")
        catalog.Set("调整守护顺序", "Riordina elenco di monitoraggio")
        catalog.Set("编辑完整路径", "Modifica percorso completo")
        catalog.Set("自定义名称和图标", "Personalizza nome e icona")
        catalog.Set("已撤销：{1}", "Annullato: {1}")
        catalog.Set("已重做：{1}", "Ripetuto: {1}")
        catalog.Set("Everything 搜索暂时不可用，请稍后重试。", "La ricerca con Everything è temporaneamente non disponibile. Riprovare più tardi.")
        catalog.Set("Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。", "Il componente di ricerca Everything manca o non può essere caricato. Estrarre completamente l'assistente oppure reinstallarlo.")
        catalog.Set("已找到 Everything，但无法后台启动，请手动启动后重试。", "Everything è stato trovato, ma non può essere avviato in background. Avviarlo manualmente e riprovare.")
        catalog.Set("后台启动 Everything 失败：{1}", "Impossibile avviare Everything in background: {1}")
        catalog.Set("正在后台启动 Everything 并等待搜索服务就绪...", "Avvio di Everything in background e attesa del servizio di ricerca...")
        catalog.Set("已在后台启动 Everything：{1}", "Everything è stato avviato in background: {1}")
        catalog.Set("等待 Everything 搜索服务就绪超时：{1}", "Tempo scaduto in attesa che il servizio di ricerca Everything fosse pronto: {1}")
        catalog.Set("未找到 Everything，点击前往官网下载最新版：{1}", "Everything non è stato trovato. Fare clic per scaricare la versione più recente dal sito ufficiale: {1}")
        catalog.Set("本机未找到 Everything；程序搜索需要 Everything 后台服务。", "Everything non è stato trovato in questo computer; la ricerca dei programmi richiede il servizio Everything in background.")
        catalog.Set("• 程序搜索：使用 Everything 服务并显示全部匹配结果；未运行时会尝试在本机查找并后台启动，未找到时提供官网最新版下载地址。", "• Ricerca dei programmi: usa il servizio Everything e mostra tutti i risultati corrispondenti. Se Everything non è in esecuzione, l'assistente lo cerca nel computer e lo avvia in background; se non lo trova, propone il collegamento ufficiale per scaricare la versione più recente.")
        catalog.Set("• 小助手随包的 Everything64.dll 只是连接 Everything 后台实例的 SDK 客户端，不负责扫描磁盘或建立索引，不能替代 Everything 本体。", "• Everything64.dll, incluso con l'assistente, è soltanto un client SDK che si collega all'istanza di Everything in background. Non esamina i dischi, non crea l'indice e non sostituisce l'applicazione Everything.")
        catalog.Set("六、进程识别与启动设置", "6. Identificazione del processo e impostazioni di avvio")
        catalog.Set("• 此设置只作用于当前守护对象，并将“用什么启动”和“用什么判断正在运行”分开处理。启动环境只在小助手下次启动目标时生效，不会重启当前进程。", "• Queste impostazioni si applicano solo all'elemento sorvegliato corrente e separano il modo in cui viene avviato dagli elementi usati per stabilire se è in esecuzione. L'ambiente di avvio viene applicato al successivo avvio della destinazione da parte dell'assistente e non riavvia il processo corrente.")
        catalog.Set("• 直接添加程序或脚本时，启动入口与监控目标相同；EXE 按完整路径识别，脚本按宿主进程命令行中的脚本路径识别。", "• Quando si aggiunge direttamente un programma o uno script, il punto di avvio e la destinazione sorvegliata coincidono. I file EXE sono identificati dal percorso completo; gli script, dal percorso dello script nella riga di comando del processo host.")
        catalog.Set("• 添加 LNK 快捷方式时，快捷方式始终作为启动入口；自动识别出的真实程序或脚本只用于判断运行状态。", "• Quando si aggiunge un collegamento LNK, questo resta sempre il punto di avvio. Il programma o lo script effettivo individuato automaticamente serve solo a determinare lo stato di esecuzione.")
        catalog.Set("• 自动识别会综合快捷方式目标、参数、Windows Installer 信息、安装目录、文件版本信息和已观察进程；证据不唯一时不会随意绑定。", "• L'identificazione automatica combina destinazione e argomenti del collegamento, dati di Windows Installer, cartella di installazione, informazioni sulla versione del file e processi osservati. Se gli indizi sono ambigui, non associa arbitrariamente una destinazione.")
        catalog.Set("• 自动结果不正确时改用“用户指定”，选择程序正常运行期间持续存在的主程序或脚本；不要选择启动器、更新器或短暂子进程。", "• Se il risultato automatico non è corretto, scegliere Specificato dall'utente e selezionare il programma principale o lo script che rimane presente durante il normale funzionamento dell'applicazione. Non selezionare un launcher, un programma di aggiornamento o un processo figlio di breve durata.")
        catalog.Set("启动程序或解释器：", "Launcher o interprete:")
        catalog.Set("留空时按目标类型自动启动；可选择 Python、AutoHotkey、PowerShell、Node.js、Java 等运行时。", "Lasciare vuoto per avviare in base al tipo di destinazione oppure selezionare un ambiente di esecuzione come Python, AutoHotkey, PowerShell, Node.js o Java.")
        catalog.Set("启动程序参数：", "Argomenti del launcher:")
        catalog.Set("参数顺序为：启动程序参数、目标路径、目标参数；例如 Java 使用 -jar。", "L'ordine è: argomenti del launcher, percorso della destinazione e argomenti della destinazione. Ad esempio, con Java si usa -jar.")
        catalog.Set("目标参数（Args）：", "Argomenti della destinazione（Args）:")
        catalog.Set("留空时继承小助手当前环境；值中可用 %变量名% 引用已有环境变量。", "Lasciare vuoto per ereditare l'ambiente corrente dell'assistente. In un valore è possibile usare %VARIABILE% per fare riferimento a una variabile di ambiente esistente.")
        catalog.Set("选择启动程序或解释器", "Scegli launcher o interprete")
        catalog.Set("可执行程序", "Programmi eseguibili")
        catalog.Set("请先选择启动程序或解释器，再填写它的参数。", "Scegliere un launcher o un interprete prima di inserirne gli argomenti.")
        catalog.Set("启动程序未设置", "Launcher non impostato")
        catalog.Set("启动程序或解释器不存在：{1}", "Il launcher o l'interprete non esiste: {1}")
        catalog.Set("启动程序无效", "Launcher non valido")
        catalog.Set("整条启动配置", "intera configurazione di avvio")
        catalog.Set("启动程序或解释器", "launcher o interprete")
        catalog.Set("解释器参数", "argomenti dell'interprete")
        catalog.Set("• 直接脚本可指定“启动程序或解释器”，选择实际执行脚本的可执行文件，例如 Python、AutoHotkey、PowerShell、Node.js、Ruby、Perl、PHP、Lua、Java 或 Bash；留空时沿用系统默认启动方式。", "• Per uno script aggiunto direttamente, Launcher o interprete consente di scegliere l'eseguibile che lo esegue realmente, ad esempio Python, AutoHotkey, PowerShell, Node.js, Ruby, Perl, PHP, Lua, Java o Bash. Lasciare vuoto per usare il metodo di avvio predefinito del sistema.")
        catalog.Set("• “启动程序参数”位于目标路径之前，“目标参数（Args）”位于目标路径之后。Java 可填写 -jar；PowerShell 可填写 -NoProfile -ExecutionPolicy Bypass -File。", "• Gli Argomenti del launcher vengono inseriti prima del percorso della destinazione; gli Argomenti della destinazione（Args）dopo. Per Java è possibile usare -jar; per PowerShell -NoProfile -ExecutionPolicy Bypass -File.")
        catalog.Set("• Python 虚拟环境请选择该环境的 Scripts\python.exe；其他语言也可选择项目要求的确切运行时版本。进程识别仍以目标脚本路径为准，不会误把解释器本身当成守护目标。", "• Per un ambiente virtuale Python, selezionare il relativo Scripts\python.exe. Anche per gli altri linguaggi è possibile scegliere la versione esatta dell'ambiente di esecuzione richiesta dal progetto. L'identificazione del processo continua a basarsi sul percorso dello script di destinazione, quindi l'interprete non viene scambiato per la destinazione sorvegliata.")
        catalog.Set("• 工作目录（CWD）用于解析相对路径；留空时使用快捷方式工作目录或目标所在目录。", "• La cartella di lavoro（CWD）serve a risolvere i percorsi relativi. Se resta vuota, viene usata la cartella di lavoro del collegamento o la cartella della destinazione.")
        catalog.Set("• 环境变量每行填写一个 KEY=VALUE，只覆盖列出的变量；值中可用 %变量名% 引用已有环境变量。启动完成后小助手会恢复自身环境。", "• Inserire una variabile di ambiente KEY=VALUE per riga. Vengono sostituite solo le variabili elencate e %VARIABILE% può fare riferimento a un valore esistente. Dopo l'avvio, l'assistente ripristina il proprio ambiente.")
        catalog.Set("; AppN 与 [Apps] 中同名的守护对象一一对应，依次保存启动程序或解释器路径及其参数。", "; Ogni AppN corrisponde all'obiettivo monitorato omonimo in [Apps] e memorizza, nell'ordine, il percorso del launcher o dell'interprete e i relativi argomenti.")
        catalog.Set("; 两个字段均为 <HEX> 编码；留空时由小助手按目标类型使用默认启动方式。", "; Entrambi i campi usano la codifica <HEX>. Se sono vuoti, l'assistente usa il metodo di avvio predefinito per il tipo di destinazione.")
        catalog.Set("守护对象不能指向文件夹：{1}", "Un elemento sorvegliato non può puntare a una cartella: {1}")
        catalog.Set("自动识别目标新位置", "Rileva automaticamente la nuova posizione della destinazione")
        catalog.Set("检测到的目标新位置已失效，请重新操作。", "La nuova posizione rilevata non è più valida. Riprovare.")
        catalog.Set("已更新已更名的守护目标：{1} -> {2}", "La destinazione sorvegliata rinominata è stata aggiornata: {1} -> {2}")
        catalog.Set("守护目标更名识别服务未能启动。", "Impossibile avviare il servizio di rilevamento delle destinazioni rinominate.")
        catalog.Set("检测到守护目标可能已更名，等待用户确认：{1} -> {2}", "Una destinazione sorvegliata potrebbe essere stata rinominata`; in attesa di conferma: {1} -> {2}")
        catalog.Set("守护目标更名识别异常：{1}", "Errore nel rilevamento di una destinazione sorvegliata rinominata: {1}")
        catalog.Set("确认窗口暂时无法显示，将稍后重试", "La finestra di conferma non è temporaneamente disponibile. Verrà eseguito un nuovo tentativo a breve.")
        catalog.Set("守护目标目录监听异常（{1}）：{2}", "Errore nel monitoraggio della cartella della destinazione（{1}）: {2}")
        catalog.Set("等待确认目标新位置", "In attesa di conferma della nuova posizione")
        catalog.Set("确认目标新位置", "Conferma la nuova posizione della destinazione")
        catalog.Set("检测到守护目标可能已更名", "Una destinazione sorvegliata potrebbe essere stata rinominata")
        catalog.Set("小助手找到了与原文件身份一致的新路径。确认后将更新守护目标，名称、图标和启动设置保持不变。", "L'assistente ha trovato un nuovo percorso con la stessa identità del file. Dopo la conferma, la destinazione sorvegliata verrà aggiornata mantenendo invariati nome, icona e impostazioni di avvio.")
        catalog.Set("原路径：", "Percorso precedente:")
        catalog.Set("新路径：", "Nuovo percorso:")
        catalog.Set("Windows 文件身份一致", "Identità file di Windows corrispondente")
        catalog.Set("Windows 重命名事件", "Evento di ridenominazione di Windows")
        catalog.Set("识别依据：", "Prova di identificazione: ")
        catalog.Set("更新守护路径", "Aggiorna percorso sorvegliato")
        catalog.Set("忽略", "Ignora")
        catalog.Set("更新已更名的守护目标", "Aggiorna destinazione sorvegliata rinominata")
        catalog.Set("• 直接添加的程序或脚本在小助手运行期间更名或在同一卷（通常是同一盘符）内移动后，小助手会按 Windows 文件身份找回新路径并请您确认，不会按相似文件名猜测。", "• Se un programma o script aggiunto direttamente viene rinominato mentre l'assistente è in esecuzione, oppure spostato all'interno dello stesso volume, l'assistente individua il nuovo percorso tramite l'identità file di Windows e chiede conferma. Non deduce la destinazione da nomi di file simili.")
        catalog.Set("• 确认后只更新守护路径，名称、图标和启动设置保持不变；关闭小助手期间发生的更名或跨磁盘移动无法可靠自动识别，请双击守护对象手动更新完整路径。", "• Dopo la conferma viene aggiornato solo il percorso monitorato. Il nome, l'icona e le impostazioni di avvio restano invariati. Le rinomine effettuate mentre l'assistente è chiuso e gli spostamenti su un altro volume non possono essere rilevati automaticamente in modo affidabile. In questi casi, fare doppio clic sull'elemento e aggiornare manualmente il percorso completo.")
        return catalog
    }
}

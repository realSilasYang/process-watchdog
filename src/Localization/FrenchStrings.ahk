; fr-FR 本地化词条目录。
; 本目录由模型直接依据简体中文稳定键逐条翻译；生成步骤仅处理转义与格式。

class FrenchStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Appuyer")
        catalog.Set(
            "`n位置：{1}",
                "`nEmplacement : {1}")
        catalog.Set(
            "`r`n      影响：该守护对象本次未加入守护列表。",
                "`r`n      Conséquence : cet élément n'a pas été ajouté à la liste de surveillance.")
        catalog.Set(
            "`r`n      目标：{1}",
                "`r`n      Cible : {1}")
        catalog.Set(
            "`r`n      问题：{1}：{2}",
                "`r`n      Problème : {1} : {2}")
        catalog.Set(
            "`r`n  [{1}] 位置：[{2}] {3}",
                "`r`n  [{1}] Emplacement : [{2}] {3}")
        catalog.Set(
            "`r`n  处理建议：确认目标路径后，可在主界面重新添加该守护对象；也可退出小助手后检查上述配置位置。后续保存配置时，损坏记录会转存到 [Recovery]，不会被静默删除。",
                "`r`n  Action conseillée : vérifiez le chemin de la cible, puis ajoutez de nouveau cet élément depuis la fenêtre principale. Vous pouvez aussi quitter l'assistant et vérifier l'emplacement de configuration indiqué ci-dessus. Lors du prochain enregistrement, les entrées endommagées seront déplacées vers [Recovery] et ne seront pas supprimées sans avertissement.")
        catalog.Set(
            "`r`n  配置文件：{1}",
                "`r`n  Fichier de configuration : {1}")
        catalog.Set(
            "   ⚠️ 配置未保存",
                "   ⚠️ Configuration non enregistrée")
        catalog.Set(
            "  --maintenance-begin `"目标完整路径`"    开始维护",
                "  --maintenance-begin `"chemin complet de la cible`"    Commencer la maintenance")
        catalog.Set(
            "  --maintenance-end `"目标完整路径`"      结束维护",
                "  --maintenance-end `"chemin complet de la cible`"      Terminer la maintenance")
        catalog.Set(
            " 已保留并保存此前添加的 {1} 个守护对象。",
                " Les {1} éléments surveillés ajoutés précédemment ont été conservés et enregistrés.")
        catalog.Set(
            " 扫描达到时间或数量上限，结果已截断。",
                " L'analyse a atteint la limite de temps ou de résultats `; les résultats ont été tronqués.")
        catalog.Set(
            "`; AllowForceTerminate：正常退出超时后是否允许强制结束进程。",
                "`; AllowForceTerminate : autorise ou non l'arrêt forcé du processus après expiration du délai de fermeture normale.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应，值为软件升级保护的 <HEX> 编码结构。",
                "`; Chaque AppN correspond à l'élément du même nom dans [Apps] `; sa valeur contient la structure de protection des mises à jour encodée au format <HEX>.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应；留空时使用目标自身的名称和图标。",
                "`; Chaque AppN correspond à l'élément du même nom dans [Apps] `; un élément vide utilise le nom et l'icône de la cible.")
        catalog.Set(
            "`; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。",
                "`; CheckInterval : intervalle de vérification de l'état, en millisecondes `; plage de 500 à 86400000.")
        catalog.Set(
            "`; CheckUpdatesOnStartup：启动后是否在后台检查小助手新版。",
                "`; CheckUpdatesOnStartup : indique s'il faut rechercher en arrière-plan une nouvelle version de l'assistant après le démarrage.")
        catalog.Set(
            "`; ClearLogsOnStartup：启动时是否清空历史日志。",
                "`; ClearLogsOnStartup : indique s'il faut effacer les anciens journaux au démarrage.")
        catalog.Set(
            "`; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col1W : largeur de la première colonne de la liste principale, enregistrée en pixels logiques à 96 PPP.")
        catalog.Set(
            "`; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col2W : largeur de la deuxième colonne de la liste principale, enregistrée en pixels logiques à 96 PPP.")
        catalog.Set(
            "`; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。",
                "`; CtrlCWaitSeconds : attente maximale, en secondes, après l'envoi de Ctrl+C à un programme en ligne de commande `; plage de 1 à 60.")
        catalog.Set(
            "`; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。",
                "`; GracefulStopSeconds : attente maximale, en secondes, pour la fermeture normale d'un programme fenêtré `; plage de 1 à 300.")
        catalog.Set(
            "`; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。",
                "`; GuiH : hauteur de la fenêtre principale, enregistrée en pixels logiques à 96 PPP.")
        catalog.Set(
            "`; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。",
                "`; GuiW : largeur de la fenêtre principale, enregistrée en pixels logiques à 96 PPP.")
        catalog.Set(
            "`; LogDirectory：留空时使用系统临时目录下的 ProcessWatchdogLogs。",
                "`; LogDirectory : si ce champ est vide, le dossier ProcessWatchdogLogs du répertoire temporaire système est utilisé.")
        catalog.Set(
            "`; LogMaxEntries：日志界面保留条数，范围 50～10000。",
                "`; LogMaxEntries : nombre d'entrées conservées dans la fenêtre du journal `; plage de 50 à 10000.")
        catalog.Set(
            "`; LogRetentionDays：日志文件保留天数，范围 1～3650。",
                "`; LogRetentionDays : durée de conservation des fichiers journaux, en jours `; plage de 1 à 3650.")
        catalog.Set(
            "`; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。",
                "`; RecursiveBatchImport : indique s'il faut parcourir les sous-dossiers lors de l'importation groupée d'un dossier.")
        catalog.Set(
            "`; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。",
                "`; RetrySequence : délais d'attente avant redémarrage, en secondes et séparés par des virgules `; 10 valeurs au maximum, chacune comprise entre 1 et 86400.")
        catalog.Set(
            "`; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。",
                "`; ShowAfterReload : indicateur interne de rechargement `; revient automatiquement à 0 une fois le rechargement terminé.")
        catalog.Set(
            "`; ShowAtStartup：启动后是否显示主窗口。",
                "`; ShowAtStartup : indique s'il faut afficher la fenêtre principale après le démarrage.")
        catalog.Set(
            "`; UiLanguage：界面语言；auto 表示跟随系统，也可填写受支持的语言代码。",
                "`; UiLanguage : langue de l'interface `; auto suit la langue du système, mais un code de langue pris en charge peut aussi être indiqué.")
        catalog.Set(
            "`; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。",
                "`; Enregistre uniquement le nom affiché et la source de l'icône dans la fenêtre principale `; n'intervient pas dans l'identification du processus, le lancement ni la protection des mises à jour.")
        catalog.Set(
            "`; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
                "`; Les champs internes comprennent Enabled, RootIsCustom, DetectionSeconds, StableSeconds, MaxWaitSeconds, InstallRoot et Actor.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。",
                "`; Les valeurs booléennes utilisent 1 pour activer et 0 pour désactiver `; il est recommandé de les modifier depuis la fenêtre de configuration.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。",
                "`; Les valeurs booléennes utilisent 1 pour activer et 0 pour désactiver `; le logiciel encode et décode automatiquement le contenu <HEX>.")
        catalog.Set(
            "`; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。",
                "`; Il est recommandé d'effectuer les modifications dans « Protection des mises à jour logicielles » et de ne pas modifier directement le contenu encodé.")
        catalog.Set(
            "`; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。",
                "`; Les entrées de surveillance impossibles à analyser de façon sûre sont conservées temporairement ici afin d'éviter toute perte silencieuse `; il n'est normalement pas nécessaire de les modifier manuellement.")
        catalog.Set(
            "`; 本区保存运行参数；以分号开头的注释不会参与软件读取。",
                "`; Cette section conserve les paramètres d'exécution `; les commentaires commençant par un point-virgule ne sont pas lus par le logiciel.")
        catalog.Set(
            "`; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
                "`; Format : état activé｜exécution en tant qu'administrateur｜chemin de la cible｜répertoire de travail｜arguments de lancement｜variables d'environnement｜cible réelle du raccourci｜indicateur de cible manuelle｜arguments du raccourci.")
        catalog.Set(
            "`; 每个 AppN 对应一个守护对象，九个字段使用竖线分隔。",
                "`; Chaque AppN correspond à un élément surveillé `; les neuf champs sont séparés par des barres verticales.")
        catalog.Set(
            "DPI 变化后刷新图标失败：{1}",
                "Échec de l'actualisation de l'icône après le changement de PPP : {1}")
        catalog.Set(
            "DPI 变化后重建图标列表失败：{1}",
                "Échec de la reconstruction de la liste d'icônes après le changement de PPP : {1}")
        catalog.Set(
            "DPI 图标重建回调无效",
                "Le rappel de reconstruction des icônes lors d'un changement de PPP n'est pas valide")
        catalog.Set(
            "{1} 条监控配置未载入，相关守护对象当前不会被守护。点击查看具体位置和原因。",
                "{1} configurations de surveillance n'ont pas été chargées `; les éléments concernés ne sont pas surveillés. Cliquez pour afficher leur emplacement et la raison.")
        catalog.Set(
            "• Ahk2Exe 只在发布服务器上用于生成 EXE，不随小助手安装，普通用户和源码运行用户都不需要维护它。",
                "• Ahk2Exe sert uniquement à produire l'EXE sur le serveur de publication. Il n'est pas installé avec l'assistant et ni les utilisateurs ordinaires ni ceux qui exécutent le code source n'ont à le maintenir.")
        catalog.Set(
            "• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。",
                "• Ctrl+A sélectionne tout. Échap annule d'abord la sélection `; si aucun élément n'est sélectionné, une nouvelle pression sur Échap masque la fenêtre principale.")
        catalog.Set(
            "• EXE 版已内嵌该版本发布时验证通过的 AutoHotkey；更新完整小助手发行包时，内嵌运行时会一同更新，电脑无需另装 AutoHotkey。",
                "• L'édition EXE intègre la version d'AutoHotkey validée lors de sa publication. L'environnement intégré est mis à jour avec le paquet complet de l'assistant `; aucune installation d'AutoHotkey n'est nécessaire sur l'ordinateur.")
        catalog.Set(
            "• EXE 版更新完整编译包；Git 源码版仅在受跟踪文件无修改且可快速前进时更新；其他源码版使用源码发行包。",
                "• L'édition EXE met à jour l'ensemble du paquet compilé. L'édition exécutée depuis un dépôt Git n'est mise à jour que si les fichiers suivis n'ont pas été modifiés et qu'une avance rapide est possible `; les autres installations depuis le code source utilisent l'archive du code source.")
        catalog.Set(
            "• 主界面的“日志”显示本次运行中的监控、重启、升级保护和操作记录，并会自动更新。",
                "• « Journal » dans la fenêtre principale affiche et actualise automatiquement les événements de surveillance, de redémarrage, de protection des mises à jour et d'utilisation de la session en cours.")
        catalog.Set(
            "• 也可将文件或文件夹直接拖放到主列表；已经存在的守护对象不会重复添加。",
                "• Vous pouvez aussi déposer directement des fichiers ou des dossiers dans la liste principale `; les éléments déjà présents ne sont pas ajoutés une seconde fois.")
        catalog.Set(
            "• 停止：设置窗口程序和命令行程序的退出等待，以及是否允许强制终止。",
                "• Arrêt : réglez les délais de fermeture des programmes fenêtrés et en ligne de commande, ainsi que l'autorisation d'un arrêt forcé.")
        catalog.Set(
            "• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。",
                "• Lorsque vous fermez la fenêtre principale, l'assistant continue de fonctionner dans la zone de notification. Son menu permet de réafficher l'interface, de recharger ou de quitter.")
        catalog.Set(
            "• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。",
                "• Si l'attente d'une mise à jour expire ou si la détection est erronée, choisissez « Terminer l'attente de mise à jour et reprendre la surveillance » `; avant la reprise, la possibilité de lancer la cible en toute sécurité sera vérifiée.")
        catalog.Set(
            "• 单击选择守护对象；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。",
                "• Cliquez sur un élément pour le sélectionner `; maintenez Ctrl ou Maj pour en sélectionner plusieurs `; faites glisser les lignes pour modifier l'ordre de surveillance.")
        catalog.Set(
            "• 双击守护对象或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。",
                "• Double-cliquez sur un élément ou appuyez sur F2 pour modifier son chemin complet. Suppr le retire, Ctrl+Z annule et Ctrl+Maj+Z ou Ctrl+Y rétablit.")
        catalog.Set(
            "• 发现新版后会先询问；确认后校验完整发行包，退出当前实例、替换受管文件并自动重启，不会覆盖个人配置和升级保护会话。",
                "• Lorsqu'une nouvelle version est disponible, une confirmation est demandée. Le paquet complet est ensuite vérifié, l'instance actuelle est fermée, les fichiers gérés sont remplacés et l'assistant redémarre automatiquement, sans écraser la configuration personnelle ni les sessions de protection des mises à jour.")
        catalog.Set(
            "• 可控的更新脚本可显式发送维护指令：",
                "• Un script de mise à jour que vous contrôlez peut envoyer des commandes de maintenance explicites :")
        catalog.Set(
            "• 在守护对象右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。",
                "• Ouvrez « Protection des mises à jour logicielles » depuis le menu contextuel d'un élément pour régler le répertoire d'installation, la fenêtre de détection de sortie, l'attente de stabilisation des fichiers et l'attente maximale de mise à jour, ou pour effacer les caractéristiques apprises du programme de mise à jour.")
        catalog.Set(
            "• 多个守护对象状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。",
                "• Si tous les éléments sélectionnés ont le même état, le bouton « Suspendre » les suspend ou les reprend ensemble `; si les états sont différents, chacun est inversé.")
        catalog.Set(
            "• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。",
                "• L'assistant compare le chemin ou la ligne de commande de la cible afin d'éviter les erreurs d'identification fondées uniquement sur le nom du processus.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“通用”页会同时显示当前小助手版本、运行形态和实际运行时版本。",
                "• La version de l'assistant et celle d'AutoHotkey sont indépendantes. La page « Général » affiche la version actuelle de l'assistant, son mode d'exécution et la version réelle de l'environnement.")
        catalog.Set(
            "• 程序搜索：仅使用 Everything 服务并显示全部匹配结果；使用前请保持 Everything 正在运行。",
                "• Recherche de programmes : utilise uniquement le service Everything et affiche tous les résultats correspondants. Vérifiez qu'Everything est en cours d'exécution avant la recherche.")
        catalog.Set(
            "• 日志：设置运行日志内存上限、批处理输出日志的保存目录、保留时间和启动时清理策略。",
                "• Journaux : réglez le nombre maximal d'entrées du journal d'exécution en mémoire, le répertoire des journaux de sortie des traitements par lots, leur durée de conservation et leur nettoyage au démarrage.")
        catalog.Set(
            "• 暂停守护对象会取消它的重试和升级检测；恢复后会重新检查目标状态。",
                "• La suspension d'un élément annule ses nouvelles tentatives et sa détection des mises à jour `; lors de la reprise, l'état de la cible est vérifié de nouveau.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“重启等待序列”依次重试；连续失败时采用后续等待时间，避免频繁拉起。",
                "• Lorsqu'un arrêt de la cible est détecté, son état est d'abord confirmé, puis les tentatives suivent la « Séquence d'attente avant redémarrage ». Après plusieurs échecs, les délais suivants sont utilisés afin d'éviter des lancements trop fréquents.")
        catalog.Set(
            "• 每次正式发布开始时都会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版（可能为预发布），冻结本次版本后完成全套测试；只有通过才生成发行包。",
                "• Au début de chaque publication officielle, la dernière version stable d'AutoHotkey et la dernière version publiée d'Ahk2Exe（qui peut être une préversion）sont de nouveau sélectionnées, figées pour cette publication, puis soumises à l'ensemble des tests. Le paquet n'est produit que si tous les tests réussissent.")
        catalog.Set(
            "• 源码版使用电脑当前安装的 AutoHotkey；小助手更新只更新项目源码，不会安装或升级本机解释器。",
                "• L'édition exécutée depuis le code source utilise l'installation actuelle d'AutoHotkey sur l'ordinateur. La mise à jour de l'assistant ne met à jour que le code du projet et n'installe ni ne met à niveau l'interpréteur local.")
        catalog.Set(
            "• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。",
                "• Cliquez sur « Ajouter » pour rechercher une application ou sélectionner des programmes, scripts, raccourcis et dossiers.")
        catalog.Set(
            "• 界面语言和字体可在“通用”中手动切换；保存后立即更新主窗口、菜单和托盘，无需重新启动。",
                "• La langue et la police de l'interface se règlent dans « Général ». L'enregistrement met aussitôt à jour la fenêtre principale, les menus et la zone de notification, sans redémarrage.")
        catalog.Set(
            "• 启动 / 监控：设置状态检查间隔、重启等待序列、启动后是否显示主窗口、是否检查小助手更新，以及文件夹批量导入是否递归。",
                "• Démarrage / Surveillance : réglez l'intervalle de vérification, la séquence d'attente avant redémarrage, l'affichage de la fenêtre principale et la recherche de mises à jour au démarrage, ainsi que le parcours des sous-dossiers lors de l'importation groupée.")
        catalog.Set(
            "• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。",
                "• Après confirmation d'une mise à jour, les lancements automatiques sont suspendus. Lorsque l'activité associée est terminée et que le fichier cible est stable, la surveillance reprend automatiquement. Les caractéristiques du programme de mise à jour détectées au cours d'une mise à jour réelle sont enregistrées automatiquement.")
        catalog.Set(
            "• 程序：EXE、COM、MSC。",
                "• Programmes : EXE, COM et MSC.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，并可立即检查小助手更新。",
                "• Général : créez des raccourcis sur le bureau et dans le menu Démarrer, activez ou désactivez le démarrage automatique par tâche planifiée et recherchez immédiatement les mises à jour de l'assistant.")
        catalog.Set(
            "• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。",
                "• Scripts : AHK, Python, JavaScript, VBScript, PowerShell, fichiers de commandes, mais aussi Ruby, Perl, PHP, Lua, JAR, Shell, etc.")
        catalog.Set(
            "• 软件升级保护默认关闭。需要时在守护对象右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。",
                "• La protection des mises à jour logicielles est désactivée par défaut. Si nécessaire, ouvrez « Protection des mises à jour logicielles » depuis le menu contextuel, cochez « Détecter automatiquement les mises à jour et protéger le processus de démarrage », puis enregistrez.")
        catalog.Set(
            "• 选中守护对象后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。",
                "• Après avoir sélectionné des éléments, vous pouvez les suspendre, les reprendre ou les supprimer. La suspension arrête uniquement la surveillance et ne ferme pas les cibles en cours d'exécution.")
        catalog.Set(
            "• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控”控制。",
                "• La sélection d'un dossier importe en groupe les fichiers compatibles qu'il contient. L'option « Surveillance » de « Configuration » détermine si les sous-dossiers sont également parcourus.")
        catalog.Set(
            "• 守护对象右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。",
                "• « Afficher le journal d'exécution » dans le menu contextuel ouvre le journal de sortie produit par les cibles BAT/CMD. Pour les autres types ou si le journal n'existe pas encore, un message indique que le fichier est introuvable.")
        catalog.Set(
            "⏳ 正在结束运行...",
                "⏳ Arrêt de la cible...")
        catalog.Set(
            "⏳ 判断是否正在升级",
                "⏳ Vérification d'une mise à jour en cours")
        catalog.Set(
            "⏳ 升级完成，准备恢复",
                "⏳ Mise à jour terminée `; préparation de la reprise")
        catalog.Set(
            "⏳ 启动倒计时 {1} 秒",
                "⏳ Démarrage dans {1} secondes")
        catalog.Set(
            "⏳ 启动失败，稍后自动重试",
                "⏳ Échec du démarrage `; nouvelle tentative automatique ultérieure")
        catalog.Set(
            "⏳ 确认升级文件稳定",
                "⏳ Vérification de la stabilité des fichiers de mise à jour")
        catalog.Set(
            "⏳ 确认升级文件稳定 {1}s",
                "⏳ Vérification de la stabilité des fichiers de mise à jour {1}s")
        catalog.Set(
            "⏳ 稍后自动重试 {1} 秒",
                "⏳ Nouvelle tentative automatique dans {1} secondes")
        catalog.Set(
            "⏳ 等待安全启动条件",
                "⏳ Attente de conditions de démarrage sûres")
        catalog.Set(
            "⏳ 等待进程状态...",
                "⏳ Attente de l'état du processus...")
        catalog.Set(
            "⏳ 重试倒计时 {1} 秒",
                "⏳ Nouvelle tentative dans {1} secondes")
        catalog.Set(
            "⏳ 验证运行状态...",
                "⏳ Vérification de l'état d'exécution...")
        catalog.Set(
            "⏸️ 已暂停",
                "⏸️ Suspendu")
        catalog.Set(
            "⏸️ 暂停",
                "⏸️ Suspendre")
        catalog.Set(
            "▶️ 恢复",
                "▶️ Reprendre")
        catalog.Set(
            "⚙️ 启动参数：{1}`n",
                "⚙️ Arguments de lancement : {1}`n")
        catalog.Set(
            "⚠️ 升级等待超时",
                "⚠️ Délai d'attente de mise à jour dépassé")
        catalog.Set(
            "⚠️ 疑似停止",
                "⚠️ Arrêt possible")
        catalog.Set(
            "⚠️ 运行中（权限不符）",
                "⚠️ En cours d'exécution（droits incorrects）")
        catalog.Set(
            "✅ 已启动（非驻留目标）",
                "✅ Démarré（cible non résidente）")
        catalog.Set(
            "✅ 运行中",
                "✅ En cours d'exécution")
        catalog.Set(
            "✅ 运行：{1}   🚫 停止：{2}   ⏳ 恢复：{3}   🔄 升级：{4}   ⏸️ 暂停：{5}   ❌ 失效：{6}   ｜   🎯 总计：{7}",
                "✅ En cours : {1}   🚫 Arrêtés : {2}   ⏳ En attente : {3}   🔄 Mise à jour : {4}   ⏸️ Suspendus : {5}   ❌ Non valides : {6}   ｜   🎯 Total : {7}")
        catalog.Set(
            "✒️ 编辑完整路径（F2）",
                "✒️ Modifier le chemin complet（F2）")
        catalog.Set(
            "确 定",
                "Valider")
        catalog.Set(
            "取 消",
                "Annuler")
        catalog.Set(
            "❌ 无法结束运行",
                "❌ Impossible d'arrêter la cible")
        catalog.Set(
            "❌ 目标不存在",
                "❌ La cible n'existe pas")
        catalog.Set(
            "❌ 程序不存在",
                "❌ Le programme n'existe pas")
        catalog.Set(
            "❌ 脚本不存在",
                "❌ Le script n'existe pas")
        catalog.Set(
            "➕ 添加",
                "➕ Ajouter")
        catalog.Set(
            "。",
                ".")
        catalog.Set(
            "一、快速上手",
                "1. Prise en main rapide")
        catalog.Set(
            "七、软件升级保护",
                "7. Protection des mises à jour logicielles")
        catalog.Set(
            "三、主界面操作",
                "3. Utilisation de la fenêtre principale")
        catalog.Set(
            "不允许的升级保护阶段转换：{1}",
                "Transition de phase de protection des mises à jour non autorisée : {1}")
        catalog.Set(
            "不支持的启动规格类型",
                "Type de spécification de lancement non pris en charge")
        catalog.Set(
            "不支持的图标格式",
                "Format d'icône non pris en charge")
        catalog.Set(
            "不是当前 <HEX> 编码格式",
                "Ce contenu n'utilise pas le format d'encodage <HEX> actuel")
        catalog.Set(
            "与已加载守护对象重复，或目标格式无效",
                "Élément déjà chargé en double ou format de cible non valide")
        catalog.Set(
            "主进程监控",
                "Surveillance du processus principal")
        catalog.Set(
            "主进程监控异常：{1}",
                "Erreur de surveillance du processus principal : {1}")
        catalog.Set(
            "二、支持的守护对象",
                "2. Cibles prises en charge")
        catalog.Set(
            "五、设置",
                "5. Configuration")
        catalog.Set(
            "代码热重载完毕，界面已恢复显示。",
                "Le rechargement à chaud du code est terminé et l'interface est de nouveau affichée.")
        catalog.Set(
            "仲裁期间捕获到升级活动",
                "Activité de mise à jour détectée pendant l'arbitrage")
        catalog.Set(
            "使用说明",
                "Guide d'utilisation")
        catalog.Set(
            "恢复默认",
                "Rétablir")
        catalog.Set(
            "保存",
                "Enregistrer")
        catalog.Set(
            "保存升级保护恢复状态失败：{1}",
                "Échec de l'enregistrement de l'état de reprise de la protection des mises à jour : {1}")
        catalog.Set(
            "保存失败",
                "Échec de l'enregistrement")
        catalog.Set(
            "保存显示设置失败，请查看运行日志。",
                "Impossible d'enregistrer les paramètres d'affichage. Consultez le journal d'exécution.")
        catalog.Set(
            "保存监控配置失败：{1}",
                "Échec de l'enregistrement de la configuration de surveillance : {1}")
        catalog.Set(
            "保存窗口布局失败：{1}",
                "Échec de l'enregistrement de la disposition de la fenêtre : {1}")
        catalog.Set(
            "保存设置失败，请查看运行日志。",
                "Impossible d'enregistrer la configuration. Consultez le journal d'exécution.")
        catalog.Set(
            "保存软件升级保护设置失败，请查看运行日志。",
                "Impossible d'enregistrer les paramètres de protection des mises à jour logicielles. Consultez le journal d'exécution.")
        catalog.Set(
            "保存运行参数失败：{1}",
                "Échec de l'enregistrement des paramètres d'exécution : {1}")
        catalog.Set(
            "值不是 0 或 1",
                "La valeur n'est ni 0 ni 1")
        catalog.Set(
            "停止",
                "Arrêt")
        catalog.Set(
            "八、日志与托盘",
                "8. Journaux et zone de notification")
        catalog.Set(
            "六、版本与小助手自身更新",
                "6. Versions et mise à jour de l'assistant")
        catalog.Set(
            "内容为空",
                "Le contenu est vide")
        catalog.Set(
            "内容无法解析",
                "Impossible d'analyser le contenu")
        catalog.Set(
            "创建快捷方式失败：{1}",
                "Échec de la création du raccourci : {1}")
        catalog.Set(
            "初始化...",
                "Initialisation...")
        catalog.Set(
            "删除选中的守护对象（支持多选，可撤销）`n快捷键：Delete",
                "Supprimer les éléments surveillés sélectionnés（sélection multiple et annulation prises en charge）`nTouche : Suppr")
        catalog.Set(
            "刷新主窗口状态失败，已暂停界面倒计时刷新：{1}",
                "Échec de l'actualisation de la fenêtre principale `; l'actualisation du compte à rebours de l'interface a été suspendue : {1}")
        catalog.Set(
            "刷新运行日志窗口失败，已暂停自动刷新：{1}",
                "Échec de l'actualisation de la fenêtre du journal d'exécution `; l'actualisation automatique a été suspendue : {1}")
        catalog.Set(
            "升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。",
                "La protection des mises à jour ne prend en charge que les programmes ou scripts dotés d'un chemin complet valide. Le répertoire d'installation doit exister et contenir le fichier cible.")
        catalog.Set(
            "升级保护仍在进行",
                "La protection des mises à jour est toujours active")
        catalog.Set(
            "升级保护初始化时无法建立进程基线，将在下一轮重试。",
                "Impossible d'établir l'état de référence des processus pendant l'initialisation de la protection des mises à jour `; une nouvelle tentative aura lieu au prochain cycle.")
        catalog.Set(
            "升级保护协调器未能初始化，核心守护不会启动。",
                "Échec de l'initialisation du coordinateur de protection des mises à jour `; la surveillance principale ne démarrera pas.")
        catalog.Set(
            "升级保护配置",
                "Configuration de la protection des mises à jour")
        catalog.Set(
            "升级文件监听",
                "Surveillance des fichiers de mise à jour")
        catalog.Set(
            "升级文件监听异常（{1}）：{2}",
                "Erreur de surveillance des fichiers de mise à jour（{1}）: {2}")
        catalog.Set(
            "升级文件监听异常：{1}",
                "Erreur de surveillance des fichiers de mise à jour : {1}")
        catalog.Set(
            "升级等待已超时",
                "Délai d'attente de mise à jour dépassé")
        catalog.Set(
            "升级进程扫描",
                "Analyse des processus de mise à jour")
        catalog.Set(
            "升级进程扫描异常：{1}",
                "Erreur d'analyse des processus de mise à jour : {1}")
        catalog.Set(
            "参数错误",
                "Erreur de paramètres")
        catalog.Set(
            "发现小助手新版本：{1}（当前版本：{2}）",
                "Nouvelle version de l'assistant disponible : {1}（version actuelle : {2}）")
        catalog.Set(
            "发现新版本 {1}，当前版本为 {2}。{3}{3}{4}{3}{3}是否立即更新？",
                "La nouvelle version {1} est disponible `; la version actuelle est {2}.{3}{3}{4}{3}{3}Voulez-vous effectuer la mise à jour maintenant ?")
        catalog.Set(
            "取消",
                "Annuler")
        catalog.Set(
            "名称",
                "Nom")
        catalog.Set(
            "后台任务耗时较长：{1}，本次 {2} 毫秒",
                "Une tâche en arrière-plan a pris trop de temps : {1}, soit {2} ms pour cette exécution")
        catalog.Set(
            "后台扫描进程未返回 PID",
                "Le processus d'analyse en arrière-plan n'a pas renvoyé de PID")
        catalog.Set(
            "后台调度任务异常（{1}）：{2}",
                "Erreur d'une tâche planifiée en arrière-plan（{1}）: {2}")
        catalog.Set(
            "后台进程快照为空或不完整，已忽略本次结果并安排重试。",
                "L'instantané des processus en arrière-plan est vide ou incomplet `; ce résultat a été ignoré et une nouvelle tentative est planifiée.")
        catalog.Set(
            "后台进程快照已确认",
                "Instantané des processus en arrière-plan confirmé")
        catalog.Set(
            "后台进程快照未及时返回，已等待完整检测窗口",
                "L'instantané des processus en arrière-plan n'est pas arrivé à temps `; toute la fenêtre de détection a été respectée")
        catalog.Set(
            "启动前没有可用的启动目标，已停止重试：{1}{2}",
                "Aucune cible de lancement n'est disponible avant le démarrage `; les nouvelles tentatives ont été arrêtées : {1}{2}")
        catalog.Set(
            "启动参数",
                "Arguments de lancement")
        catalog.Set(
            "启动参数（Args）：",
                "Arguments de lancement（Args）：")
        catalog.Set(
            "启动器需要 LaunchSpec",
                "Le lanceur nécessite un LaunchSpec")
        catalog.Set(
            "启动失败",
                "Échec du démarrage")
        catalog.Set(
            "启动失败 [{1}/{2}]：{3} - {4}",
                "Échec du démarrage [{1}/{2}] : {3} - {4}")
        catalog.Set(
            "启动成功且运行稳定：{1}",
                "Démarrage réussi et exécution stable : {1}")
        catalog.Set(
            "启动批量导入失败",
                "Échec du lancement de l'importation groupée")
        catalog.Set(
            "启动时检查小助手更新",
                "Rechercher les mises à jour de l'assistant au démarrage")
        catalog.Set(
            "启动时清空批处理日志",
                "Effacer les journaux de traitements par lots au démarrage")
        catalog.Set(
            "启动目标不可用",
                "La cible de lancement n'est pas disponible")
        catalog.Set(
            "启动目标不存在",
                "La cible de lancement n'existe pas")
        catalog.Set(
            "启用状态",
                "État d'activation")
        catalog.Set(
            "四、守护与重启",
                "4. Surveillance et redémarrage")
        catalog.Set(
            "图标来源无效",
                "La source de l'icône n'est pas valide")
        catalog.Set(
            "图标来源：",
                "Source de l'icône：")
        catalog.Set(
            "图标缩放器",
                "Outil de redimensionnement des icônes")
        catalog.Set(
            "处理后台进程快照时发生错误：{1}",
                "Erreur lors du traitement de l'instantané des processus en arrière-plan : {1}")
        catalog.Set(
            "处理应用更新结果失败：{1}",
                "Échec du traitement du résultat de mise à jour de l'application : {1}")
        catalog.Set(
            "字段数量应为 {1}，实际为 {2}",
                "{1} champs étaient attendus, mais {2} ont été trouvés")
        catalog.Set(
            "守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！",
                "Les opérations de surveillance exigent des droits système élevés en lecture et en écriture. Exécutez ce programme en tant qu'administrateur.")
        catalog.Set(
            "守护对象：",
                "Cible surveillée :")
        catalog.Set(
            "安全启动门暂缓启动：{1}（{2}）",
                "La barrière de démarrage sûr a différé le lancement : {1}（{2}）")
        catalog.Set(
            "安装目录特征",
                "Caractéristiques du répertoire d'installation")
        catalog.Set(
            "安装足迹目录：",
                "Répertoire d'installation：")
        catalog.Set(
            "完整路径",
                "Chemin complet")
        catalog.Set(
            "完整路径：{1}",
                "Chemin complet : {1}")
        catalog.Set(
            "导出诊断包",
                "Exporter le paquet de diagnostic")
        catalog.Set(
            "导出诊断包失败：{1}",
                "Échec de l'exportation du paquet de diagnostic : {1}")
        catalog.Set(
            "将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。",
                "Le paquet de distribution complet sera téléchargé et vérifié. Une fois l'assistant fermé, les fichiers du programme seront remplacés et l'assistant redémarrera automatiquement.")
        catalog.Set(
            "将下载并校验源码发行包，保留个人配置后替换源码并自动重启。",
                "L'archive du code source sera téléchargée et vérifiée. Le code sera ensuite remplacé et l'assistant redémarrera automatiquement, tout en conservant votre configuration personnelle.")
        catalog.Set(
            "将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。",
                "L'absence de modifications non validées dans le dépôt source sera vérifiée, puis le dépôt avancera directement jusqu'à l'étiquette de publication officielle avant le redémarrage automatique.")
        catalog.Set(
            "小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。",
                "L'assistant vérifie les programmes, scripts et raccourcis en arrière-plan. Lorsqu'une cible s'arrête anormalement, il la relance selon la séquence d'attente configurée. Fermer la fenêtre principale ne fait que la masquer dans la zone de notification et n'arrête pas la surveillance.")
        catalog.Set(
            "小助手已是最新版本：{1}",
                "L'assistant est déjà à jour : {1}")
        catalog.Set(
            "小助手更新",
                "Mise à jour de l'assistant")
        catalog.Set(
            "小助手设置",
                "Configuration de l'assistant")
        catalog.Set(
            "进程守护小助手更新",
                "Mise à jour de l'Assistant de surveillance des processus")
        catalog.Set(
            "进程守护小助手设置",
                "Configuration de l'Assistant de surveillance des processus")
        catalog.Set(
            "尚未从真实升级过程学习到更新程序特征。",
                "Aucune caractéristique de programme de mise à jour n'a encore été apprise à partir d'une mise à jour réelle.")
        catalog.Set(
            "展示配置",
                "Configuration de l'affichage")
        catalog.Set(
            "工作目录",
                "Répertoire de travail")
        catalog.Set(
            "工作目录（CWD）：",
                "Répertoire de travail（CWD）：")
        catalog.Set(
            "已从本次升级过程学习更新程序特征：{1}",
                "Caractéristiques du programme de mise à jour apprises au cours de cette mise à jour : {1}")
        catalog.Set(
            "已保存身份",
                "Identité enregistrée")
        catalog.Set(
            "已关闭以管理员身份运行：{1}",
                "Exécution en tant qu'administrateur désactivée : {1}")
        catalog.Set(
            "已创建最高权限的开机自启计划任务（Win10 配置，适配笔记本）。",
                "Une tâche planifiée de démarrage automatique dotée des privilèges les plus élevés a été créée（configuration Windows 10 adaptée aux ordinateurs portables）.")
        catalog.Set(
            "已创建桌面与开始菜单快捷方式。",
                "Les raccourcis du bureau et du menu Démarrer ont été créés.")
        catalog.Set(
            "已删除自启计划任务。",
                "La tâche planifiée de démarrage automatique a été supprimée.")
        catalog.Set(
            "已刷新快捷方式内置参数：{1}",
                "Les arguments intégrés du raccourci ont été actualisés : {1}")
        catalog.Set(
            "已刷新快捷方式真实进程（{1}）：{2} -> {3}",
                "Le processus réel du raccourci a été actualisé（{1}）: {2} -> {3}")
        catalog.Set(
            "已发送启动指令：{1}{2}",
                "Commande de démarrage envoyée : {1}{2}")
        catalog.Set(
            "已取消监控：{1}",
                "Surveillance annulée : {1}")
        catalog.Set(
            "已启动批处理并重定向输出到：{1}",
                "Le traitement par lots a démarré et sa sortie est redirigée vers : {1}")
        catalog.Set(
            "已启动非驻留目标：{1}",
                "Cible non résidente démarrée : {1}")
        catalog.Set(
            "已启用以管理员身份运行：{1}",
                "Exécution en tant qu'administrateur activée : {1}")
        catalog.Set(
            "已导出本地诊断包：{1}",
                "Paquet de diagnostic local exporté : {1}")
        catalog.Set(
            "已恢复未完成的升级保护会话：{1}",
                "Une session de protection des mises à jour inachevée a été restaurée : {1}")
        catalog.Set(
            "已撤销上一步操作。",
                "La dernière opération a été annulée.")
        catalog.Set(
            "已更新主窗口显示设置：{1}",
                "Les paramètres d'affichage de la fenêtre principale ont été mis à jour : {1}")
        catalog.Set(
            "已更新守护对象路径。",
                "Le chemin de la cible surveillée a été mis à jour.")
        catalog.Set(
            "已更新软件升级保护设置：{1}",
                "Les paramètres de protection des mises à jour logicielles ont été mis à jour : {1}")
        catalog.Set(
            "已添加 {1} 个守护对象。",
                "{1} éléments surveillés ont été ajoutés.")
        catalog.Set(
            "已用完快速重试，将每隔 {1} 秒继续尝试启动：{2}",
                "Les tentatives rapides sont épuisées `; une nouvelle tentative de démarrage aura lieu toutes les {1} secondes : {2}")
        catalog.Set(
            "已自动学习的更新程序特征：",
                "Caractéristiques du programme de mise à jour apprises automatiquement :")
        catalog.Set(
            "已进入软件升级保护：{1}{2}",
                "La protection des mises à jour logicielles a été activée : {1}{2}")
        catalog.Set(
            "已重做操作。",
                "L'opération a été rétablie.")
        catalog.Set(
            "常规终止权限不足，已提权终止进程 PID：{1}",
                "Les droits étaient insuffisants pour un arrêt normal `; l'arrêt du processus de PID {1} a été exécuté avec élévation.")
        catalog.Set(
            "序号",
                "N°")
        catalog.Set(
            "应用更新助手不存在",
                "L'assistant de mise à jour de l'application est introuvable")
        catalog.Set(
            "应用更新参数无效",
                "Les paramètres de mise à jour de l'application ne sont pas valides")
        catalog.Set(
            "应用更新安装进程未返回 PID",
                "Le processus d'installation de la mise à jour n'a pas renvoyé de PID")
        catalog.Set(
            "应用更新本地化资源不存在",
                "Les ressources de localisation de la mise à jour de l'application sont introuvables")
        catalog.Set(
            "应用更新检查进程未返回 PID",
                "Le processus de recherche des mises à jour n'a pas renvoyé de PID")
        catalog.Set(
            "守护对象",
                "Cible surveillée")
        catalog.Set(
            "应用资源",
                "Ressources de l'application")
        catalog.Set(
            "开机自动启动（计划任务）",
                "Démarrage automatique à l'ouverture de session（tâche planifiée）")
        catalog.Set(
            "当前陪伴您的已经是最新版本的小助手啦！",
                "L'assistant qui vous accompagne est déjà à jour !")
        catalog.Set(
            "当前应用版本无效",
                "La version actuelle de l'application n'est pas valide")
        catalog.Set(
            "当前版本：{1}（EXE 版；内嵌 AutoHotkey {2} x64）",
                "Version actuelle : {1}（édition EXE `; AutoHotkey {2} x64 intégré）")
        catalog.Set(
            "当前版本：{1}（源码版；本机 AutoHotkey {2} x64）",
                "Version actuelle : {1}（édition source `; AutoHotkey local {2} x64）")
        catalog.Set(
            "当前状态：升级活动已结束，正在确认程序文件稳定",
                "État actuel : l'activité de mise à jour est terminée `; vérification de la stabilité des fichiers du programme")
        catalog.Set(
            "当前状态：升级等待超时，需要确认后恢复",
                "État actuel : délai d'attente de mise à jour dépassé `; confirmation requise pour reprendre")
        catalog.Set(
            "当前状态：已从上次运行恢复未完成的升级保护",
                "État actuel : restauration de la protection des mises à jour laissée inachevée lors de l'exécution précédente")
        catalog.Set(
            "当前状态：已暂停自动启动，正在等待升级完成",
                "État actuel : démarrage automatique suspendu dans l'attente de la fin de la mise à jour")
        catalog.Set(
            "当前状态：显式升级维护已开始，正在等待结束命令",
                "État actuel : maintenance de mise à jour explicite commencée `; attente de la commande de fin")
        catalog.Set(
            "当前状态：正在判断本次退出是否由升级引起",
                "État actuel : vérification si cette fermeture a été provoquée par une mise à jour")
        catalog.Set(
            "当前状态：正常守护",
                "État actuel : surveillance normale")
        catalog.Set(
            "快捷方式参数",
                "Arguments du raccourci")
        catalog.Set(
            "快捷方式及已解析目标均不可用",
                "Le raccourci et sa cible résolue sont tous deux indisponibles")
        catalog.Set(
            "快捷方式目标",
                "Cible du raccourci")
        catalog.Set(
            "快捷方式真实目标",
                "Cible réelle du raccourci")
        catalog.Set(
            "快捷方式真实进程刷新被拒绝，目标已由其它守护对象守护：{1} -> {2}",
                "Actualisation du processus réel du raccourci refusée, car la cible est déjà surveillée par un autre élément : {1} -> {2}")
        catalog.Set(
            "恢复守护：{1}",
                "Reprendre la surveillance : {1}")
        catalog.Set(
            "恢复记录列表无效",
                "La liste des enregistrements de restauration n'est pas valide")
        catalog.Set(
            "恢复记录无效",
                "L'enregistrement de restauration n'est pas valide")
        catalog.Set(
            "恢复记录缺少字段：{1}",
                "Il manque un champ dans l'enregistrement de restauration : {1}")
        catalog.Set(
            "成功",
                "Réussite")
        catalog.Set(
            "所选文件夹内未找到支持的程序、脚本或快捷方式。",
                "Aucun programme, script ou raccourci pris en charge n'a été trouvé dans le dossier sélectionné.")
        catalog.Set(
            "手动添加守护对象：{1}",
                "Surveillance ajoutée manuellement : {1}")
        catalog.Set(
            "已结束运行：{1}",
                "Cible arrêtée : {1}")
        catalog.Set(
            "结束运行失败，目标进程未能停止：{1}",
                "Impossible d'arrêter le processus cible : {1}")
        catalog.Set(
            "托管窗口生命周期尚未配置",
                "Le cycle de vie de la fenêtre gérée n'est pas encore configuré")
        catalog.Set(
            "托管窗口生命周期适配器无效",
                "L'adaptateur du cycle de vie de la fenêtre gérée n'est pas valide")
        catalog.Set(
            "扩展设置包含无效数值。`n`n窗口程序关闭等待：1-300 秒`n命令行程序退出等待：1-60 秒`n日志条数：50-10000`n日志保留：1-3650 天",
                "Un ou plusieurs paramètres avancés sont incorrects.`n`nDélai de fermeture des applications avec fenêtre : 1 à 300 secondes`nDélai de sortie des applications en ligne de commande : 1 à 60 secondes`nNombre d'entrées du journal : 50 à 10 000`nConservation des journaux : 1 à 3 650 jours")
        catalog.Set(
            "批处理启动需要输出日志路径",
                "Le lancement d'un traitement par lots nécessite un chemin de journal de sortie")
        catalog.Set(
            "批量导入中断",
                "Importation groupée interrompue")
        catalog.Set(
            "批量导入完成",
                "Importation groupée terminée")
        catalog.Set(
            "批量导入已取消，已保留并保存此前添加的 {1} 个守护对象。",
                "L'importation groupée a été annulée. Les {1} éléments surveillés ajoutés précédemment ont été conservés et enregistrés.")
        catalog.Set(
            "拒绝修改路径，真实进程已由其它守护对象守护：{1}",
                "Modification du chemin refusée, car le processus réel est déjà surveillé par un autre élément : {1}")
        catalog.Set(
            "拒绝更新路径，已存在相同的守护对象：{1}",
                "Modification du chemin refusée, car une cible surveillée identique existe déjà : {1}")
        catalog.Set(
            "按钮绘制器",
                "Moteur de dessin des boutons")
        catalog.Set(
            "捕获守护对象历史失败：{1}",
                "Échec de la capture de l'historique des éléments surveillés : {1}")
        catalog.Set(
            "提示",
                "Information")
        catalog.Set(
            "⚡️搜索⚡️",
                "⚡️ Recherche ⚡️")
        catalog.Set(
            "操作计划任务时发生错误！`n`n{1}",
                "Une erreur s'est produite lors de l'utilisation de la tâche planifiée.`n`n{1}")
        catalog.Set(
            "支持的图标与图片",
                "Icônes et images prises en charge")
        catalog.Set(
            "支持的程序、脚本与快捷方式",
                "Programmes, scripts et raccourcis pris en charge")
        catalog.Set(
            "支持的程序与脚本",
                "Programmes et scripts pris en charge")
        catalog.Set(
            "收到显式维护开始命令",
                "Commande explicite de début de maintenance reçue")
        catalog.Set(
            "收到显式维护结束命令，开始执行安全恢复检查：{1}",
                "Commande explicite de fin de maintenance reçue `; lancement de la vérification de reprise sûre : {1}")
        catalog.Set(
            "整条展示配置",
                "Configuration d'affichage complète")
        catalog.Set(
            "整条记录",
                "Enregistrement complet")
        catalog.Set(
            "文件稳定等待（秒）：",
                "Attente de stabilisation du fichier（secondes）：")
        catalog.Set(
            "新脚本未通过 AutoHotkey 解析检查",
                "Le nouveau script n'a pas réussi la vérification d'analyse d'AutoHotkey")
        catalog.Set(
            "无法从损坏记录中提取",
                "Impossible d'extraire les informations de l'enregistrement endommagé")
        catalog.Set(
            "无法停止进程 PID：{1}{2}",
                "Impossible d'arrêter le processus de PID {1}{2}")
        catalog.Set(
            "无法写入诊断文件：{1}",
                "Impossible d'écrire le fichier de diagnostic : {1}")
        catalog.Set(
            "无法启动后台文件扫描：{1}",
                "Impossible de démarrer l'analyse des fichiers en arrière-plan : {1}")
        catalog.Set(
            "无法启动后台进程快照任务：{1}",
                "Impossible de démarrer la tâche d'instantané des processus en arrière-plan : {1}")
        catalog.Set(
            "无法启动小助手更新安装：{1}",
                "Impossible de démarrer l'installation de la mise à jour de l'assistant : {1}")
        catalog.Set(
            "无法启动小助手更新检查：{1}",
                "Impossible de démarrer la recherche des mises à jour de l'assistant : {1}")
        catalog.Set(
            "无法导出诊断包：`n{1}",
                "Impossible d'exporter le paquet de diagnostic :`n{1}")
        catalog.Set(
            "无法建立单实例运行锁，小助手将退出。",
                "Impossible d'obtenir le verrou d'instance unique `; l'assistant va quitter.")
        catalog.Set(
            "无法开始更新：{1}",
                "Impossible de démarrer la mise à jour : {1}")
        catalog.Set(
            "无法收集此部分诊断信息：{1}",
                "Impossible de recueillir cette partie des informations de diagnostic : {1}")
        catalog.Set(
            "无法检查更新：{1}",
                "Impossible de rechercher les mises à jour : {1}")
        catalog.Set(
            "无法清理后台扫描临时文件：{1}",
                "Impossible de nettoyer le fichier temporaire de l'analyse en arrière-plan : {1}")
        catalog.Set(
            "无法清理后台扫描结果文件：{1}",
                "Impossible de nettoyer le fichier de résultats de l'analyse en arrière-plan : {1}")
        catalog.Set(
            "无法生成守护对象快照：{1}",
                "Impossible de créer l'instantané des éléments surveillés : {1}")
        catalog.Set(
            "日志",
                "Journal")
        catalog.Set(
            "日志文件不存在：{1}",
                "Le fichier journal n'existe pas : {1}")
        catalog.Set("📄 查看批处理输出日志", "📄 Afficher le journal de sortie batch")
        catalog.Set("尚未生成批处理输出日志", "Aucun journal de sortie batch pour le moment")
        catalog.Set(
            "小助手只有在启动 BAT 或 CMD 守护对象时才会创建此文件。",
                "Ce fichier est créé uniquement lorsque l’assistant lance un élément BAT ou CMD.")
        catalog.Set("日志保存位置：", "Emplacement du journal :")
        catalog.Set("确定", "OK")
        catalog.Set(
            "时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间",
                "Les réglages de durée ne sont pas valides.`n`nFenêtre de détection de sortie : 2-120 secondes`nAttente de stabilisation du fichier : 2-300 secondes`nAttente maximale de mise à jour : 60-86400 secondes et doit être supérieure à l'attente de stabilisation")
        catalog.Set(
            "显式升级维护命令执行异常：{1}",
                "Erreur lors de l'exécution de la commande explicite de maintenance de mise à jour : {1}")
        catalog.Set(
            "显式升级维护命令未找到监控目标：{1}",
                "La commande explicite de maintenance de mise à jour n'a trouvé aucune cible surveillée : {1}")
        catalog.Set(
            "显式升级维护命令被忽略，目标未启用升级保护：{1}",
                "La commande explicite de maintenance de mise à jour a été ignorée, car la protection des mises à jour n'est pas activée pour la cible : {1}")
        catalog.Set(
            "显示主界面",
                "Afficher l'interface principale")
        catalog.Set(
            "显示名称：",
                "Nom affiché：")
        catalog.Set(
            "暂停守护：{1}",
                "Suspendre la surveillance : {1}")
        catalog.Set(
            "暂停或恢复选中守护对象，不会退出目标`n支持多选；混合状态时逐项反转`n快捷键：Space",
                "Suspendre ou reprendre la surveillance des éléments sélectionnés sans fermer les cibles`nSélection multiple prise en charge `; si les états sont différents, chacun est inversé`nRaccourci : Espace")
        catalog.Set(
            "暂时无法查询进程状态，稍后重试结束运行：{1}",
                "Impossible de consulter temporairement l'état du processus `; l'arrêt sera retenté plus tard : {1}")
        catalog.Set(
            "暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                "Impossible de vérifier temporairement les processus existants `; le lancement est différé afin d'éviter les instances en double : {1}")
        catalog.Set(
            "暂时无法结束运行",
                "Arrêt temporairement impossible")
        catalog.Set(
            "更新助手已启动，小助手即将退出并完成更新。",
                "L'assistant de mise à jour a démarré. L'assistant va quitter afin de terminer la mise à jour.")
        catalog.Set(
            "更新应用搜索结果失败：{1}",
                "Échec de l'actualisation des résultats de recherche d'applications : {1}")
        catalog.Set(
            "更新检查未返回结果",
                "La recherche des mises à jour n'a renvoyé aucun résultat")
        catalog.Set(
            "更新检查正在进行，请稍候。",
                "Une recherche de mises à jour est déjà en cours. Veuillez patienter.")
        catalog.Set(
            "更新检查返回了无法识别的状态：{1}",
                "La recherche des mises à jour a renvoyé un état inconnu : {1}")
        catalog.Set(
            "最长升级等待（秒）：",
                "Attente maximale de mise à jour（secondes）：")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），恢复普通重启流程：{3}",
                "Aucune activité de mise à jour détectée（{1}, durée de {2} secondes）`; reprise de la procédure de redémarrage normale : {3}")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），目标仍不存在：{3}",
                "Aucune activité de mise à jour détectée（{1}, durée de {2} secondes）et la cible est toujours absente : {3}")
        catalog.Set(
            "未找到目标",
                "Cible introuvable")
        catalog.Set(
            "未添加",
                "Non ajouté")
        catalog.Set(
            "未知升级保护阶段",
                "Phase de protection des mises à jour inconnue")
        catalog.Set(
            "未知守护阶段",
                "Phase de surveillance inconnue")
        catalog.Set(
            "未知版本",
                "Version inconnue")
        catalog.Set(
            "未知解析错误",
                "Erreur d'analyse inconnue")
        catalog.Set(
            "未知错误",
                "Erreur inconnue")
        catalog.Set(
            "查看实时运行日志`n涵盖监控、重启、升级保护与操作记录",
                "Afficher le journal d'exécution en temps réel`nInclut les événements de surveillance, de redémarrage, de protection des mises à jour et d'utilisation")
        catalog.Set(
            "查看支持类型、操作方法、守护设置`n以及升级保护说明",
                "Afficher les types pris en charge, le mode d'emploi et les réglages de surveillance`nAinsi que les instructions relatives à la protection des mises à jour")
        catalog.Set(
            "核心守护",
                "Surveillance principale")
        catalog.Set(
            "核心守护计时器启动失败。",
                "Échec du démarrage du minuteur de surveillance principale.")
        catalog.Set(
            "桌面与开始菜单快捷方式",
                "Raccourcis du bureau et du menu Démarrer")
        catalog.Set(
            "创建成功！",
                "Créés !")
        catalog.Set(
            "检查小助手更新",
                "Rechercher les mises à jour de l'assistant")
        catalog.Set(
            "检查小助手更新失败：{1}",
                "Échec de la recherche des mises à jour de l'assistant : {1}")
        catalog.Set(
            "检查更新",
                "Rechercher les mises à jour")
        catalog.Set(
            "检查更新失败：{1}",
                "Échec de la recherche des mises à jour : {1}")
        catalog.Set(
            "检查更新超时",
                "Délai de recherche des mises à jour dépassé")
        catalog.Set(
            "检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。",
                "Une tâche planifiée portant le même nom a été détectée, mais elle n'a pas été créée par ce programme. Afin d'éviter de la supprimer par erreur, gérez-la d'abord dans le Planificateur de tâches.")
        catalog.Set(
            "检测到安装目录变化",
                "Modification du répertoire d'installation détectée")
        catalog.Set(
            "检测到相关安装进程",
                "Processus d'installation associé détecté")
        catalog.Set(
            "检测到程序文件变化",
                "Modification des fichiers du programme détectée")
        catalog.Set(
            "检测到运行中的目标未使用管理员权限：{1}",
                "La cible en cours d'exécution n'utilise pas les droits d'administrateur : {1}")
        catalog.Set(
            "检测到进程停止，准备重启：{1}（将在 {2} 秒后启动）",
                "Arrêt du processus détecté `; préparation du redémarrage : {1}（démarrage dans {2} secondes）")
        catalog.Set(
            "正在扫描...",
                "Analyse en cours...")
        catalog.Set(
            "正在扫描文件夹，可点击取消停止",
                "Analyse du dossier en cours `; cliquez sur Annuler pour l'arrêter")
        catalog.Set(
            "正在扫描：{1}",
                "Analyse en cours : {1}")
        catalog.Set(
            "正在添加扫描结果...",
                "Ajout des résultats de l'analyse...")
        catalog.Set(
            "正在添加：{1} / {2}",
                "Ajout : {1} / {2}")
        catalog.Set(
            "正常关闭超时后允许强制终止",
                "Autoriser l'arrêt forcé après expiration du délai de fermeture normale")
        catalog.Set(
            "正常关闭超时，已强制终止进程 PID：{1}",
                "Délai de fermeture normale dépassé `; arrêt forcé du processus de PID {1}")
        catalog.Set(
            "正常关闭超时，已按设置跳过强制终止 PID：{1}",
                "Délai de fermeture normale dépassé `; conformément à la configuration, l'arrêt forcé du PID {1} a été ignoré")
        catalog.Set(
            "没有可安装的应用更新",
                "Aucune mise à jour d'application ne peut être installée")
        catalog.Set(
            "浏览",
                "Parcourir")
        catalog.Set(
            "添加扫描结果失败",
                "Échec de l'ajout des résultats de l'analyse")
        catalog.Set(
            "添加守护对象",
                "Ajouter un élément surveillé")
        catalog.Set(
            "添加守护对象失败，已回滚内存状态：{1}",
                "Échec de l'ajout de l'élément surveillé `; l'état en mémoire a été rétabli : {1}")
        catalog.Set(
            "添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放",
                "Ajouter un programme, un script ou un raccourci`nRecherche, importation groupée de dossiers et glisser-déposer de fichiers pris en charge")
        catalog.Set(
            "清除记录",
                "Effacer les enregistrements")
        catalog.Set(
            "状态",
                "État")
        catalog.Set(
            "独立环境配置 💡`n",
                "Configuration d'environnement indépendante 💡`n")
        catalog.Set(
            "环境变量",
                "Variables d'environnement")
        catalog.Set(
            "环境变量（每行一个 KEY=VALUE）：",
                "Variables d'environnement（une valeur KEY=VALUE par ligne）：")
        catalog.Set(
            "用户指定",
                "Indiqué par l'utilisateur")
        catalog.Set(
            "用户结束了升级等待，重新执行安全启动检查：{1}",
                "L'utilisateur a mis fin à l'attente de mise à jour `; nouvelle vérification du démarrage sûr : {1}")
        catalog.Set(
            "界面语言和字体已即时更新，无需重新启动小助手。",
                "La langue et la police de l'interface ont été mises à jour immédiatement`; aucun redémarrage de l'assistant n'est nécessaire.")
        catalog.Set(
            "更新配置注释语言失败：{1}",
                "Impossible de mettre à jour la langue des commentaires de configuration : {1}")
        catalog.Set(
            "；恢复配置失败：{1}",
                "`; la restauration de la configuration a également échoué : {1}")
        catalog.Set(
            "界面显示设置无法即时应用，已恢复原语言和字体：{1}",
                "Impossible d'appliquer immédiatement les paramètres d'affichage. La langue et la police précédentes ont été rétablies : {1}")
        catalog.Set(
            "无法即时切换界面语言或字体，原显示设置已恢复。`n`n{1}",
                "Impossible de changer immédiatement la langue ou la police de l'interface. Les paramètres d'affichage précédents ont été rétablis.`n`n{1}")
        catalog.Set(
            "显示设置应用失败",
                "Impossible d'appliquer les paramètres d'affichage")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Police par défaut de la langue（{1}）")
        catalog.Set(
            "正在检查更新…",
                "Recherche de mises à jour…")
        catalog.Set(
            "`; UiFont：界面字体；auto 表示使用当前语言的默认字体，也可填写本机已安装字体名称。",
                "`; UiFont : police de l'interface. auto utilise la police par défaut de la langue active `; le nom d'une police installée peut aussi être indiqué.")
        catalog.Set(
            "界面语言：",
                "Langue de l'interface：")
        catalog.Set(
            "界面资源",
                "Ressources de l'interface")
        catalog.Set("启动", "Démarrage")
        catalog.Set("监控", "Surveillance")
        catalog.Set(
            "守护对象重复",
                "Cible de surveillance en double")
        catalog.Set(
            "监控配置加载异常",
                "Erreur de chargement de la configuration de surveillance")
        catalog.Set(
            "监控配置加载异常：共 {1} 条记录未能载入。",
                "Erreur de chargement de la configuration de surveillance : {1} enregistrements n'ont pas pu être chargés.")
        catalog.Set(
            "监控配置尚未保存，请查看运行日志。",
                "La configuration de surveillance n'a pas encore été enregistrée. Consultez le journal d'exécution.")
        catalog.Set(
            "守护对象保存状态无效",
                "L'état d'enregistrement de l'élément surveillé n'est pas valide")
        catalog.Set(
            "守护对象注册回调无效",
                "Le rappel d'enregistrement de l'élément surveillé n'est pas valide")
        catalog.Set(
            "守护对象路径无效：{1}",
                "Le chemin de l'élément surveillé n'est pas valide : {1}")
        catalog.Set(
            "监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核：{1}",
                "Le fichier cible n'existe plus. La surveillance est passée à l'état « fichier absent » et le vérifiera automatiquement lorsqu'il réapparaîtra : {1}")
        catalog.Set(
            "目标任务需要 WatchdogScheduler",
                "La tâche cible nécessite WatchdogScheduler")
        catalog.Set(
            "目标文件已恢复，重新核对运行状态：{1}",
                "Le fichier cible a réapparu `; nouvelle vérification de l'état d'exécution : {1}")
        catalog.Set(
            "目标文件缺失时检测到升级活动",
                "Activité de mise à jour détectée alors que le fichier cible était absent")
        catalog.Set(
            "目标程序文件不存在",
                "Le fichier du programme cible n'existe pas")
        catalog.Set(
            "目标程序：{1}",
                "Programme cible : {1}")
        catalog.Set(
            "目标路径",
                "Chemin de la cible")
        catalog.Set(
            "目标退出时检测到升级信号",
                "Signal de mise à jour détecté lors de la fermeture de la cible")
        catalog.Set(
            "真实目标来源标记",
                "Indicateur de source de la cible réelle")
        catalog.Set(
            "真实进程路径无效",
                "Le chemin du processus réel n'est pas valide")
        catalog.Set(
            "确 定",
                "Valider")
        catalog.Set(
            "程序文件刚刚发生变化",
                "Le fichier du programme vient d'être modifié")
        catalog.Set(
            "程序文件尚未达到稳定等待时间",
                "Le fichier du programme n'a pas encore atteint la durée de stabilité requise")
        catalog.Set(
            "程序文件正在写入或结构不完整",
                "Le fichier du programme est en cours d'écriture ou sa structure est incomplète")
        catalog.Set(
            "稍后",
                "Plus tard")
        catalog.Set(
            "窗口层级平台适配器无效",
                "L'adaptateur de plateforme de la hiérarchie des fenêtres n'est pas valide")
        catalog.Set(
            "窗口层级管理器无效",
                "Le gestionnaire de hiérarchie des fenêtres n'est pas valide")
        catalog.Set(
            "窗口布局字段不是整数：{1}",
                "Le champ de disposition de fenêtre n'est pas un entier : {1}")
        catalog.Set(
            "窗口布局字段超出范围：{1}",
                "Le champ de disposition de fenêtre est hors limites : {1}")
        catalog.Set(
            "窗口布局对象无效",
                "L'objet de disposition de fenêtre n'est pas valide")
        catalog.Set(
            "立即更新",
                "Mettre à jour maintenant")
        catalog.Set(
            "等待 {1} 秒后进行第 {2} 次尝试...",
                "Attendez {1} secondes avant la tentative {2}...")
        catalog.Set(
            "管理员运行状态",
                "État d'exécution en tant qu'administrateur")
        catalog.Set(
            "系统 PowerShell 不可用",
                "PowerShell système n'est pas disponible")
        catalog.Set(
            "系统压缩工具未能创建诊断包",
                "L'outil de compression système n'a pas pu créer le paquet de diagnostic")
        catalog.Set(
            "系统权限拦截",
                "Bloqué par les autorisations système")
        catalog.Set(
            "通用",
                "Général")
        catalog.Set(
            "显示",
                "Affichage")
        catalog.Set(
            "结束升级等待并恢复守护",
                "Terminer l'attente de mise à jour et reprendre la surveillance")
        catalog.Set(
            "编码损坏",
                "Encodage endommagé")
        catalog.Set(
            "缺少窗口布局字段：{1}",
                "Champ de disposition de fenêtre manquant : {1}")
        catalog.Set(
            "缺少窗口生命周期回调：{1}",
                "Rappel de cycle de vie de fenêtre manquant : {1}")
        catalog.Set(
            "缺少诊断信息提供器：{1}",
                "Fournisseur d'informations de diagnostic manquant : {1}")
        catalog.Set(
            "缺少运行参数：{1}",
                "Paramètre d'exécution manquant : {1}")
        catalog.Set(
            "自动",
                "Automatique")
        catalog.Set(
            "自动识别升级并保护启动过程",
                "Détecter automatiquement les mises à jour et protéger le processus de démarrage")
        catalog.Set(
            "自动识别进程",
                "Identifier automatiquement le processus")
        catalog.Set(
            "自定义名称",
                "Nom personnalisé")
        catalog.Set(
            "自定义图标",
                "Icône personnalisée")
        catalog.Set(
            "计划任务冲突",
                "Conflit de tâche planifiée")
        catalog.Set(
            "计划任务操作失败：{1}",
                "Échec de l'opération sur la tâche planifiée : {1}")
        catalog.Set(
            "设置已更新：轮询={1}ms，序列=[{2}]，日志上限={3}",
                "Configuration mise à jour : interrogation={1}ms, séquence=[{2}], limite du journal={3}")
        catalog.Set(
            "设置无效",
                "Configuration non valide")
        catalog.Set(
            "诊断临时目录已存在",
                "Le répertoire temporaire de diagnostic existe déjà")
        catalog.Set(
            "诊断包保存目录不存在",
                "Le répertoire d'enregistrement du paquet de diagnostic n'existe pas")
        catalog.Set(
            "诊断包已导出到：`n{1}",
                "Paquet de diagnostic exporté vers :`n{1}")
        catalog.Set(
            "诊断包目标文件名已被占用",
                "Le nom de fichier cible du paquet de diagnostic est déjà utilisé")
        catalog.Set(
            "诊断压缩包未生成",
                "L'archive de diagnostic n'a pas été produite")
        catalog.Set(
            "该文件不是受支持的图标或图片格式。`n`n支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。",
                "Ce fichier n'utilise pas un format d'icône ou d'image pris en charge.`n`nFormats pris en charge : ICO, EXE, DLL, CPL, LNK, PNG, JPG, JPEG, JPE, JFIF, BMP, GIF, TIF, TIFF, WebP, SVG et ANI.")
        catalog.Set(
            "该目标已存在、无效或指向目录。",
                "Cette cible existe déjà, n'est pas valide ou désigne un répertoire.")
        catalog.Set(
            "该真实进程已由其他守护对象守护。",
                "Ce processus réel est déjà protégé par un autre élément surveillé.")
        catalog.Set(
            "该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再结束运行。",
                "Ce logiciel est sous protection de mise à jour. Attendez la fin de la mise à jour ou terminez l'attente dans « Protection des mises à jour logicielles » avant de l'arrêter.")
        catalog.Set(
            "语义版本无效",
                "La version sémantique n'est pas valide")
        catalog.Set(
            "请通过上方按钮搜索或选择，或在下方填写进程名或目标路径：`n【支持程序、脚本、快捷方式，以及文件夹批量导入】",
                "Recherchez ou sélectionnez avec les boutons ci-dessus.`nSinon, saisissez ci-dessous un nom de processus ou un chemin cible.`n【Prend en charge programmes, scripts, raccourcis et importation groupée de dossiers】")
        catalog.Set(
            "请选择现有且可执行的真实程序或脚本路径。",
                "Sélectionnez le chemin existant et exécutable d'un programme ou script réel.")
        catalog.Set(
            "请选择现有的图标、程序、资源库或快捷方式文件。",
                "Sélectionnez un fichier existant d'icône, de programme, de bibliothèque de ressources ou de raccourci.")
        catalog.Set(
            "读取后台扫描结果失败",
                "Échec de la lecture des résultats de l'analyse en arrière-plan")
        catalog.Set(
            "调度器已停止",
                "Le planificateur est arrêté")
        catalog.Set(
            "跟随系统",
                "Suivre le système")
        catalog.Set(
            "路径",
                "Chemin")
        catalog.Set(
            "轮询间隔必须为 500-86400000 毫秒的正整数！",
                "L'intervalle d'interrogation doit être un entier positif compris entre 500 et 86400000 millisecondes.")
        catalog.Set(
            "软件升级保护",
                "Protection des mises à jour logicielles")
        catalog.Set(
            "软件升级保护超过最长等待时间，需要用户确认后恢复：{1}",
                "La protection des mises à jour logicielles a dépassé l'attente maximale `; une confirmation de l'utilisateur est nécessaire pour reprendre : {1}")
        catalog.Set(
            "软件升级完成，准备恢复启动：{1}",
                "La mise à jour logicielle est terminée `; préparation de la reprise du démarrage : {1}")
        catalog.Set(
            "软件升级完成，已恢复正常守护：{1}",
                "La mise à jour logicielle est terminée `; la surveillance normale a repris : {1}")
        catalog.Set(
            "载入中...",
                "Chargement...")
        catalog.Set(
            "运行参数不是支持的界面语言：{1}",
                "Le paramètre d'exécution n'est pas une langue d'interface prise en charge : {1}")
        catalog.Set(
            "运行参数不是整数：{1}",
                "Le paramètre d'exécution n'est pas un entier : {1}")
        catalog.Set(
            "运行参数不能为空：{1}",
                "Le paramètre d'exécution ne peut pas être vide : {1}")
        catalog.Set(
            "运行参数对象无效",
                "L'objet des paramètres d'exécution n'est pas valide")
        catalog.Set(
            "运行参数超出范围：{1}",
                "Le paramètre d'exécution est hors limites : {1}")
        catalog.Set(
            "运行日志",
                "Journal d'exécution")
        catalog.Set(
            "进程仍在运行，忽略重复启动：{1}",
                "Le processus est toujours en cours d'exécution `; le lancement en double est ignoré : {1}")
        catalog.Set(
            "进程启动后迅速退出或未成功常驻后台",
                "Le processus s'est fermé peu après son lancement ou n'a pas réussi à rester actif en arrière-plan")
        catalog.Set(
            "进程守护小助手",
                "Assistant de surveillance des processus")
        catalog.Set(
            "持续守护重要程序与自动化任务，让日常工作稳定运行",
                "Gardez vos applications et automatisations essentielles stables au quotidien")
        catalog.Set(
            "进程守护小助手 - 开机自启守护程序",
                "Assistant de surveillance des processus - Surveillance au démarrage")
        catalog.Set(
            "进程守护小助手已静默启动。",
                "L'Assistant de surveillance des processus a démarré en mode silencieux.")
        catalog.Set(
            "退出检测窗口（秒）：",
                "Fenêtre de détection de sortie（secondes）：")
        catalog.Set(
            "退出清理异常（{1}）：{2}",
                "Erreur de nettoyage à la fermeture（{1}）: {2}")
        catalog.Set(
            "退出程序",
                "Quitter le programme")
        catalog.Set(
            "选择主窗口图标",
                "Sélectionner l'icône de la fenêtre principale")
        catalog.Set(
            "选择工作目录",
                "Sélectionner le répertoire de travail")
        catalog.Set(
            "选择快捷方式对应的真实进程",
                "Sélectionner le processus réel correspondant au raccourci")
        catalog.Set(
            "选择批处理日志目录",
                "Sélectionner le répertoire des journaux de traitements par lots")
        catalog.Set(
            "选择文件",
                "Sélectionner un fichier")
        catalog.Set(
            "选择文件夹",
                "Sélectionner un dossier")
        catalog.Set(
            "选择要监控的文件",
                "Sélectionner le fichier à surveiller")
        catalog.Set(
            "选择要监控的文件夹",
                "Sélectionner le dossier à surveiller")
        catalog.Set(
            "选择诊断包保存位置",
                "Sélectionner l'emplacement d'enregistrement du paquet de diagnostic")
        catalog.Set(
            "选择软件安装目录",
                "Sélectionner le répertoire d'installation du logiciel")
        catalog.Set(
            "通过拖拽添加了 {1} 个守护对象。",
                "{1} éléments surveillés ont été ajoutés par glisser-déposer.")
        catalog.Set(
            "配置仓储无效",
                "Le dépôt de configuration n'est pas valide")
        catalog.Set(
            "配置写入器无效",
                "Le composant d'écriture de la configuration n'est pas valide")
        catalog.Set(
            "配置文件写入事务正在进行",
                "Une transaction d'écriture du fichier de configuration est en cours")
        catalog.Set(
            "重新加载",
                "Recharger")
        catalog.Set(
            "重新加载失败",
                "Échec du rechargement")
        catalog.Set(
            "重新加载失败，已保留当前实例：{1}",
                "Échec du rechargement `; l'instance actuelle a été conservée : {1}")
        catalog.Set(
            "重新加载失败，当前守护仍在运行。`n`n{1}",
                "Échec du rechargement `; la surveillance actuelle continue de fonctionner.`n`n{1}")
        catalog.Set(
            "重试序列不能为空！",
                "La séquence de nouvelles tentatives ne peut pas être vide.")
        catalog.Set(
            "重试序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "Le format de la séquence de nouvelles tentatives est incorrect. Elle doit contenir des entiers positifs séparés par des virgules（par exemple : 1,10,60）, chacun compris entre 1 et 86400 secondes.")
        catalog.Set(
            "重试延迟序列不能为空",
                "La séquence de délais avant nouvelle tentative ne peut pas être vide")
        catalog.Set(
            "重试延迟序列无效",
                "La séquence de délais avant nouvelle tentative n'est pas valide")
        catalog.Set(
            "错误",
                "Erreur")
        catalog.Set(
            "名称：{1}`n真实路径：{2}",
                "Nom : {1}`nChemin réel : {2}")
        catalog.Set(
            "🌿 环境变量：{1} 项`n",
                "🌿 Variables d'environnement : {1}`n")
        catalog.Set(
            "🎨 自定义名称和图标",
                "🎨 Personnaliser le nom et l'icône")
        catalog.Set(
            "📁 工作目录：{1}`n",
                "📁 Répertoire de travail : {1}`n")
        catalog.Set(
            "📂 打开所在位置",
                "📂 Ouvrir l'emplacement")
        catalog.Set(
            "📂 浏览文件夹...",
                "📂 Parcourir les dossiers...")
        catalog.Set(
            "选择...",
                "Sélectionner...")
        catalog.Set(
            "📄 查看运行日志",
                "📄 Afficher le journal d'exécution")
        catalog.Set(
            "📄 浏览文件...",
                "📄 Parcourir les fichiers...")
        catalog.Set(
            "🔄 反转状态",
                "🔄 Inverser l'état")
        catalog.Set(
            "🔄 恢复升级保护状态",
                "🔄 État restauré de la protection des mises à jour")
        catalog.Set(
            "🔄 显式升级维护中",
                "🔄 Maintenance de mise à jour explicite en cours")
        catalog.Set(
            "🔄 检查",
                "🔄 Vérifier")
        catalog.Set(
            "🔄 等待程序文件可用",
                "🔄 Attente de la disponibilité du fichier du programme")
        catalog.Set(
            "🔄 等待程序文件恢复",
                "🔄 Attente de la restauration du fichier du programme")
        catalog.Set(
            "🔄 软件升级中",
                "🔄 Mise à jour du logiciel en cours")
        catalog.Set(
            "🔄 软件升级保护设置",
                "🔄 Paramètres de protection des mises à jour logicielles")
        catalog.Set(
            "⏹️ 结束运行",
                "⏹️ Arrêter l'exécution")
        catalog.Set(
            "搜索...",
                "Rechercher...")
        catalog.Set(
            "搜索：",
                "Rechercher：")
        catalog.Set(
            "扩展名",
                "Extension")
        catalog.Set(
            "🗑️ 删除",
                "🗑️ Supprimer")
        catalog.Set(
            "🚀 正在启动...",
                "🚀 Démarrage...")
        catalog.Set(
            "🛡️ 以管理员身份运行",
                "🛡️ Exécuter en tant qu'administrateur")
        catalog.Set(
            "（{1}）",
                "（{1}）")
        catalog.Set(
            "（第 {1} 行）",
                "（ligne {1}）")
        catalog.Set(
            "（管理员权限）",
                "（droits d'administrateur）")
        catalog.Set(
            "：{1}",
                "：{1}")
        catalog.Set(
            "Everything 搜索不可用，请确认 Everything 正在运行。",
                "La recherche Everything est indisponible. Vérifiez qu'Everything est en cours d'exécution.")
        catalog.Set(
            "正在载入 Everything 搜索结果：{1}／{2}",
                "Chargement des résultats de recherche Everything : {1}/{2}")
        catalog.Set(
            "Everything 搜索结果：{1} 项",
                "Résultats de recherche Everything : {1}")
        catalog.Set("{1}（EXE 版）", "{1}（version EXE）")
        catalog.Set("{1}（源码版）", "{1}（version source）")
        catalog.Set("• “结束运行”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• « Arrêter l'exécution » demande d'abord à la cible de se fermer normalement. Si le délai expire, l'option de la « Politique d'arrêt » détermine si elle doit être arrêtée de force.")
        catalog.Set("• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。", "• À propos : consultez la version de l'application et l'environnement d'exécution AutoHotkey, recherchez manuellement une mise à jour ou ouvrez le projet open source.")
        catalog.Set("• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。", "• Lorsqu'une cible semble arrêtée, l'assistant confirme son état, puis réessaie selon la « Séquence de délais de redémarrage automatique après un plantage ». En cas d'échecs successifs, les délais suivants évitent des redémarrages trop fréquents.")
        catalog.Set("• 界面语言和内容字体保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• L'enregistrement de la langue de l'interface ou de la police du contenu actualise immédiatement la fenêtre principale, les menus et la zone de notification, sans redémarrage.")
        catalog.Set("• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。", "• Journaux : réglez la limite d'affichage du journal d'exécution, l'emplacement et la durée de conservation des journaux de traitements par lots, ainsi que leur nettoyage au démarrage.")
        catalog.Set("• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。", "• Politique d'arrêt : réglez le délai de fermeture des applications GUI et CLI et choisissez d'autoriser ou non l'arrêt forcé lorsque la fermeture normale dépasse ce délai.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时是否显示主窗口，以及界面语言和内容字体。", "• Général : créez des raccourcis sur le Bureau et dans le menu Démarrer, activez ou désactivez le démarrage par tâche planifiée, choisissez d'afficher ou non la fenêtre principale au démarrage et réglez la langue ainsi que la police du contenu de l'interface.")
        catalog.Set("• 小助手版本与 AutoHotkey 版本彼此独立；“关于”页会分别显示当前小助手版本、运行形态和实际运行时版本。", "• Les versions de l'assistant et d'AutoHotkey sont indépendantes. La page « À propos » affiche séparément la version actuelle de l'assistant, son mode de distribution et la version réelle de l'environnement d'exécution.")
        catalog.Set("CLI 程序关闭超时（秒）：", "Délai de fermeture des applications CLI（secondes）:")
        catalog.Set("GUI 程序关闭超时（秒）：", "Délai de fermeture des applications GUI（secondes）:")
        catalog.Set("崩溃自动重启延迟序列（秒）：", "Délais de redémarrage automatique après un plantage（secondes）:")
        catalog.Set("崩溃自动重启延迟序列不能为空！", "La séquence de délais de redémarrage automatique après un plantage ne peut pas être vide.")
        catalog.Set("崩溃自动重启延迟序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。", "La séquence de délais de redémarrage automatique après un plantage est incorrecte. Saisissez des entiers positifs séparés par des virgules（par exemple : 1,10,60）, chacun compris entre 1 et 86400 secondes.")
        catalog.Set("当前版本：", "Version actuelle :")
        catalog.Set("导入文件夹时包含子目录", "Inclure les sous-dossiers lors de l'importation d'un dossier")
        catalog.Set("开源地址", "Projet open source")
        catalog.Set("关于", "À propos")
        catalog.Set("界面内容字体：", "Police du contenu de l'interface :")
        catalog.Set("进程状态检查间隔（毫秒）：", "Intervalle de vérification des processus（millisecondes）:")
        catalog.Set("进程状态检查间隔必须为 500-86400000 毫秒的正整数！", "L'intervalle de vérification des processus doit être un entier positif compris entre 500 et 86400000 millisecondes.")
        catalog.Set("扩展设置包含无效数值。`n`nGUI 程序关闭超时：1-300 秒`nCLI 程序关闭超时：1-60 秒`n运行日志显示上限：50-10000 条`n批处理日志保留天数：1-3650 天", "Certains réglages avancés contiennent des valeurs incorrectes.`n`nDélai de fermeture des applications GUI : 1 à 300 secondes`nDélai de fermeture des applications CLI : 1 à 60 secondes`nLimite d'affichage du journal d'exécution : 50 à 10000 entrées`nConservation des journaux de traitements par lots : 1 à 3650 jours")
        catalog.Set("配置显示、启动、监控、停止策略与日志", "Configurez Affichage, Démarrage, Surveillance, Politique d'arrêt et Journaux")
        catalog.Set("批处理日志保存路径：", "Emplacement des journaux de traitements par lots :")
        catalog.Set("批处理日志保留天数：", "Conservation des journaux de traitements par lots（jours）:")
        catalog.Set("启动时显示主窗口", "Afficher la fenêtre principale au démarrage")
        catalog.Set("设置已更新：进程检查间隔={1}ms，重启延迟序列=[{2}]，日志显示上限={3}", "Réglages mis à jour : intervalle des processus={1} ms, séquence de délais de redémarrage=[{2}], limite d'affichage du journal={3}")
        catalog.Set("停止策略", "Politique d'arrêt")
        catalog.Set("运行环境：", "Environnement d'exécution :")
        catalog.Set("运行日志显示上限（条）：", "Limite d'affichage du journal d'exécution（entrées）:")
        catalog.Set("; Theme：界面主题；auto 表示跟随 Windows 系统，light 表示浅色，dark 表示深色。", "; Theme : thème de l’interface`; auto suit les paramètres Windows, light utilise le thème clair et dark le thème sombre.")
        catalog.Set("主题：", "Thème :")
        catalog.Set("浅色", "Clair")
        catalog.Set("深色", "Sombre")
        catalog.Set("运行参数不是支持的界面主题：{1}", "Le paramètre d’exécution ne correspond pas à un thème d’interface pris en charge : {1}")
        catalog.Set("界面显示设置无法即时应用，已恢复原语言、字体和主题：{1}", "Les paramètres d’affichage n’ont pas pu être appliqués immédiatement `; la langue, la police et le thème précédents ont été restaurés : {1}")
        catalog.Set("无法即时切换界面语言、字体或主题，原显示设置已恢复。`n`n{1}", "Impossible de changer immédiatement la langue, la police ou le thème de l’interface. Les paramètres d’affichage précédents ont été restaurés.`n`n{1}")
        catalog.Set("界面语言、字体和主题已即时更新，无需重新启动小助手。", "La langue, la police et le thème de l’interface ont été mis à jour immédiatement `; le redémarrage de l’assistant est inutile.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。", "• Général : créez des raccourcis sur le bureau et dans le menu Démarrer, activez ou désactivez le démarrage planifié, choisissez l’affichage de la fenêtre principale et la recherche de mises à jour au démarrage, puis définissez la langue, la police du contenu et le thème.")
        catalog.Set("• 显示：界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Affichage : après l’enregistrement de la langue, de la police du contenu ou du thème, la fenêtre principale, les menus et la zone de notification sont mis à jour sans redémarrage.")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Ouvrir l’aide`nChoisissez le guide d’utilisation, le journal d’exécution ou l’envoi d’un commentaire")
        catalog.Set("快揭不开锅了（≥Д≤）", "La caisse est presque vide（≥Д≤）")
        catalog.Set("帮助", "Aide")
        catalog.Set("提交反馈", "Envoyer un commentaire")
        catalog.Set("支持开源项目", "Soutenir le projet open source")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式：", "Si l’assistant vous a fait gagner du temps dans le diagnostic des problèmes et la remise en service de vos programmes, n’hésitez pas à soutenir l’auteur à l’aide des codes QR ci-dessous !`nChoisissez votre façon de contribuer :")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Image du code QR introuvable")
        catalog.Set("• 主界面的“帮助”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。", "• Ouvrez Aide dans la fenêtre principale pour consulter le guide d’utilisation, le journal de cette session ou la page de commentaires du projet. Le journal contient la surveillance, les redémarrages, la protection des mises à jour et les actions de l’utilisateur, et se met à jour automatiquement.")
        catalog.Set("⚙️ 进程识别与启动设置", "⚙️ Identification du processus et paramètres de lancement")
        catalog.Set("进程识别与启动设置", "Identification du processus et paramètres de lancement")
        catalog.Set("进程识别", "Identification du processus")
        catalog.Set("启动环境", "Environnement de lancement")
        catalog.Set("快捷方式仍用于启动；真实进程用于判断程序是否正在运行。", "Le raccourci reste le point de lancement `; le processus réel sert à déterminer si l'application est en cours d'exécution.")
        catalog.Set("该守护对象直接启动并监控同一个目标，无需额外识别真实进程。", "Cet élément lance et surveille directement la même cible `; aucune identification séparée du processus réel n'est nécessaire.")
        catalog.Set("用于判断运行状态的真实进程：", "Processus réel utilisé pour vérifier l'état :")
        catalog.Set("用于判断运行状态的目标：", "Cible utilisée pour vérifier l'état :")
        catalog.Set("重新识别", "Identifier de nouveau")
        catalog.Set("选择程序", "Choisir un programme")
        catalog.Set("识别依据：{1}", "Source de l'identification : {1}")
        catalog.Set("识别依据：暂无可靠结果", "Source de l'identification : aucun résultat fiable")
        catalog.Set("识别状态：路径有效。", "État de l'identification : le chemin est valide.")
        catalog.Set("识别状态：路径暂时不可用，已保留上次可靠结果。", "État de l'identification : le chemin est temporairement indisponible `; le dernier résultat fiable a été conservé.")
        catalog.Set("识别状态：路径暂时不可用，将保留此身份等待恢复。", "État de l'identification : le chemin est temporairement indisponible `; cette identité sera conservée en attendant son rétablissement.")
        catalog.Set("识别状态：未找到可靠目标，请改为手动指定。", "État de l'identification : aucune cible fiable n'a été trouvée. Indiquez-la manuellement.")
        catalog.Set("识别状态：手动指定，保存时将验证路径。", "État de l'identification : indiqué manuellement `; le chemin sera vérifié lors de l'enregistrement.")
        catalog.Set("识别状态：启动入口与监控目标一致。", "État de l'identification : le point de lancement et la cible surveillée sont identiques.")
        catalog.Set("这些设置仅在小助手下次启动目标时生效，不会重启当前进程。", "Ces paramètres s'appliqueront au prochain lancement de la cible par l'assistant et ne redémarreront pas le processus actuellement en cours d'exécution.")
        catalog.Set("留空时使用快捷方式工作目录或程序所在目录。", "Laissez ce champ vide pour utiliser le dossier de travail du raccourci ou le dossier du programme.")
        catalog.Set("留空时不附加额外参数。", "Laissez ce champ vide pour ne transmettre aucun argument supplémentaire.")
        catalog.Set("留空时继承小助手当前环境。", "Laissez ce champ vide pour hériter de l'environnement actuel de l'assistant.")
        catalog.Set("工作目录不存在或不可访问：{1}", "Le dossier de travail n'existe pas ou n'est pas accessible : {1}")
        catalog.Set("工作目录无效", "Dossier de travail non valide")
        catalog.Set("环境变量第 {1} 行缺少等号（KEY=VALUE）。", "Il manque un signe égal à la ligne {1} des variables d'environnement（KEY=VALUE）.")
        catalog.Set("环境变量第 {1} 行的名称无效：{2}", "La ligne {1} des variables d'environnement contient un nom non valide : {2}")
        catalog.Set("环境变量第 {1} 行重复定义了 {2}。", "La ligne {1} des variables d'environnement redéfinit {2}.")
        catalog.Set("环境变量配置无法解析。", "Impossible d'analyser la configuration des variables d'environnement.")
        catalog.Set("环境变量配置无效", "Variables d'environnement non valides")
        catalog.Set("设置已应用到当前运行，但暂未写入配置文件；小助手将在后台自动重试。", "Les paramètres sont actifs pour cette session, mais n'ont pas encore été écrits dans le fichier de configuration. L'assistant réessaiera automatiquement en arrière-plan.")
        catalog.Set("配置暂未写入", "Configuration pas encore écrite")
        catalog.Set("已更新进程识别与启动设置：{1}", "Identification du processus et paramètres de lancement mis à jour : {1}")
        catalog.Set("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。", "• Raccourcis : LNK, URL et APPREF-MS, y compris les raccourcis MSI dont la cible réelle peut être résolue. Pour un raccourci particulier, indiquez manuellement le processus réel dans Identification du processus et paramètres de lancement.")
        catalog.Set("• 右键守护对象可自定义主窗口名称和图标，也可打开所在位置、结束运行、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。“结束运行”会同时暂停守护，目标不会被自动重新启动；要求管理员运行但当前权限不符时仍会显示警告。", "• Cliquez avec le bouton droit sur un élément pour personnaliser son nom et son icône, ouvrir son emplacement, arrêter la cible, modifier son chemin, régler le lancement administrateur, l'identification du processus, le lancement et la protection des mises à jour, ou consulter le journal de sortie. Arrêter la cible suspend aussi la surveillance, donc elle ne redémarre pas automatiquement `; les droits insuffisants restent signalés.")
        catalog.Set("添加", "Ajouter")
        catalog.Set("暂停", "Suspendre")
        catalog.Set("恢复", "Reprendre")
        catalog.Set("删除", "Supprimer")
        catalog.Set("设置", "Configuration")
        catalog.Set("打赏", "Donner")
        catalog.Set("保存", "Enregistrer")
        catalog.Set("取消", "Annuler")
        catalog.Set("反转状态", "Inverser l'état")
        catalog.Set("统计：运行", "En cours")
        catalog.Set("统计：停止", "Arrêtés")
        catalog.Set("统计：恢复", "Reprise en cours")
        catalog.Set("统计：升级", "Mise à jour")
        catalog.Set("统计：暂停", "En pause")
        catalog.Set("统计：失效", "Non valides")
        catalog.Set("统计：总计", "Total")
        catalog.Set("配置未保存", "Configuration non enregistrée")
        catalog.Set("创建", "Créer")
        catalog.Set("开启", "Activer")
        catalog.Set("关闭", "Désactiver")
        catalog.Set("切换", "Basculer")
        catalog.Set("冲突", "Conflit")
        catalog.Set("浏览", "Parcourir")
        catalog.Set("监控配置", "Configuration de la surveillance")
        catalog.Set("管理员运行状态", "Exécution en tant qu’administrateur")
        catalog.Set("调整守护顺序", "Réorganiser la liste de surveillance")
        catalog.Set("编辑完整路径", "Modifier le chemin complet")
        catalog.Set("自定义名称和图标", "Personnaliser le nom et l’icône")
        catalog.Set("已撤销：{1}", "Annulé : {1}")
        catalog.Set("已重做：{1}", "Rétabli : {1}")
        catalog.Set("Everything 搜索暂时不可用，请稍后重试。", "La recherche Everything est temporairement indisponible. Réessayez dans un instant.")
        catalog.Set("Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。", "Le composant de recherche Everything est absent ou n'a pas pu être chargé. Décompressez entièrement l'assistant ou réinstallez-le.")
        catalog.Set("已找到 Everything，但无法后台启动，请手动启动后重试。", "Everything a été trouvé, mais n'a pas pu être lancé en arrière-plan. Lancez-le manuellement, puis réessayez.")
        catalog.Set("后台启动 Everything 失败：{1}", "Impossible de lancer Everything en arrière-plan : {1}")
        catalog.Set("正在后台启动 Everything 并等待搜索服务就绪...", "Lancement d'Everything en arrière-plan et attente du service de recherche...")
        catalog.Set("已在后台启动 Everything：{1}", "Everything a été lancé en arrière-plan : {1}")
        catalog.Set("等待 Everything 搜索服务就绪超时：{1}", "Délai dépassé en attendant que le service de recherche Everything soit prêt : {1}")
        catalog.Set("未找到 Everything，点击前往官网下载最新版：{1}", "Everything est introuvable. Cliquez pour télécharger la dernière version depuis le site officiel : {1}")
        catalog.Set("本机未找到 Everything；程序搜索需要 Everything 后台服务。", "Everything est introuvable sur cet ordinateur `; la recherche de programmes nécessite son service en arrière-plan.")
        catalog.Set("• 程序搜索：使用 Everything 服务并显示全部匹配结果；未运行时会尝试在本机查找并后台启动，未找到时提供官网最新版下载地址。", "• Recherche de programmes : utilise le service Everything et affiche tous les résultats correspondants. Si Everything ne fonctionne pas, l'assistant le recherche sur l'ordinateur et le lance en arrière-plan `; s'il est introuvable, un lien officiel vers la dernière version est proposé.")
        catalog.Set("• 小助手随包的 Everything64.dll 只是连接 Everything 后台实例的 SDK 客户端，不负责扫描磁盘或建立索引，不能替代 Everything 本体。", "• Le fichier Everything64.dll fourni avec l'assistant est uniquement un client SDK qui se connecte à l'instance Everything en arrière-plan. Il n'analyse pas les disques, ne crée pas l'index et ne remplace pas l'application Everything.")
        catalog.Set("六、进程识别与启动设置", "6. Identification du processus et paramètres de lancement")
        catalog.Set("• 此设置只作用于当前守护对象，并将“用什么启动”和“用什么判断正在运行”分开处理。启动环境只在小助手下次启动目标时生效，不会重启当前进程。", "• Ces paramètres ne concernent que l'élément surveillé actuel et séparent la méthode de lancement des éléments servant à déterminer s'il fonctionne. L'environnement de lancement s'applique uniquement au prochain démarrage de la cible par l'assistant et ne redémarre pas le processus actuel.")
        catalog.Set("• 直接添加程序或脚本时，启动入口与监控目标相同；EXE 按完整路径识别，脚本按宿主进程命令行中的脚本路径识别。", "• Lorsqu'un programme ou un script est ajouté directement, l'entrée de lancement et la cible surveillée sont identiques. Un EXE est identifié par son chemin complet `; un script, par son chemin dans la ligne de commande du processus hôte.")
        catalog.Set("• 添加 LNK 快捷方式时，快捷方式始终作为启动入口；自动识别出的真实程序或脚本只用于判断运行状态。", "• Lorsqu'un raccourci LNK est ajouté, il reste toujours l'entrée de lancement. Le programme ou script réel détecté automatiquement sert uniquement à déterminer l'état d'exécution.")
        catalog.Set("• 自动识别会综合快捷方式目标、参数、Windows Installer 信息、安装目录、文件版本信息和已观察进程；证据不唯一时不会随意绑定。", "• L'identification automatique combine la cible et les arguments du raccourci, les données de Windows Installer, le dossier d'installation, les informations de version du fichier et les processus observés. Elle n'associe pas de cible lorsque les indices sont ambigus.")
        catalog.Set("• 自动结果不正确时改用“用户指定”，选择程序正常运行期间持续存在的主程序或脚本；不要选择启动器、更新器或短暂子进程。", "• Si le résultat automatique est incorrect, choisissez Défini par l'utilisateur, puis sélectionnez le programme principal ou le script qui reste présent pendant le fonctionnement normal de l'application. Ne sélectionnez pas un lanceur, un programme de mise à jour ou un processus enfant éphémère.")
        catalog.Set("启动程序或解释器：", "Lanceur ou interpréteur :")
        catalog.Set("留空时按目标类型自动启动；可选择 Python、AutoHotkey、PowerShell、Node.js、Java 等运行时。", "Laissez vide pour lancer selon le type de cible, ou sélectionnez un environnement d'exécution tel que Python, AutoHotkey, PowerShell, Node.js ou Java.")
        catalog.Set("启动程序参数：", "Arguments du lanceur :")
        catalog.Set("参数顺序为：启动程序参数、目标路径、目标参数；例如 Java 使用 -jar。", "L'ordre est le suivant : arguments du lanceur, chemin de la cible, puis arguments de la cible. Par exemple, utilisez -jar avec Java.")
        catalog.Set("目标参数（Args）：", "Arguments de la cible（Args）:")
        catalog.Set("留空时继承小助手当前环境；值中可用 %变量名% 引用已有环境变量。", "Laissez vide pour hériter de l'environnement actuel de l'assistant. Utilisez %VARIABLE% dans une valeur pour faire référence à une variable d'environnement existante.")
        catalog.Set("选择启动程序或解释器", "Choisir un lanceur ou un interpréteur")
        catalog.Set("可执行程序", "Programmes exécutables")
        catalog.Set("请先选择启动程序或解释器，再填写它的参数。", "Choisissez un lanceur ou un interpréteur avant de saisir ses arguments.")
        catalog.Set("启动程序未设置", "Lanceur non défini")
        catalog.Set("启动程序或解释器不存在：{1}", "Le lanceur ou l'interpréteur n'existe pas : {1}")
        catalog.Set("启动程序无效", "Lanceur non valide")
        catalog.Set("整条启动配置", "configuration de lancement complète")
        catalog.Set("启动程序或解释器", "lanceur ou interpréteur")
        catalog.Set("解释器参数", "arguments de l'interpréteur")
        catalog.Set("• 直接脚本可指定“启动程序或解释器”，选择实际执行脚本的可执行文件，例如 Python、AutoHotkey、PowerShell、Node.js、Ruby、Perl、PHP、Lua、Java 或 Bash；留空时沿用系统默认启动方式。", "• Pour un script ajouté directement, Lanceur ou interpréteur permet de choisir l'exécutable qui lance réellement le script, par exemple Python, AutoHotkey, PowerShell, Node.js, Ruby, Perl, PHP, Lua, Java ou Bash. Laissez ce champ vide pour utiliser la méthode de lancement par défaut du système.")
        catalog.Set("• “启动程序参数”位于目标路径之前，“目标参数（Args）”位于目标路径之后。Java 可填写 -jar；PowerShell 可填写 -NoProfile -ExecutionPolicy Bypass -File。", "• Les Arguments du lanceur sont placés avant le chemin de la cible `; les Arguments de la cible（Args）sont placés après. Pour Java, vous pouvez utiliser -jar `; pour PowerShell, -NoProfile -ExecutionPolicy Bypass -File.")
        catalog.Set("• Python 虚拟环境请选择该环境的 Scripts\python.exe；其他语言也可选择项目要求的确切运行时版本。进程识别仍以目标脚本路径为准，不会误把解释器本身当成守护目标。", "• Pour un environnement virtuel Python, sélectionnez son fichier Scripts\python.exe. Pour les autres langages, vous pouvez également sélectionner la version précise de l'environnement d'exécution requise par le projet. L'identification du processus repose toujours sur le chemin du script cible `; l'interpréteur lui-même ne sera donc pas confondu avec la cible surveillée.")
        catalog.Set("• 工作目录（CWD）用于解析相对路径；留空时使用快捷方式工作目录或目标所在目录。", "• Le répertoire de travail（CWD）sert à résoudre les chemins relatifs. S'il est vide, le répertoire de travail du raccourci ou le répertoire de la cible est utilisé.")
        catalog.Set("• 环境变量每行填写一个 KEY=VALUE，只覆盖列出的变量；值中可用 %变量名% 引用已有环境变量。启动完成后小助手会恢复自身环境。", "• Saisissez une variable d'environnement KEY=VALUE par ligne. Seules les variables indiquées sont remplacées et %VARIABLE% peut faire référence à une valeur existante. L'assistant rétablit son propre environnement après le lancement.")
        catalog.Set("; AppN 与 [Apps] 中同名的守护对象一一对应，依次保存启动程序或解释器路径及其参数。", "; Chaque AppN correspond à la cible surveillée du même nom dans [Apps] et enregistre, dans cet ordre, le chemin du lanceur ou de l'interpréteur et ses arguments.")
        catalog.Set("; 两个字段均为 <HEX> 编码；留空时由小助手按目标类型使用默认启动方式。", "; Les deux champs utilisent l'encodage <HEX>. Lorsqu'ils sont vides, l'assistant emploie la méthode de lancement par défaut correspondant au type de cible.")
        catalog.Set("守护对象不能指向文件夹：{1}", "Un élément surveillé ne peut pas désigner un dossier : {1}")
        catalog.Set("自动识别目标新位置", "Identifier automatiquement le nouvel emplacement de la cible")
        catalog.Set("检测到的目标新位置已失效，请重新操作。", "Le nouvel emplacement détecté n'est plus valide. Veuillez réessayer.")
        catalog.Set("已更新已更名的守护目标：{1} -> {2}", "La cible surveillée renommée a été mise à jour : {1} -> {2}")
        catalog.Set("守护目标内容迁移识别服务未能启动。", "Le service de détection du déplacement de contenu des cibles surveillées n'a pas pu démarrer.")
        catalog.Set("检测到守护目标可能已更名，等待用户确认：{1} -> {2}", "Une cible surveillée a peut-être été renommée `; confirmation en attente : {1} -> {2}")
        catalog.Set("确认窗口暂时无法显示，将稍后重试", "La fenêtre de confirmation est temporairement indisponible. Un nouvel essai sera effectué prochainement.")
        catalog.Set("发现多个内容完全相同的迁移候选，已暂停自动迁移：{1}", "Plusieurs candidats au contenu strictement identique ont été trouvés`; le déplacement automatique est suspendu : {1}")
        catalog.Set("检测到内容一致的守护目标新位置，等待用户确认：{1} -> {2}", "Un nouvel emplacement au contenu identique a été détecté`; confirmation en attente : {1} -> {2}")
        catalog.Set("守护目标内容迁移识别异常：{1}", "Erreur de détection du déplacement de contenu de la cible : {1}")
        catalog.Set("等待确认目标新位置", "En attente de confirmation du nouvel emplacement")
        catalog.Set("确认目标新位置", "Confirmer le nouvel emplacement de la cible")
        catalog.Set("检测到守护目标可能已更名", "Une cible surveillée a peut-être été renommée")
        catalog.Set("小助手找到了与原文件内容完全一致的新路径。确认后将更新守护目标，名称、图标和启动设置保持不变。", "L'assistant a trouvé un nouveau chemin dont le contenu est strictement identique. Après confirmation, la cible surveillée sera mise à jour sans modifier son nom, son icône ni ses paramètres de lancement.")
        catalog.Set("原路径：", "Ancien chemin :")
        catalog.Set("新路径：", "Nouveau chemin :")
        catalog.Set("识别依据：", "Élément d'identification : ")
        catalog.Set("更新守护路径", "Mettre à jour le chemin surveillé")
        catalog.Set("忽略", "Ignorer")
        catalog.Set("更新已更名的守护目标", "Mettre à jour la cible surveillée renommée")
        catalog.Set("• 直接添加的程序或脚本本身或上级目录被更名、跨目录或跨磁盘移动后，小助手会按文件大小筛选并以 SHA-256 内容哈希确认新路径；即使移动发生在小助手关闭期间也能识别。", "• Après le renommage ou le déplacement d’un programme, d’un script ou de son dossier parent entre dossiers ou disques, l’assistant filtre par taille et confirme le nouveau chemin avec l’empreinte SHA-256, même si le déplacement a eu lieu alors qu’il était fermé.")
        catalog.Set("; AppN 与 [Apps] 中同名的直接文件目标一一对应，依次保存文件大小和 SHA-256 内容哈希。", "; Chaque entrée AppN correspond au fichier directement surveillé du même nom dans [Apps] et enregistre sa taille, puis son empreinte de contenu SHA-256.")
        catalog.Set("; 此节由小助手自动维护，用于在文件或目录改名、跨目录或跨磁盘移动后确认内容未变；请勿手动编辑。", "; L’assistant gère cette section automatiquement afin de vérifier que le contenu reste inchangé après un renommage ou un déplacement entre dossiers ou disques. Ne la modifiez pas manuellement.")
        catalog.Set("Everything64.dll 已加载，但 Everything 后台实例未响应；正在尝试定位并启动 Everything 本体。", "Everything64.dll is loaded, but the Everything background instance is not responding. The assistant is trying to locate and start the Everything application.")
        catalog.Set("Everything 查询失败：{1}", "Everything query failed: {1}")
        catalog.Set("Everything 搜索暂时不可用：后台实例未返回结果，请稍后重试。", "Everything search is temporarily unavailable: the background instance did not return results. Try again shortly.")
        catalog.Set("内存不足", "Not enough memory")
        catalog.Set("后台 IPC 服务不可用", "The background IPC service is unavailable")
        catalog.Set("无法注册 Everything 查询窗口类", "Could not register the Everything query window class")
        catalog.Set("无法创建 Everything 查询窗口", "Could not create the Everything query window")
        catalog.Set("无法创建 Everything 查询线程", "Could not create the Everything query thread")
        catalog.Set("结果索引无效", "The result index is invalid")
        catalog.Set("调用顺序无效", "The call sequence is invalid")
        catalog.Set("未知错误码 {1}", "Unknown error code {1}")
        catalog.Set("已找到 Everything 本体，但无法后台启动；请手动启动 Everything 后重试。", "Everything was found but could not be started in the background. Start Everything manually and try again.")
        catalog.Set("后台启动 Everything 失败：{1}（路径：{2}；发现过程：{3}）", "Failed to start Everything in the background: {1} (path: {2}; discovery: {3})")
        catalog.Set("正在后台启动 Everything 本体并等待搜索服务就绪...", "Starting the Everything application in the background and waiting for the search service...")
        catalog.Set("已启动 Everything，但后台搜索服务仍未响应；请确认 Everything 主程序完成启动且服务可用。", "Everything was started, but the background search service is still not responding. Confirm that Everything finished starting and its service is available.")
        catalog.Set("未找到 Everything 本体，点击前往官网下载最新版：{1}", "Everything was not found. Click to download the latest version from the official site: {1}")
        catalog.Set("本机未找到 Everything 本体；程序搜索需要 Everything 的索引和后台服务，随包 Everything64.dll 只是 IPC 客户端。{1}{2}", "Everything was not found on this computer. Program search requires Everything's index and background service; the bundled Everything64.dll is only an IPC client. {1}{2}")
        catalog.Set("暂时无法核对现有进程，延迟启动以避免重复实例：{1}{2}", "The existing process cannot be verified yet, so startup is delayed to avoid a duplicate instance: {1}{2}")
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
        catalog.Set("后台进程快照不可用", "The background process snapshot is unavailable")
        catalog.Set("候选进程命令行不可用", "The candidate process command line is unavailable")
        catalog.Set("命令行只提供相对目标路径，无法可靠匹配", "The command line provides only a relative target path, so it cannot be matched reliably")
        catalog.Set("候选进程镜像路径不可访问", "The candidate process image path is inaccessible")
        catalog.Set("发现多个版本目录包含同名入口，已暂停自动迁移：{1}", "Multiple version directories contain an entry with the same name; automatic relocation is paused: {1}")
        catalog.Set("版本目录迁移候选暂不可读取，将稍后重试：{1}", "The version-directory relocation candidate is temporarily unreadable and will be retried later: {1}")
        catalog.Set("版本目录迁移候选仍在本次忽略冷却期内：{1} -> {2}", "The version-directory relocation candidate is still in this ignore cooldown: {1} -> {2}")
        catalog.Set("候选进程创建身份无法核对", "The candidate process creation identity cannot be verified")
        catalog.Set("存在多个候选进程，无法唯一确认", "Multiple candidate processes exist, so the target cannot be uniquely confirmed")
        catalog.Set("目标探活规格无效", "The target probe specification is invalid")
        catalog.Set("无法执行内容迁移：缺少旧文件的完整内容指纹：{1}", "Content relocation cannot run because the previous file has no complete content fingerprint: {1}")
        catalog.Set("监测到目标文件缺失，内容迁移将在缺失状态稳定后开始扫描：{1}", "The target file is missing; content relocation will start scanning after the missing state is stable: {1}")
        catalog.Set("内容迁移暂缓：目标正处于升级保护、维护恢复或近期启动信号保护中：{1}", "Content relocation is paused because the target is under update protection, maintenance recovery, or recent launch-signal protection: {1}")
        catalog.Set("内容迁移候选已被拒绝：{1} -> {2}（候选不存在、扩展名不兼容、已被守护或与现有目标冲突）", "The content relocation candidate was rejected: {1} -> {2} (candidate missing, incompatible extension, already monitored, or conflicting with an existing target)")
        catalog.Set("内容迁移候选仍在本次忽略冷却期内：{1} -> {2}", "The content relocation candidate is still in this ignore cooldown: {1} -> {2}")
        catalog.Set("后台扫描失败或超时", "The background scan failed or timed out")
        catalog.Set("扫描未能在时限内完整核对", "The scan could not complete verification within the time limit")
        catalog.Set("内容迁移扫描未完成，将稍后重试：{1}（搜索根：{2}；原因：{3}）", "Content relocation scan did not complete and will retry later: {1} (search root: {2}; reason: {3})")
        catalog.Set("发现多个内容完全相同的迁移候选，已暂停自动迁移：{1}（候选：{2}）", "Multiple relocation candidates with identical content were found; automatic relocation is paused: {1} (candidates: {2})")
        catalog.Set("正在扫描内容迁移候选：{1}（搜索根：{2}；方式：{3}）", "Scanning for content relocation candidates: {1} (search root: {2}; method: {3})")
        catalog.Set("Everything 索引预筛选", "Everything index prefilter")
        catalog.Set("直接递归扫描", "direct recursive scan")
        catalog.Set("无法启动内容迁移扫描，已尝试下一个搜索根：{1}（搜索根：{2}；方式：{3}）", "Could not start the content relocation scan; trying the next search root: {1} (search root: {2}; method: {3})")
        catalog.Set("尚未找到内容完全一致的迁移候选，将稍后重试：{1}（已按扩展名、大小和 SHA-256 完整内容指纹核对）", "No relocation candidate with identical content has been found yet; will retry later: {1} (checked by extension, size, and full SHA-256 content fingerprint)")
        catalog.Set("未知", "Unknown")
        catalog.Set("无", "None")
        catalog.Set("，另有 {1} 个", ", plus {1} more")
        catalog.Set("🔄 重新启动", "🔄 Redémarrer")
        catalog.Set("点个 star 吧~", "Offrez-nous une petite étoile~")
        catalog.Set("⏳ 停止原进程...", "⏳ Arrêt du processus d'origine...")
        catalog.Set("❌ 无法停止原进程", "❌ Impossible d'arrêter le processus d'origine")
        catalog.Set("手动触发了重新启动：{1}", "Redémarrage déclenché manuellement : {1}")
        catalog.Set("手动重启已取消，原进程未能停止：{1}", "Le redémarrage manuel a été annulé, car le processus d'origine n'a pas pu être arrêté : {1}")
        catalog.Set("暂时无法查询进程状态，稍后重试手动重启：{1}", "Impossible de consulter temporairement l'état du processus `; le redémarrage manuel sera retenté plus tard : {1}")
        catalog.Set("暂时无法重新启动", "Redémarrage temporairement impossible")
        catalog.Set("该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。", "Ce logiciel est sous protection de mise à jour. Attendez la fin de la mise à jour ou terminez l'attente dans « Protection des mises à jour logicielles » avant de le redémarrer.")
        catalog.Set("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• « Redémarrer » demande d'abord à la cible de se fermer normalement. Si le délai expire, l'option de la « Politique d'arrêt » détermine si elle doit être arrêtée de force.")
        catalog.Set("查看版本、运行环境和项目入口", "Voir la version, environnement et liens du projet")
        catalog.Set("找作者对线", "Contacter auteur")
        catalog.Set("升级期间检测到唯一同名新版本入口，等待用户确认：{1} -> {2}", "A unique same-named entry in a new version directory was detected during the upgrade. Awaiting confirmation: {1} -> {2}")
        catalog.Set("升级期间发现唯一同名新版本入口；已记录并持续校验候选 SHA-256。确认后将更新守护目标，名称、图标和启动设置保持不变。", "The only same-named entry in a new version directory was found during the upgrade. Its SHA-256 is recorded and rechecked. Confirming updates the monitored target without changing its name, icon, or launch settings.")
        catalog.Set("内容完全一致 / SHA-256", "Exact content match / SHA-256")
        catalog.Set("唯一同名新版本入口 / SHA-256", "Unique same-named version entry / SHA-256")
        catalog.Set("• 常规迁移不使用文件名、文件 ID 或目录监听作为判断依据。版本目录升级是受限例外：升级期间仅在同一父目录中存在唯一同名新版本入口时提出迁移，并记录、持续校验候选 SHA-256。发现多个候选、多个内容相同的副本或扫描未完整完成时不会猜测目标；确认后只更新守护路径，名称、图标和启动设置保持不变。", "• Regular relocation decisions do not use file names, file IDs, or directory watchers. Version-directory upgrades are a restricted exception: during an upgrade, relocation is proposed only when exactly one same-named entry exists in a new version directory under the same parent, and that candidate's SHA-256 is recorded and continuously verified. The assistant does not guess when multiple candidates or identical copies exist, or when a scan is incomplete. Confirming changes only the monitored path and preserves the name, icon, and launch settings.")
        return catalog
    }
}

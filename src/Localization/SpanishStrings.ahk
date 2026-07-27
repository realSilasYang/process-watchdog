; es-ES 本地化词条目录。
; 本目录由模型直接依据简体中文稳定键逐条翻译；生成步骤仅处理转义与格式。

class SpanishStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set(
            "`n位置：{1}",
                "`nUbicación: {1}")
        catalog.Set(
            "`r`n      影响：该项目本次未加入守护列表。",
                "`r`n      Consecuencia: este elemento no se ha añadido a la lista de supervisión.")
        catalog.Set(
            "`r`n      目标：{1}",
                "`r`n      Destino: {1}")
        catalog.Set(
            "`r`n      问题：{1}：{2}",
                "`r`n      Problema: {1}: {2}")
        catalog.Set(
            "`r`n  [{1}] 位置：[{2}] {3}",
                "`r`n  [{1}] Ubicación: [{2}] {3}")
        catalog.Set(
            "`r`n  处理建议：确认目标路径后，可在主界面重新添加该项目；也可退出小助手后检查上述配置位置。后续保存配置时，损坏记录会转存到 [Recovery]，不会被静默删除。",
                "`r`n  Acción recomendada: compruebe la ruta de destino y vuelva a añadir el elemento desde la ventana principal`; también puede cerrar el asistente y revisar la ubicación de configuración indicada. Al volver a guardar la configuración, los registros dañados se trasladarán a [Recovery] y no se eliminarán sin aviso.")
        catalog.Set(
            "`r`n  配置文件：{1}",
                "`r`n  Archivo de configuración: {1}")
        catalog.Set(
            "   ⚠️ 配置未保存",
                "   ⚠️ Configuración sin guardar")
        catalog.Set(
            "  --maintenance-begin `"目标完整路径`"    开始维护",
                "  --maintenance-begin `"ruta completa del destino`"    Iniciar mantenimiento")
        catalog.Set(
            "  --maintenance-end `"目标完整路径`"      结束维护",
                "  --maintenance-end `"ruta completa del destino`"      Finalizar mantenimiento")
        catalog.Set(
            " 已保留并保存此前添加的 {1} 个监控项。",
                " Se han conservado y guardado los {1} elementos de supervisión añadidos anteriormente.")
        catalog.Set(
            " 扫描达到时间或数量上限，结果已截断。",
                " El análisis alcanzó el límite de tiempo o de resultados`; se han truncado los resultados.")
        catalog.Set(
            "`; AllowForceTerminate：正常退出超时后是否允许强制结束进程。",
                "`; AllowForceTerminate: indica si se permite forzar la finalización del proceso cuando se agota el tiempo de salida normal.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名项目一一对应，值为软件升级保护的 <HEX> 编码结构。",
                "`; Cada AppN corresponde al elemento del mismo nombre en [Apps]`; su valor contiene la estructura de protección de actualizaciones codificada como <HEX>.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名项目一一对应；留空的项目使用目标自身的名称和图标。",
                "`; Cada AppN corresponde al elemento del mismo nombre en [Apps]`; los elementos vacíos usan el nombre y el icono del propio destino.")
        catalog.Set(
            "`; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。",
                "`; CheckInterval: intervalo de comprobación del estado en milisegundos`; rango de 500 a 86400000.")
        catalog.Set(
            "`; CheckUpdatesOnStartup：启动后是否在后台检查小助手新版。",
                "`; CheckUpdatesOnStartup: indica si se buscan nuevas versiones del asistente en segundo plano después de iniciarlo.")
        catalog.Set(
            "`; ClearLogsOnStartup：启动时是否清空历史日志。",
                "`; ClearLogsOnStartup: indica si se borran los registros anteriores al iniciar.")
        catalog.Set(
            "`; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col1W: ancho de la primera columna de la lista principal, guardado en píxeles lógicos a 96 DPI.")
        catalog.Set(
            "`; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col2W: ancho de la segunda columna de la lista principal, guardado en píxeles lógicos a 96 DPI.")
        catalog.Set(
            "`; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。",
                "`; CtrlCWaitSeconds: tiempo máximo de espera, en segundos, después de que un programa de línea de comandos reciba Ctrl+C`; rango de 1 a 60.")
        catalog.Set(
            "`; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。",
                "`; GracefulStopSeconds: tiempo máximo, en segundos, para que un programa con ventana se cierre normalmente`; rango de 1 a 300.")
        catalog.Set(
            "`; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。",
                "`; GuiH: altura de la ventana principal, guardada en píxeles lógicos a 96 DPI.")
        catalog.Set(
            "`; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。",
                "`; GuiW: anchura de la ventana principal, guardada en píxeles lógicos a 96 DPI.")
        catalog.Set(
            "`; LogDirectory：留空时使用系统临时目录下的 ProcessWatchdogLogs。",
                "`; LogDirectory: si se deja vacío, se usa ProcessWatchdogLogs dentro del directorio temporal del sistema.")
        catalog.Set(
            "`; LogMaxEntries：日志界面保留条数，范围 50～10000。",
                "`; LogMaxEntries: número de entradas que conserva la ventana de registro`; rango de 50 a 10000.")
        catalog.Set(
            "`; LogRetentionDays：日志文件保留天数，范围 1～3650。",
                "`; LogRetentionDays: días durante los que se conservan los archivos de registro`; rango de 1 a 3650.")
        catalog.Set(
            "`; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。",
                "`; RecursiveBatchImport: indica si se recorren las subcarpetas al importar una carpeta por lotes.")
        catalog.Set(
            "`; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。",
                "`; RetrySequence: tiempos de espera para reiniciar, en segundos y separados por comas`; hasta 10 valores, cada uno entre 1 y 86400.")
        catalog.Set(
            "`; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。",
                "`; ShowAfterReload: marcador interno de recarga`; vuelve automáticamente a 0 al terminar la recarga.")
        catalog.Set(
            "`; ShowAtStartup：启动后是否显示主窗口。",
                "`; ShowAtStartup: indica si se muestra la ventana principal después de iniciar.")
        catalog.Set(
            "`; UiLanguage：界面语言；auto 表示跟随系统，也可填写受支持的语言代码。",
                "`; UiLanguage: idioma de la interfaz`; auto sigue el idioma del sistema, aunque también puede indicarse un código de idioma compatible.")
        catalog.Set(
            "`; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。",
                "`; Solo guarda el nombre mostrado y el origen del icono de la ventana principal`; no interviene en la identificación del proceso, el inicio ni la protección de actualizaciones.")
        catalog.Set(
            "`; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
                "`; Los campos internos incluyen Enabled, RootIsCustom, DetectionSeconds, StableSeconds, MaxWaitSeconds, InstallRoot y Actor.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。",
                "`; Los valores booleanos usan 1 para activar y 0 para desactivar`; se recomienda cambiarlos desde la ventana de configuración.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。",
                "`; Los valores booleanos usan 1 para activar y 0 para desactivar`; el programa codifica y descodifica automáticamente el contenido <HEX>.")
        catalog.Set(
            "`; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。",
                "`; Se recomienda realizar los cambios desde “Protección de actualizaciones de software” y no editar directamente el contenido codificado.")
        catalog.Set(
            "`; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。",
                "`; Los registros de supervisión que no se puedan interpretar de forma segura se guardan temporalmente aquí para evitar pérdidas silenciosas`; normalmente no hace falta modificarlos a mano.")
        catalog.Set(
            "`; 本区保存运行参数；以分号开头的注释不会参与软件读取。",
                "`; Esta sección guarda los parámetros de ejecución`; los comentarios que empiezan por punto y coma no se leen como configuración.")
        catalog.Set(
            "`; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
                "`; Formato: estado habilitado｜ejecutar como administrador｜ruta de destino｜directorio de trabajo｜argumentos de inicio｜variables de entorno｜destino real del acceso directo｜marca de destino manual｜argumentos del acceso directo.")
        catalog.Set(
            "`; 每个 AppN 对应一个监控项，九个字段使用竖线分隔。",
                "`; Cada AppN corresponde a un elemento de supervisión`; los nueve campos están separados por barras verticales.")
        catalog.Set(
            "DPI 变化后刷新图标失败：{1}",
                "No se pudo actualizar el icono después del cambio de DPI: {1}")
        catalog.Set(
            "DPI 变化后重建图标列表失败：{1}",
                "No se pudo reconstruir la lista de iconos después del cambio de DPI: {1}")
        catalog.Set(
            "DPI 图标重建回调无效",
                "La devolución de llamada para reconstruir los iconos por cambio de DPI no es válida")
        catalog.Set(
            "{1} 条监控配置未载入，相关项目当前不会被守护。点击查看具体位置和原因。",
                "No se cargaron {1} configuraciones de supervisión`; los elementos correspondientes no se están supervisando. Haga clic para ver su ubicación y el motivo.")
        catalog.Set(
            "• Ahk2Exe 只在发布服务器上用于生成 EXE，不随小助手安装，普通用户和源码运行用户都不需要维护它。",
                "• Ahk2Exe solo se usa en el servidor de publicación para generar el EXE. No se instala con el asistente y ni los usuarios normales ni quienes ejecutan el código fuente tienen que mantenerlo.")
        catalog.Set(
            "• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。",
                "• Ctrl+A selecciona todo. Esc primero anula la selección`; si no hay elementos seleccionados, al volver a pulsar Esc se oculta la ventana principal.")
        catalog.Set(
            "• EXE 版已内嵌该版本发布时验证通过的 AutoHotkey；更新完整小助手发行包时，内嵌运行时会一同更新，电脑无需另装 AutoHotkey。",
                "• La edición EXE incorpora la versión de AutoHotkey verificada al publicar esa versión. El entorno incorporado se actualiza con el paquete completo del asistente y no es necesario instalar AutoHotkey en el equipo.")
        catalog.Set(
            "• EXE 版更新完整编译包；Git 源码版仅在受跟踪文件无修改且可快速前进时更新；其他源码版使用源码发行包。",
                "• La edición EXE actualiza el paquete compilado completo. La edición desde código fuente de Git solo se actualiza si los archivos seguidos no tienen cambios y se puede avanzar directamente`; las demás instalaciones desde código fuente usan el paquete de código fuente.")
        catalog.Set(
            "• “监控与启动”可控制是否在启动时后台检查新版；“通用”可随时手动检查。检查过程不会阻塞主界面。",
                "• En “Supervisión e inicio” puede elegir si se buscan nuevas versiones en segundo plano al iniciar`; en “General” puede iniciar una búsqueda manual en cualquier momento. La comprobación no bloquea la ventana principal.")
        catalog.Set(
            "• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止”中的选项决定。",
                "• “Reiniciar” solicita primero al destino que se cierre normalmente. Si se supera el tiempo configurado, la opción correspondiente de “Detención” determina si se fuerza la finalización.")
        catalog.Set(
            "• 主界面的“日志”显示本次运行中的监控、重启、升级保护和操作记录，并会自动更新。",
                "• “Registro” en la ventana principal muestra y actualiza automáticamente los eventos de supervisión, reinicio, protección de actualizaciones y operaciones de la sesión actual.")
        catalog.Set(
            "• 也可将文件或文件夹直接拖放到主列表；已经存在的项目不会重复添加。",
                "• También puede arrastrar archivos o carpetas directamente a la lista principal`; los elementos existentes no se vuelven a añadir.")
        catalog.Set(
            "• 停止：设置窗口程序和命令行程序的退出等待，以及是否允许强制终止。",
                "• Detención: configure el tiempo de espera de salida para programas con ventana y de línea de comandos, y si se permite forzar su finalización.")
        catalog.Set(
            "• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。",
                "• Al cerrar la ventana principal, el asistente sigue ejecutándose en la bandeja del sistema. Su menú permite volver a mostrar la interfaz, recargar o salir.")
        catalog.Set(
            "• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。",
                "• Si se agota la espera de una actualización o la detección es incorrecta, puede elegir “Finalizar la espera de actualización y reanudar la supervisión”`; antes de reanudar se comprueba que el destino se pueda iniciar de forma segura.")
        catalog.Set(
            "• 单击选择项目；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。",
                "• Haga clic para seleccionar un elemento`; mantenga pulsado Ctrl o Shift para seleccionar varios`; arrastre las filas para cambiar el orden de supervisión.")
        catalog.Set(
            "• 双击项目或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。",
                "• Haga doble clic en un elemento o pulse F2 para editar la ruta completa. Delete elimina, Ctrl+Z deshace y Ctrl+Shift+Z o Ctrl+Y rehace.")
        catalog.Set(
            "• 发现新版后会先询问；确认后校验完整发行包，退出当前实例、替换受管文件并自动重启，不会覆盖个人配置和升级保护会话。",
                "• Cuando haya una nueva versión, se pedirá confirmación. Después se verificará el paquete completo, se cerrará la instancia actual, se sustituirán los archivos administrados y se reiniciará automáticamente, sin sobrescribir la configuración personal ni las sesiones de protección de actualizaciones.")
        catalog.Set(
            "• 可控的更新脚本可显式发送维护指令：",
                "• Un script de actualización bajo su control puede enviar instrucciones de mantenimiento explícitas:")
        catalog.Set(
            "• 右键项目可自定义主窗口名称和图标，也可打开所在位置、重新启动、编辑路径、切换管理员运行、配置高级运行环境与软件升级保护，并查看批处理输出日志。要求管理员运行但当前权限不符时会显示警告；右键重新启动会按该设置提权启动。",
                "• Haga clic con el botón derecho en un elemento para personalizar su nombre e icono en la ventana principal, abrir su ubicación, reiniciarlo, editar la ruta, cambiar la ejecución como administrador, configurar el entorno de ejecución avanzado y la protección de actualizaciones, o ver el registro de salida por lotes. Si se exige ejecución como administrador pero el proceso actual no tiene los permisos necesarios, se mostrará un aviso`; al reiniciarlo desde el menú contextual se elevarán los permisos según esa opción.")
        catalog.Set(
            "• 在项目右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。",
                "• Abra “Protección de actualizaciones de software” desde el menú contextual para ajustar el directorio de instalación, la ventana de detección de salida, la espera de estabilidad del archivo y la espera máxima de actualización, o para borrar las características aprendidas del actualizador.")
        catalog.Set(
            "• 多选项目状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。",
                "• Si todos los elementos seleccionados tienen el mismo estado, “Pausar” los pausará o reanudará juntos`; si los estados están mezclados, se invertirá cada uno.")
        catalog.Set(
            "• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。",
                "• El asistente compara la ruta o la línea de comandos del destino para evitar identificaciones erróneas basadas solo en el nombre del proceso.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“通用”页会同时显示当前小助手版本、运行形态和实际运行时版本。",
                "• La versión del asistente y la de AutoHotkey son independientes. “General” muestra la versión actual del asistente, el modo de ejecución y la versión real del entorno.")
        catalog.Set(
            "• 程序搜索：仅使用 Everything 服务并显示全部匹配结果；使用前请保持 Everything 正在运行。",
                "• Búsqueda de programas: usa únicamente el servicio Everything y muestra todos los resultados coincidentes. Antes de buscar, asegúrese de que Everything esté en ejecución.")
        catalog.Set(
            "• 日志：设置运行日志内存上限、批处理输出日志的保存目录、保留时间和启动时清理策略。",
                "• Registros: configure el límite de registros de ejecución en memoria, el directorio de los registros de salida por lotes, el periodo de conservación y la limpieza al iniciar.")
        catalog.Set(
            "• 暂停项目会取消该项目的重试和升级检测；恢复后会重新检查目标状态。",
                "• Al pausar un elemento se cancelan sus reintentos y la detección de actualizaciones`; al reanudarlo se vuelve a comprobar el estado del destino.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“重启等待序列”依次重试；连续失败时采用后续等待时间，避免频繁拉起。",
                "• Cuando se detecta que el destino se ha detenido, primero se confirma su estado y después se reintenta según la “Secuencia de espera para reiniciar”`; tras varios fallos se usan los tiempos posteriores para evitar inicios demasiado frecuentes.")
        catalog.Set(
            "• 每次正式发布开始时都会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版（可能为预发布），冻结本次版本后完成全套测试；只有通过才生成发行包。",
                "• Al comenzar cada publicación oficial se vuelven a seleccionar la versión estable más reciente de AutoHotkey y la última versión publicada de Ahk2Exe（que puede ser una versión preliminar）, se fijan para esa publicación y se ejecutan todas las pruebas. El paquete solo se genera si todo pasa correctamente.")
        catalog.Set(
            "• 源码版使用电脑当前安装的 AutoHotkey；小助手更新只更新项目源码，不会安装或升级本机解释器。",
                "• La edición desde código fuente usa la instalación actual de AutoHotkey del equipo. La actualización del asistente solo actualiza el código del proyecto y no instala ni actualiza el intérprete local.")
        catalog.Set(
            "• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。",
                "• Haga clic en “Añadir” para buscar una aplicación o seleccionar programas, scripts, accesos directos y carpetas.")
        catalog.Set(
            "• 界面语言和字体可在“通用”中手动切换；保存后立即更新主窗口、菜单和托盘，无需重新启动。",
                "• El idioma y la fuente de la interfaz se pueden cambiar en “General”. Al guardar, la ventana principal, los menús y la bandeja se actualizan de inmediato, sin reiniciar.")
        catalog.Set(
            "• 监控与启动：设置状态检查间隔、重启等待序列、启动后是否显示主窗口、是否检查小助手更新，以及文件夹批量导入是否递归。",
                "• Supervisión e inicio: configure el intervalo de comprobación, la secuencia de espera para reiniciar, si se muestra la ventana principal y se buscan actualizaciones al iniciar, y si la importación de carpetas recorre las subcarpetas.")
        catalog.Set(
            "• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。",
                "• Tras confirmar una actualización se suspenden los inicios automáticos. Cuando termina la actividad relacionada y el archivo de destino se estabiliza, la supervisión se reanuda automáticamente. Las características del actualizador detectadas durante una actualización real se guardan de forma automática.")
        catalog.Set(
            "• 程序：EXE、COM、MSC。",
                "• Programas: EXE, COM y MSC.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，并可立即检查小助手更新。",
                "• General: cree accesos directos en el escritorio y el menú Inicio, active o desactive el inicio automático mediante una tarea programada y busque inmediatamente actualizaciones del asistente.")
        catalog.Set(
            "• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。",
                "• Scripts: AHK, Python, JavaScript, VBScript, PowerShell, archivos por lotes y también Ruby, Perl, PHP, Lua, JAR, Shell, entre otros.")
        catalog.Set(
            "• 软件升级保护默认关闭。需要时在项目右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。",
                "• La protección de actualizaciones de software está desactivada de forma predeterminada. Cuando la necesite, abra “Protección de actualizaciones de software” desde el menú contextual, marque “Detectar actualizaciones automáticamente y proteger el proceso de inicio” y guarde.")
        catalog.Set(
            "• 选中项目后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。",
                "• Después de seleccionar elementos puede pausarlos, reanudarlos o eliminarlos. La pausa solo detiene la supervisión`; no cierra los destinos que se estén ejecutando.")
        catalog.Set(
            "• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控与启动”控制。",
                "• Al seleccionar una carpeta se importan por lotes los archivos compatibles que contiene. La opción “Supervisión e inicio” de “Configuración” determina si también se recorren las subcarpetas.")
        catalog.Set(
            "• 项目右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。",
                "• “Ver registro de ejecución” en el menú contextual abre el registro de salida generado por destinos BAT/CMD. Para otros tipos o si aún no existe, se indicará que el archivo no está disponible.")
        catalog.Set(
            "⏳ 停止原进程...",
                "⏳ Deteniendo el proceso original...")
        catalog.Set(
            "⏳ 判断是否正在升级",
                "⏳ Comprobando si hay una actualización en curso")
        catalog.Set(
            "⏳ 升级完成，准备恢复",
                "⏳ Actualización terminada`; preparando la reanudación")
        catalog.Set(
            "⏳ 启动倒计时 {1} 秒",
                "⏳ Inicio en {1} segundos")
        catalog.Set(
            "⏳ 启动失败，稍后自动重试",
                "⏳ No se pudo iniciar`; se reintentará automáticamente más tarde")
        catalog.Set(
            "⏳ 确认升级文件稳定",
                "⏳ Confirmando que los archivos de actualización sean estables")
        catalog.Set(
            "⏳ 确认升级文件稳定 {1}s",
                "⏳ Confirmando la estabilidad de los archivos de actualización {1}s")
        catalog.Set(
            "⏳ 稍后自动重试 {1} 秒",
                "⏳ Reintento automático dentro de {1} segundos")
        catalog.Set(
            "⏳ 等待安全启动条件",
                "⏳ Esperando condiciones de inicio seguras")
        catalog.Set(
            "⏳ 等待进程状态...",
                "⏳ Esperando el estado del proceso...")
        catalog.Set(
            "⏳ 重试倒计时 {1} 秒",
                "⏳ Reintento dentro de {1} segundos")
        catalog.Set(
            "⏳ 验证运行状态...",
                "⏳ Verificando el estado de ejecución...")
        catalog.Set(
            "⏸️ 已暂停",
                "⏸️ En pausa")
        catalog.Set(
            "⏸️ 暂停",
                "⏸️ Pausar")
        catalog.Set(
            "▶️ 恢复",
                "▶️ Reanudar")
        catalog.Set(
            "⚙️ 启动参数：{1}`n",
                "⚙️ Argumentos de inicio: {1}`n")
        catalog.Set(
            "⚠️ 升级等待超时",
                "⚠️ Se agotó la espera de actualización")
        catalog.Set(
            "⚠️ 疑似停止",
                "⚠️ Posible detención")
        catalog.Set(
            "⚠️ 运行中（权限不符）",
                "⚠️ En ejecución（permisos incorrectos）")
        catalog.Set(
            "✅ 已启动（非驻留目标）",
                "✅ Iniciado（destino no residente）")
        catalog.Set(
            "✅ 运行中",
                "✅ En ejecución")
        catalog.Set(
            "✅ 运行：{1}   🚫 停止：{2}   ⏳ 恢复：{3}   🔄 升级：{4}   ⏸️ 暂停：{5}   ❌ 失效：{6}   ｜   🎯 总计：{7}",
                "✅ En ejecución: {1}   🚫 Detenidos: {2}   ⏳ En espera: {3}   🔄 Actualizando: {4}   ⏸️ En pausa: {5}   ❌ No válidos: {6}   ｜   🎯 Total: {7}")
        catalog.Set(
            "✒️ 编辑完整路径（F2）",
                "✒️ Editar la ruta completa（F2）")
        catalog.Set(
            "确 定",
                "Aceptar")
        catalog.Set(
            "取 消",
                "Cancelar")
        catalog.Set(
            "❌ 无法停止原进程",
                "❌ No se pudo detener el proceso original")
        catalog.Set(
            "❌ 目标不存在",
                "❌ El destino no existe")
        catalog.Set(
            "❌ 程序不存在",
                "❌ El programa no existe")
        catalog.Set(
            "❌ 脚本不存在",
                "❌ El script no existe")
        catalog.Set(
            "➕ 添加",
                "➕ Añadir")
        catalog.Set(
            "。",
                ".")
        catalog.Set(
            "一、快速上手",
                "1. Inicio rápido")
        catalog.Set(
            "七、软件升级保护",
                "7. Protección de actualizaciones de software")
        catalog.Set(
            "三、主界面操作",
                "3. Operaciones de la ventana principal")
        catalog.Set(
            "不允许的升级保护阶段转换：{1}",
                "Transición de fase de protección de actualizaciones no permitida: {1}")
        catalog.Set(
            "不支持的启动规格类型",
                "Tipo de especificación de inicio no compatible")
        catalog.Set(
            "不支持的图标格式",
                "Formato de icono no compatible")
        catalog.Set(
            "不是当前 <HEX> 编码格式",
                "No corresponde al formato de codificación <HEX> actual")
        catalog.Set(
            "与已加载项目重复，或目标格式无效",
                "Duplica un elemento cargado o el formato del destino no es válido")
        catalog.Set(
            "主进程监控",
                "Supervisión del proceso principal")
        catalog.Set(
            "主进程监控异常：{1}",
                "Error en la supervisión del proceso principal: {1}")
        catalog.Set(
            "二、支持的目标",
                "2. Destinos compatibles")
        catalog.Set(
            "五、设置",
                "5. Configuración")
        catalog.Set(
            "代码热重载完毕，界面已恢复显示。",
                "La recarga dinámica del código ha terminado y la interfaz vuelve a estar visible.")
        catalog.Set(
            "仲裁期间捕获到升级活动",
                "Se detectó actividad de actualización durante el arbitraje")
        catalog.Set(
            "使用说明",
                "Guía de uso")
        catalog.Set(
            "恢复默认",
                "Restaurar")
        catalog.Set(
            "保存",
                "Guardar")
        catalog.Set(
            "保存升级保护恢复状态失败：{1}",
                "No se pudo guardar el estado de recuperación de la protección de actualizaciones: {1}")
        catalog.Set(
            "保存失败",
                "No se pudo guardar")
        catalog.Set(
            "保存显示设置失败，请查看运行日志。",
                "No se pudo guardar la configuración de presentación. Consulte el registro de ejecución.")
        catalog.Set(
            "保存监控配置失败：{1}",
                "No se pudo guardar la configuración de supervisión: {1}")
        catalog.Set(
            "保存窗口布局失败：{1}",
                "No se pudo guardar la disposición de la ventana: {1}")
        catalog.Set(
            "保存设置失败，请查看运行日志。",
                "No se pudo guardar la configuración. Consulte el registro de ejecución.")
        catalog.Set(
            "保存软件升级保护设置失败，请查看运行日志。",
                "No se pudo guardar la configuración de protección de actualizaciones de software. Consulte el registro de ejecución.")
        catalog.Set(
            "保存运行参数失败：{1}",
                "No se pudieron guardar los parámetros de ejecución: {1}")
        catalog.Set(
            "值不是 0 或 1",
                "El valor no es 0 ni 1")
        catalog.Set(
            "停止",
                "Detención")
        catalog.Set(
            "八、日志与托盘",
                "8. Registros y bandeja del sistema")
        catalog.Set(
            "六、版本与小助手自身更新",
                "6. Versiones y actualización del asistente")
        catalog.Set(
            "内容为空",
                "El contenido está vacío")
        catalog.Set(
            "内容无法解析",
                "No se puede interpretar el contenido")
        catalog.Set(
            "创建快捷方式失败：{1}",
                "No se pudo crear el acceso directo: {1}")
        catalog.Set(
            "初始化...",
                "Inicializando...")
        catalog.Set(
            "删除选中的守护项目（支持多选，可撤销）`n快捷键：Delete",
                "Eliminar los elementos de supervisión seleccionados（admite selección múltiple y deshacer）`nTecla: Delete")
        catalog.Set(
            "刷新主窗口状态失败，已暂停界面倒计时刷新：{1}",
                "No se pudo actualizar el estado de la ventana principal`; se ha pausado la actualización de la cuenta atrás de la interfaz: {1}")
        catalog.Set(
            "刷新运行日志窗口失败，已暂停自动刷新：{1}",
                "No se pudo actualizar la ventana de registro de ejecución`; se ha pausado la actualización automática: {1}")
        catalog.Set(
            "升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。",
                "La protección de actualizaciones solo admite programas o scripts con una ruta completa válida. El directorio de instalación debe existir y contener el archivo de destino.")
        catalog.Set(
            "升级保护仍在进行",
                "La protección de actualizaciones sigue activa")
        catalog.Set(
            "升级保护初始化时无法建立进程基线，将在下一轮重试。",
                "No se pudo crear la línea base de procesos al inicializar la protección de actualizaciones`; se volverá a intentar en el siguiente ciclo.")
        catalog.Set(
            "升级保护协调器未能初始化，核心守护不会启动。",
                "No se pudo inicializar el coordinador de protección de actualizaciones`; la supervisión principal no se iniciará.")
        catalog.Set(
            "升级保护配置",
                "Configuración de protección de actualizaciones")
        catalog.Set(
            "升级文件监听",
                "Vigilancia de archivos de actualización")
        catalog.Set(
            "升级文件监听异常（{1}）：{2}",
                "Error en la vigilancia de archivos de actualización（{1}）: {2}")
        catalog.Set(
            "升级文件监听异常：{1}",
                "Error en la vigilancia de archivos de actualización: {1}")
        catalog.Set(
            "升级等待已超时",
                "Se agotó la espera de actualización")
        catalog.Set(
            "升级进程扫描",
                "Análisis de procesos de actualización")
        catalog.Set(
            "升级进程扫描异常：{1}",
                "Error en el análisis de procesos de actualización: {1}")
        catalog.Set(
            "参数错误",
                "Error de argumentos")
        catalog.Set(
            "发现小助手新版本：{1}（当前版本：{2}）",
                "Nueva versión del asistente disponible: {1}（versión actual: {2}）")
        catalog.Set(
            "发现新版本 {1}，当前版本为 {2}。{3}{3}{4}{3}{3}是否立即更新？",
                "Hay una nueva versión {1}`; la versión actual es {2}.{3}{3}{4}{3}{3}¿Desea actualizar ahora?")
        catalog.Set(
            "取消",
                "Cancelar")
        catalog.Set(
            "名称",
                "Nombre")
        catalog.Set(
            "后台任务耗时较长：{1}，本次 {2} 毫秒",
                "Una tarea en segundo plano ha tardado demasiado: {1}`; esta ejecución duró {2} ms")
        catalog.Set(
            "后台扫描进程未返回 PID",
                "El proceso de análisis en segundo plano no devolvió un PID")
        catalog.Set(
            "后台调度任务异常（{1}）：{2}",
                "Error en una tarea programada en segundo plano（{1}）: {2}")
        catalog.Set(
            "后台进程快照为空或不完整，已忽略本次结果并安排重试。",
                "La instantánea de procesos en segundo plano está vacía o incompleta`; se ha ignorado y se ha programado otro intento.")
        catalog.Set(
            "后台进程快照已确认",
                "Instantánea de procesos en segundo plano confirmada")
        catalog.Set(
            "后台进程快照未及时返回，已等待完整检测窗口",
                "La instantánea de procesos en segundo plano no llegó a tiempo`; se esperó toda la ventana de detección")
        catalog.Set(
            "启动前没有可用的启动目标，已停止重试：{1}{2}",
                "No hay ningún destino de inicio disponible antes de iniciar`; se han detenido los reintentos: {1}{2}")
        catalog.Set(
            "启动参数",
                "Argumentos de inicio")
        catalog.Set(
            "启动参数（Args）：",
                "Argumentos de inicio（Args）：")
        catalog.Set(
            "启动器需要 LaunchSpec",
                "El iniciador requiere LaunchSpec")
        catalog.Set(
            "启动失败",
                "No se pudo iniciar")
        catalog.Set(
            "启动失败 [{1}/{2}]：{3} - {4}",
                "No se pudo iniciar [{1}/{2}]: {3} - {4}")
        catalog.Set(
            "启动成功且运行稳定：{1}",
                "Inicio correcto y ejecución estable: {1}")
        catalog.Set(
            "启动批量导入失败",
                "No se pudo iniciar la importación por lotes")
        catalog.Set(
            "启动时检查小助手更新",
                "Buscar actualizaciones del asistente al iniciar")
        catalog.Set(
            "启动时清空批处理日志",
                "Borrar los registros de lotes al iniciar")
        catalog.Set(
            "启动目标不可用",
                "El destino de inicio no está disponible")
        catalog.Set(
            "启动目标不存在",
                "El destino de inicio no existe")
        catalog.Set(
            "启用状态",
                "Estado habilitado")
        catalog.Set(
            "四、守护与重启",
                "4. Supervisión y reinicio")
        catalog.Set(
            "图标来源无效",
                "El origen del icono no es válido")
        catalog.Set(
            "图标来源：",
                "Origen del icono：")
        catalog.Set(
            "图标缩放器",
                "Escalador de iconos")
        catalog.Set(
            "处理后台进程快照时发生错误：{1}",
                "Error al procesar la instantánea de procesos en segundo plano: {1}")
        catalog.Set(
            "处理应用更新结果失败：{1}",
                "No se pudo procesar el resultado de actualización de la aplicación: {1}")
        catalog.Set(
            "字段数量应为 {1}，实际为 {2}",
                "Se esperaban {1} campos, pero se encontraron {2}")
        catalog.Set(
            "守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！",
                "Las operaciones de supervisión requieren permisos elevados de lectura y escritura del sistema. Ejecute este programa como administrador.")
        catalog.Set(
            "守护目标：",
                "Destino supervisado：")
        catalog.Set(
            "安全启动门暂缓启动：{1}（{2}）",
                "La puerta de inicio seguro ha aplazado el inicio: {1}（{2}）")
        catalog.Set(
            "安装目录特征",
                "Características del directorio de instalación")
        catalog.Set(
            "安装足迹目录：",
                "Directorio de instalación：")
        catalog.Set(
            "完整路径",
                "Ruta completa")
        catalog.Set(
            "完整路径：{1}",
                "Ruta completa: {1}")
        catalog.Set(
            "导出诊断包",
                "Exportar paquete de diagnóstico")
        catalog.Set(
            "导出诊断包失败：{1}",
                "No se pudo exportar el paquete de diagnóstico: {1}")
        catalog.Set(
            "将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。",
                "Se descargará y verificará el paquete de distribución completo. Después de cerrar el asistente, se sustituirán los archivos del programa y se reiniciará automáticamente.")
        catalog.Set(
            "将下载并校验源码发行包，保留个人配置后替换源码并自动重启。",
                "Se descargará y verificará el paquete de código fuente. Después se sustituirá el código y se reiniciará automáticamente, conservando la configuración personal.")
        catalog.Set(
            "将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。",
                "Se comprobará que el repositorio de código fuente no tenga cambios sin confirmar`; después se avanzará directamente hasta la etiqueta de publicación oficial y se reiniciará automáticamente.")
        catalog.Set(
            "小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。",
                "El asistente comprueba en segundo plano programas, scripts y accesos directos. Si un destino termina de forma anómala, lo reinicia según la secuencia de espera configurada. Cerrar la ventana principal solo la oculta en la bandeja del sistema y no detiene la supervisión.")
        catalog.Set(
            "小助手已是最新版本：{1}",
                "El asistente ya está actualizado: {1}")
        catalog.Set(
            "小助手更新",
                "Actualización del asistente")
        catalog.Set(
            "小助手设置",
                "Configuración del asistente")
        catalog.Set(
            "尚未从真实升级过程学习到更新程序特征。",
                "Aún no se han aprendido características del actualizador a partir de una actualización real.")
        catalog.Set(
            "展示配置",
                "Configuración de presentación")
        catalog.Set(
            "工作目录",
                "Directorio de trabajo")
        catalog.Set(
            "工作目录（CWD）：",
                "Directorio de trabajo（CWD）：")
        catalog.Set(
            "已从本次升级过程学习更新程序特征：{1}",
                "Características del actualizador aprendidas durante esta actualización: {1}")
        catalog.Set(
            "已保存身份",
                "Identidad guardada")
        catalog.Set(
            "已关闭以管理员身份运行：{1}",
                "Se ha desactivado la ejecución como administrador: {1}")
        catalog.Set(
            "已创建最高权限的开机自启计划任务（Win10 配置，适配笔记本）。",
                "Se ha creado una tarea programada de inicio automático con los máximos privilegios（configuración de Windows 10 compatible con portátiles）.")
        catalog.Set(
            "已创建桌面与开始菜单快捷方式。",
                "Se han creado accesos directos en el escritorio y el menú Inicio.")
        catalog.Set(
            "已删除自启计划任务。",
                "Se ha eliminado la tarea programada de inicio automático.")
        catalog.Set(
            "已刷新快捷方式内置参数：{1}",
                "Se han actualizado los argumentos integrados del acceso directo: {1}")
        catalog.Set(
            "已刷新快捷方式真实进程（{1}）：{2} -> {3}",
                "Se ha actualizado el proceso real del acceso directo（{1}）: {2} -> {3}")
        catalog.Set(
            "已发送启动指令：{1}{2}",
                "Se ha enviado la instrucción de inicio: {1}{2}")
        catalog.Set(
            "已取消监控：{1}",
                "Supervisión cancelada: {1}")
        catalog.Set(
            "已启动批处理并重定向输出到：{1}",
                "Se ha iniciado el proceso por lotes y su salida se redirige a: {1}")
        catalog.Set(
            "已启动非驻留目标：{1}",
                "Se ha iniciado un destino no residente: {1}")
        catalog.Set(
            "已启用以管理员身份运行：{1}",
                "Se ha activado la ejecución como administrador: {1}")
        catalog.Set(
            "已导出本地诊断包：{1}",
                "Paquete de diagnóstico local exportado: {1}")
        catalog.Set(
            "已恢复未完成的升级保护会话：{1}",
                "Se ha restaurado una sesión de protección de actualizaciones sin terminar: {1}")
        catalog.Set(
            "已撤销上一步操作。",
                "Se ha deshecho la última operación.")
        catalog.Set(
            "已更新主窗口显示设置：{1}",
                "Se ha actualizado la configuración de presentación de la ventana principal: {1}")
        catalog.Set(
            "已更新应用程序路径。",
                "Se ha actualizado la ruta de la aplicación.")
        catalog.Set(
            "已更新软件升级保护设置：{1}",
                "Se ha actualizado la configuración de protección de actualizaciones de software: {1}")
        catalog.Set(
            "已添加 {1} 个监控项。",
                "Se han añadido {1} elementos de supervisión.")
        catalog.Set(
            "已用完快速重试，将每隔 {1} 秒继续尝试启动：{2}",
                "Se agotaron los reintentos rápidos`; se seguirá intentando iniciar cada {1} segundos: {2}")
        catalog.Set(
            "已自动学习的更新程序特征：",
                "Características del actualizador aprendidas automáticamente:")
        catalog.Set(
            "已进入软件升级保护：{1}{2}",
                "Se ha activado la protección de actualizaciones de software: {1}{2}")
        catalog.Set(
            "已重做操作。",
                "Se ha rehecho la operación.")
        catalog.Set(
            "常规终止权限不足，已提权终止进程 PID：{1}",
                "La finalización normal no tenía permisos suficientes`; se ha elevado la finalización del proceso con PID: {1}")
        catalog.Set(
            "序号",
                "N.º")
        catalog.Set(
            "应用更新助手不存在",
                "No se encuentra el asistente de actualización de la aplicación")
        catalog.Set(
            "应用更新参数无效",
                "Los argumentos de actualización de la aplicación no son válidos")
        catalog.Set(
            "应用更新安装进程未返回 PID",
                "El proceso de instalación de la actualización no devolvió un PID")
        catalog.Set(
            "应用更新本地化资源不存在",
                "No se encuentran los recursos de localización de la actualización de la aplicación")
        catalog.Set(
            "应用更新检查进程未返回 PID",
                "El proceso de búsqueda de actualizaciones no devolvió un PID")
        catalog.Set(
            "应用程序",
                "Aplicación")
        catalog.Set(
            "应用资源",
                "Recursos de la aplicación")
        catalog.Set(
            "开机自动启动（计划任务）",
                "Inicio automático al encender（tarea programada）")
        catalog.Set(
            "当前陪伴您的已经是最新版本的小助手啦！",
                "¡El asistente que te acompaña ya está actualizado a la última versión!")
        catalog.Set(
            "当前应用版本无效",
                "La versión actual de la aplicación no es válida")
        catalog.Set(
            "当前版本：{1}（EXE 版；内嵌 AutoHotkey {2} x64）",
                "Versión actual: {1}（edición EXE`; AutoHotkey {2} x64 incorporado）")
        catalog.Set(
            "当前版本：{1}（源码版；本机 AutoHotkey {2} x64）",
                "Versión actual: {1}（edición desde código fuente`; AutoHotkey local {2} x64）")
        catalog.Set(
            "当前状态：升级活动已结束，正在确认程序文件稳定",
                "Estado actual: la actividad de actualización ha terminado`; confirmando la estabilidad de los archivos del programa")
        catalog.Set(
            "当前状态：升级等待超时，需要确认后恢复",
                "Estado actual: se agotó la espera de actualización`; se requiere confirmación para reanudar")
        catalog.Set(
            "当前状态：已从上次运行恢复未完成的升级保护",
                "Estado actual: se restauró la protección de actualizaciones que quedó sin terminar en la ejecución anterior")
        catalog.Set(
            "当前状态：已暂停自动启动，正在等待升级完成",
                "Estado actual: el inicio automático está en pausa mientras termina la actualización")
        catalog.Set(
            "当前状态：显式升级维护已开始，正在等待结束命令",
                "Estado actual: comenzó el mantenimiento explícito de actualización`; esperando la orden de finalización")
        catalog.Set(
            "当前状态：正在判断本次退出是否由升级引起",
                "Estado actual: comprobando si esta salida se debe a una actualización")
        catalog.Set(
            "当前状态：正常守护",
                "Estado actual: supervisión normal")
        catalog.Set(
            "快捷方式参数",
                "Argumentos del acceso directo")
        catalog.Set(
            "快捷方式及已解析目标均不可用",
                "Ni el acceso directo ni su destino resuelto están disponibles")
        catalog.Set(
            "快捷方式目标",
                "Destino del acceso directo")
        catalog.Set(
            "快捷方式真实目标",
                "Destino real del acceso directo")
        catalog.Set(
            "快捷方式真实进程刷新被拒绝，目标已由其它项目守护：{1} -> {2}",
                "Se rechazó la actualización del proceso real del acceso directo porque otro elemento ya supervisa el destino: {1} -> {2}")
        catalog.Set(
            "恢复守护：{1}",
                "Reanudar la supervisión: {1}")
        catalog.Set(
            "恢复记录列表无效",
                "La lista de registros de restauración no es válida")
        catalog.Set(
            "恢复记录无效",
                "El registro de restauración no es válido")
        catalog.Set(
            "恢复记录缺少字段：{1}",
                "Falta un campo en el registro de restauración: {1}")
        catalog.Set(
            "成功",
                "Correcto")
        catalog.Set(
            "所选文件夹内未找到支持的程序、脚本或快捷方式。",
                "No se encontraron programas, scripts ni accesos directos compatibles en la carpeta seleccionada.")
        catalog.Set(
            "手动添加监控：{1}",
                "Supervisión añadida manualmente: {1}")
        catalog.Set(
            "手动触发了重新启动：{1}",
                "Reinicio activado manualmente: {1}")
        catalog.Set(
            "手动重启已取消，原进程未能停止：{1}",
                "Se canceló el reinicio manual porque no se pudo detener el proceso original: {1}")
        catalog.Set(
            "托管窗口生命周期尚未配置",
                "El ciclo de vida de la ventana administrada aún no está configurado")
        catalog.Set(
            "托管窗口生命周期适配器无效",
                "El adaptador del ciclo de vida de la ventana administrada no es válido")
        catalog.Set(
            "扩展设置包含无效数值。`n`n窗口程序关闭等待：1-300 秒`n命令行程序退出等待：1-60 秒`n日志条数：50-10000`n日志保留：1-3650 天",
                "Uno o más ajustes avanzados no son válidos.`n`nEspera para cerrar aplicaciones con ventana: 1-300 segundos`nEspera para salir de aplicaciones de línea de comandos: 1-60 segundos`nEntradas del registro: 50-10000`nConservación de registros: 1-3650 días")
        catalog.Set(
            "批处理启动需要输出日志路径",
                "El inicio de un proceso por lotes requiere una ruta de registro de salida")
        catalog.Set(
            "批量导入中断",
                "Importación por lotes interrumpida")
        catalog.Set(
            "批量导入完成",
                "Importación por lotes terminada")
        catalog.Set(
            "批量导入已取消，已保留并保存此前添加的 {1} 个监控项。",
                "Se canceló la importación por lotes. Se han conservado y guardado los {1} elementos de supervisión añadidos anteriormente.")
        catalog.Set(
            "拒绝修改路径，真实进程已由其它项目守护：{1}",
                "Se rechazó el cambio de ruta porque otro elemento ya supervisa el proceso real: {1}")
        catalog.Set(
            "拒绝将应用路径改为已存在的监控项：{1}",
                "Se rechazó el cambio de la ruta de la aplicación porque ya existe un elemento de supervisión con esa ruta: {1}")
        catalog.Set(
            "按钮绘制器",
                "Procesador de dibujo de botones")
        catalog.Set(
            "捕获监控项历史失败：{1}",
                "No se pudo capturar el historial de elementos de supervisión: {1}")
        catalog.Set(
            "提示",
                "Aviso")
        catalog.Set(
            "⚡️搜索⚡️",
                "⚡️ Búsqueda ⚡️")
        catalog.Set(
            "操作计划任务时发生错误！`n`n{1}",
                "Se produjo un error al operar la tarea programada.`n`n{1}")
        catalog.Set(
            "支持的图标与图片",
                "Iconos e imágenes compatibles")
        catalog.Set(
            "支持的程序、脚本与快捷方式",
                "Programas, scripts y accesos directos compatibles")
        catalog.Set(
            "支持的程序与脚本",
                "Programas y scripts compatibles")
        catalog.Set(
            "收到显式维护开始命令",
                "Se recibió la orden explícita de iniciar el mantenimiento")
        catalog.Set(
            "收到显式维护结束命令，开始执行安全恢复检查：{1}",
                "Se recibió la orden explícita de finalizar el mantenimiento`; comenzando la comprobación para reanudar de forma segura: {1}")
        catalog.Set(
            "整条展示配置",
                "Configuración de presentación completa")
        catalog.Set(
            "整条记录",
                "Registro completo")
        catalog.Set(
            "文件稳定等待（秒）：",
                "Espera de estabilidad del archivo（segundos）：")
        catalog.Set(
            "新脚本未通过 AutoHotkey 解析检查",
                "El nuevo script no superó la comprobación de análisis de AutoHotkey")
        catalog.Set(
            "无法从损坏记录中提取",
                "No se pudo extraer información del registro dañado")
        catalog.Set(
            "无法停止进程 PID：{1}{2}",
                "No se pudo finalizar el proceso con PID {1}{2}")
        catalog.Set(
            "无法写入诊断文件：{1}",
                "No se pudo escribir el archivo de diagnóstico: {1}")
        catalog.Set(
            "无法启动后台文件扫描：{1}",
                "No se pudo iniciar el análisis de archivos en segundo plano: {1}")
        catalog.Set(
            "无法启动后台进程快照任务：{1}",
                "No se pudo iniciar la tarea de instantánea de procesos en segundo plano: {1}")
        catalog.Set(
            "无法启动小助手更新安装：{1}",
                "No se pudo iniciar la instalación de la actualización del asistente: {1}")
        catalog.Set(
            "无法启动小助手更新检查：{1}",
                "No se pudo iniciar la búsqueda de actualizaciones del asistente: {1}")
        catalog.Set(
            "无法导出诊断包：`n{1}",
                "No se pudo exportar el paquete de diagnóstico:`n{1}")
        catalog.Set(
            "无法建立单实例运行锁，小助手将退出。",
                "No se pudo obtener el bloqueo de instancia única`; el asistente se cerrará.")
        catalog.Set(
            "无法开始更新：{1}",
                "No se pudo iniciar la actualización: {1}")
        catalog.Set(
            "无法收集此部分诊断信息：{1}",
                "No se pudo recopilar esta sección de la información de diagnóstico: {1}")
        catalog.Set(
            "无法检查更新：{1}",
                "No se pudo buscar actualizaciones: {1}")
        catalog.Set(
            "无法清理后台扫描临时文件：{1}",
                "No se pudo limpiar el archivo temporal del análisis en segundo plano: {1}")
        catalog.Set(
            "无法清理后台扫描结果文件：{1}",
                "No se pudo limpiar el archivo de resultados del análisis en segundo plano: {1}")
        catalog.Set(
            "无法生成监控项快照：{1}",
                "No se pudo crear la instantánea de elementos de supervisión: {1}")
        catalog.Set(
            "日志",
                "Registro")
        catalog.Set(
            "日志文件不存在：{1}",
                "El archivo de registro no existe: {1}")
        catalog.Set("📄 查看批处理输出日志", "📄 Ver registro de salida por lotes")
        catalog.Set("尚未生成批处理输出日志", "Aún no hay un registro de salida por lotes")
        catalog.Set(
            "小助手只有在启动 BAT 或 CMD 项目时才会创建此文件。",
                "Este archivo solo se crea cuando el asistente inicia un elemento BAT o CMD.")
        catalog.Set("日志保存位置：", "Ubicación del registro:")
        catalog.Set("确定", "Aceptar")
        catalog.Set(
            "时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间",
                "La configuración de tiempo no es válida.`n`nVentana de detección de salida: 2-120 segundos`nEspera de estabilidad del archivo: 2-300 segundos`nEspera máxima de actualización: 60-86400 segundos y debe ser mayor que la espera de estabilidad")
        catalog.Set(
            "显式升级维护命令执行异常：{1}",
                "Error al ejecutar la orden explícita de mantenimiento de actualización: {1}")
        catalog.Set(
            "显式升级维护命令未找到监控目标：{1}",
                "La orden explícita de mantenimiento de actualización no encontró el destino supervisado: {1}")
        catalog.Set(
            "显式升级维护命令被忽略，目标未启用升级保护：{1}",
                "Se ignoró la orden explícita de mantenimiento de actualización porque el destino no tiene activada la protección de actualizaciones: {1}")
        catalog.Set(
            "显示主界面",
                "Mostrar la interfaz principal")
        catalog.Set(
            "显示名称：",
                "Nombre mostrado：")
        catalog.Set(
            "暂停守护：{1}",
                "Pausar la supervisión: {1}")
        catalog.Set(
            "暂停或恢复选中项目的守护，不会退出目标`n支持多选；混合状态时逐项反转",
                "Pausar o reanudar la supervisión de los elementos seleccionados sin cerrar los destinos`nAdmite selección múltiple`; si los estados están mezclados, se invierte cada uno")
        catalog.Set(
            "暂时无法查询进程状态，稍后重试手动重启：{1}",
                "No se puede consultar temporalmente el estado del proceso`; el reinicio manual se reintentará más tarde: {1}")
        catalog.Set(
            "暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                "No se pueden comprobar temporalmente los procesos existentes`; se retrasa el inicio para evitar instancias duplicadas: {1}")
        catalog.Set(
            "暂时无法重新启动",
                "No se puede reiniciar temporalmente")
        catalog.Set(
            "更新助手已启动，小助手即将退出并完成更新。",
                "El asistente de actualización se ha iniciado. El asistente se cerrará para completar la actualización.")
        catalog.Set(
            "更新应用搜索结果失败：{1}",
                "No se pudieron actualizar los resultados de búsqueda de aplicaciones: {1}")
        catalog.Set(
            "更新检查未返回结果",
                "La búsqueda de actualizaciones no devolvió ningún resultado")
        catalog.Set(
            "更新检查正在进行，请稍候。",
                "Hay una búsqueda de actualizaciones en curso. Espere.")
        catalog.Set(
            "更新检查返回了无法识别的状态：{1}",
                "La búsqueda de actualizaciones devolvió un estado desconocido: {1}")
        catalog.Set(
            "最长升级等待（秒）：",
                "Espera máxima de actualización（segundos）：")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），恢复普通重启流程：{3}",
                "No se detectó actividad de actualización（{1}, {2} segundos）`; se reanuda el proceso normal de reinicio: {3}")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），目标仍不存在：{3}",
                "No se detectó actividad de actualización（{1}, {2} segundos） y el destino sigue sin existir: {3}")
        catalog.Set(
            "未找到目标",
                "No se encontró el destino")
        catalog.Set(
            "未添加",
                "No añadido")
        catalog.Set(
            "未知升级保护阶段",
                "Fase de protección de actualizaciones desconocida")
        catalog.Set(
            "未知守护阶段",
                "Fase de supervisión desconocida")
        catalog.Set(
            "未知版本",
                "Versión desconocida")
        catalog.Set(
            "未知解析错误",
                "Error de análisis desconocido")
        catalog.Set(
            "未知错误",
                "Error desconocido")
        catalog.Set(
            "查看实时运行日志`n涵盖监控、重启、升级保护与操作记录",
                "Ver el registro de ejecución en tiempo real`nIncluye eventos de supervisión, reinicio, protección de actualizaciones y operaciones")
        catalog.Set(
            "查看支持类型、操作方法、守护设置`n以及升级保护说明",
                "Ver los tipos compatibles, el modo de uso y la configuración de supervisión`nIncluye instrucciones sobre la protección de actualizaciones")
        catalog.Set(
            "核心守护",
                "Supervisión principal")
        catalog.Set(
            "核心守护计时器启动失败。",
                "No se pudo iniciar el temporizador de supervisión principal.")
        catalog.Set(
            "桌面与开始菜单快捷方式",
                "Accesos directos del escritorio y del menú Inicio")
        catalog.Set(
            "创建桌面快捷方式，并将小助手加入开始菜单“所有”列表；是否固定到开始菜单由您决定。",
                "Crea un acceso directo en el escritorio y añade el asistente a la lista Todas las aplicaciones del menú Inicio. Tú decides si quieres anclarlo a Inicio.")
        catalog.Set(
            "创建成功！",
                "¡Creados!")
        catalog.Set(
            "检查小助手更新",
                "Buscar actualizaciones del asistente")
        catalog.Set(
            "检查小助手更新失败：{1}",
                "No se pudieron buscar actualizaciones del asistente: {1}")
        catalog.Set(
            "检查更新",
                "Buscar actualizaciones")
        catalog.Set(
            "立即检查更新",
                "Buscar actualizaciones ahora")
        catalog.Set(
            "检查更新失败：{1}",
                "No se pudieron buscar actualizaciones: {1}")
        catalog.Set(
            "检查更新超时",
                "Se agotó el tiempo para buscar actualizaciones")
        catalog.Set(
            "检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。",
                "Se detectó una tarea programada con el mismo nombre, pero no fue creada por este programa. Para evitar borrarla por error, gestiónela primero en el Programador de tareas.")
        catalog.Set(
            "检测到安装目录变化",
                "Se detectó un cambio en el directorio de instalación")
        catalog.Set(
            "检测到相关安装进程",
                "Se detectó un proceso de instalación relacionado")
        catalog.Set(
            "检测到程序文件变化",
                "Se detectó un cambio en los archivos del programa")
        catalog.Set(
            "检测到运行中的目标未使用管理员权限：{1}",
                "El destino en ejecución no usa permisos de administrador: {1}")
        catalog.Set(
            "检测到进程停止，准备重启：{1}（将在 {2} 秒后启动）",
                "Se detectó que el proceso se detuvo`; preparando el reinicio: {1}（se iniciará dentro de {2} segundos）")
        catalog.Set(
            "正在扫描...",
                "Analizando...")
        catalog.Set(
            "正在扫描文件夹，可点击取消停止",
                "Analizando la carpeta`; haga clic en Cancelar para detener")
        catalog.Set(
            "正在扫描：{1}",
                "Analizando: {1}")
        catalog.Set(
            "正在添加扫描结果...",
                "Añadiendo los resultados del análisis...")
        catalog.Set(
            "正在添加：{1} / {2}",
                "Añadiendo: {1} / {2}")
        catalog.Set(
            "正常关闭超时后允许强制终止",
                "Permitir la finalización forzada si se agota el tiempo de cierre normal")
        catalog.Set(
            "正常关闭超时，已强制终止进程 PID：{1}",
                "Se agotó el tiempo de cierre normal`; se forzó la finalización del proceso con PID: {1}")
        catalog.Set(
            "正常关闭超时，已按设置跳过强制终止 PID：{1}",
                "Se agotó el tiempo de cierre normal`; según la configuración, no se forzó la finalización del PID: {1}")
        catalog.Set(
            "没有可安装的应用更新",
                "No hay ninguna actualización de la aplicación para instalar")
        catalog.Set(
            "浏览",
                "Examinar")
        catalog.Set(
            "添加扫描结果失败",
                "No se pudieron añadir los resultados del análisis")
        catalog.Set(
            "添加监控项",
                "Añadir elemento de supervisión")
        catalog.Set(
            "添加监控项失败，已回滚内存状态：{1}",
                "No se pudo añadir el elemento de supervisión`; se ha revertido el estado en memoria: {1}")
        catalog.Set(
            "添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放",
                "Añadir un programa, script o acceso directo`nAdmite búsqueda, importación de carpetas por lotes y arrastrar archivos")
        catalog.Set(
            "清除记录",
                "Borrar registros")
        catalog.Set(
            "状态",
                "Estado")
        catalog.Set(
            "独立环境配置 💡`n",
                "Configuración de entorno independiente 💡`n")
        catalog.Set(
            "环境变量",
                "Variables de entorno")
        catalog.Set(
            "环境变量（每行一个 KEY=VALUE）：",
                "Variables de entorno（una por línea como KEY=VALUE）：")
        catalog.Set(
            "用户指定",
                "Especificado por el usuario")
        catalog.Set(
            "用户结束了升级等待，重新执行安全启动检查：{1}",
                "El usuario finalizó la espera de actualización`; repitiendo la comprobación de inicio seguro: {1}")
        catalog.Set(
            "界面语言和字体已即时更新，无需重新启动小助手。",
                "El idioma y la fuente de la interfaz se actualizaron de inmediato; no es necesario reiniciar el asistente.")
        catalog.Set(
            "更新配置注释语言失败：{1}",
                "No se pudo actualizar el idioma de los comentarios de configuración: {1}")
        catalog.Set(
            "；恢复配置失败：{1}",
                "; tampoco se pudo restaurar la configuración: {1}")
        catalog.Set(
            "界面显示设置无法即时应用，已恢复原语言和字体：{1}",
                "No se pudo aplicar de inmediato la configuración de pantalla. Se restauraron el idioma y la fuente anteriores: {1}")
        catalog.Set(
            "无法即时切换界面语言或字体，原显示设置已恢复。`n`n{1}",
                "No se pudo cambiar de inmediato el idioma o la fuente de la interfaz. Se restauró la configuración de pantalla anterior.`n`n{1}")
        catalog.Set(
            "显示设置应用失败",
                "No se pudo aplicar la configuración de pantalla")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Usar la fuente predeterminada del idioma（{1}）")
        catalog.Set(
            "正在检查更新…",
                "Buscando actualizaciones…")
        catalog.Set(
            "`; UiFont：界面字体；auto 表示使用当前语言的默认字体，也可填写本机已安装字体名称。",
                "`; UiFont: fuente de la interfaz. auto usa la fuente predeterminada del idioma actual`; también puede indicarse el nombre de una fuente instalada.")
        catalog.Set(
            "界面语言：",
                "Idioma de la interfaz：")
        catalog.Set(
            "界面资源",
                "Recursos de la interfaz")
        catalog.Set(
            "监控与启动",
                "Supervisión e inicio")
        catalog.Set(
            "监控目标重复",
                "Destino de supervisión duplicado")
        catalog.Set(
            "监控配置加载异常",
                "Error al cargar la configuración de supervisión")
        catalog.Set(
            "监控配置加载异常：共 {1} 条记录未能载入。",
                "Error al cargar la configuración de supervisión: no se pudieron cargar {1} registros.")
        catalog.Set(
            "监控配置尚未保存，请查看运行日志。",
                "La configuración de supervisión aún no se ha guardado. Consulte el registro de ejecución.")
        catalog.Set(
            "监控项保存状态无效",
                "El estado de guardado del elemento de supervisión no es válido")
        catalog.Set(
            "监控项注册回调无效",
                "La devolución de llamada de registro del elemento de supervisión no es válida")
        catalog.Set(
            "监控项路径无效：{1}",
                "La ruta del elemento de supervisión no es válida: {1}")
        catalog.Set(
            "监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核：{1}",
                "Se detectó que el archivo de destino ya no existe. La supervisión ha pasado al estado de archivo ausente y volverá a comprobarlo automáticamente cuando reaparezca: {1}")
        catalog.Set(
            "目标任务需要 WatchdogScheduler",
                "La tarea de destino requiere WatchdogScheduler")
        catalog.Set(
            "目标文件已恢复，重新核对运行状态：{1}",
                "El archivo de destino ha reaparecido`; comprobando de nuevo el estado de ejecución: {1}")
        catalog.Set(
            "目标文件缺失时检测到升级活动",
                "Se detectó actividad de actualización mientras faltaba el archivo de destino")
        catalog.Set(
            "目标程序文件不存在",
                "El archivo del programa de destino no existe")
        catalog.Set(
            "目标程序：{1}",
                "Programa de destino: {1}")
        catalog.Set(
            "目标路径",
                "Ruta de destino")
        catalog.Set(
            "目标退出时检测到升级信号",
                "Se detectó una señal de actualización al salir el destino")
        catalog.Set(
            "真实目标来源标记",
                "Marca del origen del destino real")
        catalog.Set(
            "真实进程路径无效",
                "La ruta del proceso real no es válida")
        catalog.Set(
            "确 定",
                "Aceptar")
        catalog.Set(
            "程序文件刚刚发生变化",
                "El archivo del programa acaba de cambiar")
        catalog.Set(
            "程序文件尚未达到稳定等待时间",
                "El archivo del programa aún no ha alcanzado el tiempo de espera de estabilidad")
        catalog.Set(
            "程序文件正在写入或结构不完整",
                "Se está escribiendo el archivo del programa o su estructura está incompleta")
        catalog.Set(
            "稍后",
                "Más tarde")
        catalog.Set(
            "窗口层级平台适配器无效",
                "El adaptador de plataforma de jerarquía de ventanas no es válido")
        catalog.Set(
            "窗口层级管理器无效",
                "El administrador de jerarquía de ventanas no es válido")
        catalog.Set(
            "窗口布局字段不是整数：{1}",
                "El campo de disposición de ventana no es un entero: {1}")
        catalog.Set(
            "窗口布局字段超出范围：{1}",
                "El campo de disposición de ventana está fuera del intervalo: {1}")
        catalog.Set(
            "窗口布局对象无效",
                "El objeto de disposición de ventana no es válido")
        catalog.Set(
            "立即更新",
                "Actualizar ahora")
        catalog.Set(
            "等待 {1} 秒后进行第 {2} 次尝试...",
                "Espere {1} segundos antes del intento {2}...")
        catalog.Set(
            "管理员运行状态",
                "Estado de ejecución como administrador")
        catalog.Set(
            "系统 PowerShell 不可用",
                "PowerShell del sistema no está disponible")
        catalog.Set(
            "系统压缩工具未能创建诊断包",
                "La herramienta de compresión del sistema no pudo crear el paquete de diagnóstico")
        catalog.Set(
            "系统权限拦截",
                "Bloqueado por los permisos del sistema")
        catalog.Set(
            "通用",
                "General")
        catalog.Set(
            "结束升级等待并恢复守护",
                "Finalizar la espera de actualización y reanudar la supervisión")
        catalog.Set(
            "编码损坏",
                "Codificación dañada")
        catalog.Set(
            "缺少窗口布局字段：{1}",
                "Falta un campo de disposición de ventana: {1}")
        catalog.Set(
            "缺少窗口生命周期回调：{1}",
                "Falta una devolución de llamada del ciclo de vida de la ventana: {1}")
        catalog.Set(
            "缺少诊断信息提供器：{1}",
                "Falta un proveedor de información de diagnóstico: {1}")
        catalog.Set(
            "缺少运行参数：{1}",
                "Falta un argumento de ejecución: {1}")
        catalog.Set(
            "自动",
                "Automático")
        catalog.Set(
            "自动识别升级并保护启动过程",
                "Detectar actualizaciones automáticamente y proteger el proceso de inicio")
        catalog.Set(
            "自动识别进程",
                "Identificar el proceso automáticamente")
        catalog.Set(
            "自定义名称",
                "Nombre personalizado")
        catalog.Set(
            "自定义图标",
                "Icono personalizado")
        catalog.Set(
            "计划任务冲突",
                "Conflicto de tarea programada")
        catalog.Set(
            "计划任务操作失败：{1}",
                "No se pudo operar la tarea programada: {1}")
        catalog.Set(
            "设置已更新：轮询={1}ms，序列=[{2}]，日志上限={3}",
                "Configuración actualizada: sondeo={1}ms, secuencia=[{2}], límite del registro={3}")
        catalog.Set(
            "设置无效",
                "Configuración no válida")
        catalog.Set(
            "诊断临时目录已存在",
                "El directorio temporal de diagnóstico ya existe")
        catalog.Set(
            "诊断包保存目录不存在",
                "El directorio de destino del paquete de diagnóstico no existe")
        catalog.Set(
            "诊断包已导出到：`n{1}",
                "Paquete de diagnóstico exportado a:`n{1}")
        catalog.Set(
            "诊断包目标文件名已被占用",
                "El nombre de archivo de destino del paquete de diagnóstico ya está en uso")
        catalog.Set(
            "诊断压缩包未生成",
                "No se generó el archivo comprimido de diagnóstico")
        catalog.Set(
            "该文件不是受支持的图标或图片格式。`n`n支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。",
                "Este archivo no tiene un formato de icono o imagen compatible.`n`nSe admiten ICO, EXE, DLL, CPL, LNK, PNG, JPG, JPEG, JPE, JFIF, BMP, GIF, TIF, TIFF, WebP, SVG y ANI.")
        catalog.Set(
            "该目标已存在、无效或指向目录。",
                "Este destino ya existe, no es válido o apunta a un directorio.")
        catalog.Set(
            "该真实进程已由其他监控项守护。",
                "Otro elemento de supervisión ya protege este proceso real.")
        catalog.Set(
            "该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。",
                "Este programa está bajo protección de actualizaciones. Espere a que termine la actualización o finalice la espera desde “Protección de actualizaciones de software” antes de reiniciarlo.")
        catalog.Set(
            "语义版本无效",
                "La versión semántica no es válida")
        catalog.Set(
            "请通过上方按钮搜索或选择，或在下方填写进程名或目标路径：`n【支持程序、脚本、快捷方式，以及文件夹批量导入】",
                "Use los botones superiores para buscar o seleccionar.`nO introduzca abajo el nombre del proceso o la ruta de destino.`n【Programas, scripts, accesos directos e importación de carpetas por lotes】")
        catalog.Set(
            "请选择现有且可执行的真实程序或脚本路径。",
                "Seleccione la ruta existente y ejecutable de un programa o script real.")
        catalog.Set(
            "请选择现有的图标、程序、资源库或快捷方式文件。",
                "Seleccione un archivo existente de icono, programa, biblioteca de recursos o acceso directo.")
        catalog.Set(
            "读取后台扫描结果失败",
                "No se pudieron leer los resultados del análisis en segundo plano")
        catalog.Set(
            "调度器已停止",
                "El programador se ha detenido")
        catalog.Set(
            "跟随系统",
                "Seguir el sistema")
        catalog.Set(
            "路径",
                "Ruta")
        catalog.Set(
            "轮询间隔必须为 500-86400000 毫秒的正整数！",
                "El intervalo de sondeo debe ser un entero positivo entre 500 y 86400000 milisegundos.")
        catalog.Set(
            "软件升级保护",
                "Protección de actualizaciones de software")
        catalog.Set(
            "软件升级保护超过最长等待时间，需要用户确认后恢复：{1}",
                "La protección de actualizaciones de software superó la espera máxima`; se requiere confirmación del usuario para reanudar: {1}")
        catalog.Set(
            "软件升级完成，准备恢复启动：{1}",
                "La actualización de software ha terminado`; preparando la reanudación del inicio: {1}")
        catalog.Set(
            "软件升级完成，已恢复正常守护：{1}",
                "La actualización de software ha terminado`; se ha reanudado la supervisión normal: {1}")
        catalog.Set(
            "载入中...",
                "Cargando...")
        catalog.Set(
            "运行参数不是支持的界面语言：{1}",
                "El argumento de ejecución no es un idioma de interfaz compatible: {1}")
        catalog.Set(
            "运行参数不是整数：{1}",
                "El argumento de ejecución no es un entero: {1}")
        catalog.Set(
            "运行参数不能为空：{1}",
                "El argumento de ejecución no puede estar vacío: {1}")
        catalog.Set(
            "运行参数对象无效",
                "El objeto de argumentos de ejecución no es válido")
        catalog.Set(
            "运行参数超出范围：{1}",
                "El argumento de ejecución está fuera del intervalo: {1}")
        catalog.Set(
            "运行日志",
                "Registro de ejecución")
        catalog.Set(
            "进程仍在运行，忽略重复启动：{1}",
                "El proceso sigue en ejecución`; se ignora el inicio duplicado: {1}")
        catalog.Set(
            "进程启动后迅速退出或未成功常驻后台",
                "El proceso terminó poco después de iniciarse o no consiguió permanecer en segundo plano")
        catalog.Set(
            "进程守护小助手",
                "Asistente de supervisión de procesos")
        catalog.Set(
            "持续守护重要程序与自动化任务，让日常工作稳定运行",
                "Mantén tus aplicaciones y automatizaciones esenciales funcionando de forma estable")
        catalog.Set(
            "进程守护小助手 - 开机自启守护程序",
                "Asistente de supervisión de procesos - Supervisor de inicio automático")
        catalog.Set(
            "进程守护小助手已静默启动。",
                "El Asistente de supervisión de procesos se ha iniciado en modo silencioso.")
        catalog.Set(
            "退出检测窗口（秒）：",
                "Ventana de detección de salida（segundos）：")
        catalog.Set(
            "退出清理异常（{1}）：{2}",
                "Error de limpieza al salir（{1}）: {2}")
        catalog.Set(
            "退出程序",
                "Salir del programa")
        catalog.Set(
            "选择主窗口图标",
                "Seleccionar el icono de la ventana principal")
        catalog.Set(
            "选择工作目录",
                "Seleccionar el directorio de trabajo")
        catalog.Set(
            "选择快捷方式对应的真实进程",
                "Seleccionar el proceso real correspondiente al acceso directo")
        catalog.Set(
            "选择批处理日志目录",
                "Seleccionar el directorio de registros por lotes")
        catalog.Set(
            "选择文件",
                "Seleccionar archivo")
        catalog.Set(
            "选择文件夹",
                "Seleccionar carpeta")
        catalog.Set(
            "选择要监控的文件",
                "Seleccionar el archivo que se va a supervisar")
        catalog.Set(
            "选择要监控的文件夹",
                "Seleccionar la carpeta que se va a supervisar")
        catalog.Set(
            "选择诊断包保存位置",
                "Seleccionar dónde guardar el paquete de diagnóstico")
        catalog.Set(
            "选择软件安装目录",
                "Seleccionar el directorio de instalación del programa")
        catalog.Set(
            "通过拖拽添加了 {1} 个监控项。",
                "Se añadieron {1} elementos de supervisión mediante arrastrar y soltar.")
        catalog.Set(
            "配置仓储无效",
                "El repositorio de configuración no es válido")
        catalog.Set(
            "配置写入器无效",
                "El escritor de configuración no es válido")
        catalog.Set(
            "配置文件写入事务正在进行",
                "Hay una transacción de escritura del archivo de configuración en curso")
        catalog.Set(
            "配置通用、监控与启动、停止`n以及日志选项",
                "Configure General, Supervisión e inicio, Detención`ny Registro")
        catalog.Set(
            "重新加载",
                "Recargar")
        catalog.Set(
            "重新加载失败",
                "No se pudo recargar")
        catalog.Set(
            "重新加载失败，已保留当前实例：{1}",
                "No se pudo recargar`; se ha conservado la instancia actual: {1}")
        catalog.Set(
            "重新加载失败，当前守护仍在运行。`n`n{1}",
                "No se pudo recargar`; la supervisión actual sigue funcionando.`n`n{1}")
        catalog.Set(
            "重试序列不能为空！",
                "La secuencia de reintentos no puede estar vacía.")
        catalog.Set(
            "重试序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "El formato de la secuencia de reintentos no es válido. Debe contener enteros positivos separados por comas（por ejemplo: 1,10,60）, cada uno entre 1 y 86400 segundos.")
        catalog.Set(
            "重试延迟序列不能为空",
                "La secuencia de demora de reintentos no puede estar vacía")
        catalog.Set(
            "重试延迟序列无效",
                "La secuencia de demora de reintentos no es válida")
        catalog.Set(
            "错误",
                "Error")
        catalog.Set(
            "项目名称：{1}`n真实路径：{2}",
                "Nombre del elemento: {1}`nRuta real: {2}")
        catalog.Set(
            "🌿 环境变量：{1} 项`n",
                "🌿 Variables de entorno: {1}`n")
        catalog.Set(
            "🎨 自定义名称和图标",
                "🎨 Personalizar nombre e icono")
        catalog.Set(
            "📁 工作目录：{1}`n",
                "📁 Directorio de trabajo: {1}`n")
        catalog.Set(
            "📂 打开所在位置",
                "📂 Abrir ubicación")
        catalog.Set(
            "📂 浏览文件夹...",
                "📂 Examinar carpetas...")
        catalog.Set(
            "选择...",
                "Seleccionar...")
        catalog.Set(
            "📄 查看运行日志",
                "📄 Ver registro de ejecución")
        catalog.Set(
            "📄 浏览文件...",
                "📄 Examinar archivos...")
        catalog.Set(
            "🔄 反转状态",
                "🔄 Invertir estado")
        catalog.Set(
            "🔄 恢复升级保护状态",
                "🔄 Estado restaurado de protección de actualizaciones")
        catalog.Set(
            "🔄 显式升级维护中",
                "🔄 Mantenimiento explícito de actualización en curso")
        catalog.Set(
            "🔄 检查",
                "🔄 Comprobar")
        catalog.Set(
            "🔄 等待程序文件可用",
                "🔄 Esperando a que el archivo del programa esté disponible")
        catalog.Set(
            "🔄 等待程序文件恢复",
                "🔄 Esperando a que se restaure el archivo del programa")
        catalog.Set(
            "🔄 软件升级中",
                "🔄 Actualización de software en curso")
        catalog.Set(
            "🔄 软件升级保护",
                "🔄 Protección de actualizaciones de software")
        catalog.Set(
            "🔄 重新启动",
                "🔄 Reiniciar")
        catalog.Set(
            "搜索...",
                "Buscar...")
        catalog.Set(
            "搜索：",
                "Buscar：")
        catalog.Set(
            "扩展名",
                "Extensión")
        catalog.Set(
            "🗑️ 删除",
                "🗑️ Eliminar")
        catalog.Set(
            "🚀 正在启动...",
                "🚀 Iniciando...")
        catalog.Set(
            "🛡️ 以管理员身份运行",
                "🛡️ Ejecutar como administrador")
        catalog.Set(
            "（{1}）",
                "（{1}）")
        catalog.Set(
            "（第 {1} 行）",
                "（línea {1}）")
        catalog.Set(
            "（管理员权限）",
                "（permisos de administrador）")
        catalog.Set(
            "：{1}",
                "：{1}")
        catalog.Set(
            "Everything 搜索不可用，请确认 Everything 正在运行。",
                "La búsqueda de Everything no está disponible. Asegúrese de que Everything esté en ejecución.")
        catalog.Set(
            "正在载入 Everything 搜索结果：{1}／{2}",
                "Cargando resultados de búsqueda de Everything: {1}/{2}")
        catalog.Set(
            "Everything 搜索结果：{1} 项",
                "Resultados de búsqueda de Everything: {1}")
        catalog.Set("{1}（EXE 版）", "{1}（versión EXE）")
        catalog.Set("{1}（源码版）", "{1}（versión de código fuente）")
        catalog.Set("• “关于”页可控制是否在启动时后台检查新版，也可随时手动检查。检查过程不会阻塞主界面。", "• La página «Acerca de» permite buscar nuevas versiones en segundo plano al iniciar o iniciar una búsqueda manual en cualquier momento. La comprobación no bloquea la ventana principal.")
        catalog.Set("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• «Reiniciar» solicita primero al destino que se cierre normalmente. Si vence el tiempo de espera, la opción de «Política de detención» determina si se fuerza su cierre.")
        catalog.Set("• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。", "• Acerca de: consulta la versión de la aplicación y el entorno de ejecución de AutoHotkey, busca actualizaciones manualmente o abre el proyecto de código abierto.")
        catalog.Set("• 监控与启动：设置进程状态检查间隔、崩溃自动重启延迟序列，以及导入文件夹时是否包含子目录。", "• Supervisión e inicio: configura el intervalo de comprobación de procesos, la secuencia de demoras del reinicio automático tras un fallo y si se incluyen las subcarpetas al importar una carpeta.")
        catalog.Set("• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。", "• Cuando detecta que un destino se ha detenido, el asistente confirma su estado y vuelve a intentarlo según la «Secuencia de demoras del reinicio automático tras un fallo». Si los fallos continúan, usa las demoras siguientes para evitar reinicios demasiado frecuentes.")
        catalog.Set("• 界面语言和内容字体保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Al guardar el idioma de la interfaz o la fuente del contenido, la ventana principal, los menús y la bandeja se actualizan de inmediato sin reiniciar.")
        catalog.Set("• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。", "• Registros: configura el límite de visualización del registro de ejecución, la ruta y los días de conservación de los registros de salida por lotes y su limpieza al iniciar.")
        catalog.Set("• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。", "• Política de detención: configura el tiempo de espera al cerrar aplicaciones GUI y CLI y si se permite forzar su cierre cuando se agota el cierre normal.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时是否显示主窗口，以及界面语言和内容字体。", "• General: crea accesos directos en el escritorio y el menú Inicio, activa o desactiva el inicio mediante una tarea programada, elige si se muestra la ventana principal al iniciar y configura el idioma y la fuente del contenido de la interfaz.")
        catalog.Set("• 小助手版本与 AutoHotkey 版本彼此独立；“关于”页会分别显示当前小助手版本、运行形态和实际运行时版本。", "• Las versiones del asistente y de AutoHotkey son independientes. La página «Acerca de» muestra por separado la versión actual del asistente, el tipo de distribución y la versión real del entorno de ejecución.")
        catalog.Set("CLI 程序关闭超时（秒）：", "Tiempo de espera al cerrar aplicaciones CLI（segundos）:")
        catalog.Set("GUI 程序关闭超时（秒）：", "Tiempo de espera al cerrar aplicaciones GUI（segundos）:")
        catalog.Set("崩溃自动重启延迟序列（秒）：", "Demoras del reinicio automático tras un fallo（segundos）:")
        catalog.Set("崩溃自动重启延迟序列不能为空！", "La secuencia de demoras del reinicio automático tras un fallo no puede estar vacía.")
        catalog.Set("崩溃自动重启延迟序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。", "La secuencia de demoras del reinicio automático tras un fallo no es válida. Introduce enteros positivos separados por comas（por ejemplo: 1,10,60）, cada uno entre 1 y 86400 segundos.")
        catalog.Set("当前版本：", "Versión actual:")
        catalog.Set("导入文件夹时包含子目录", "Incluir subcarpetas al importar una carpeta")
        catalog.Set("开源地址", "Proyecto de código abierto")
        catalog.Set("关于", "Acerca de")
        catalog.Set("界面内容字体：", "Fuente del contenido de la interfaz:")
        catalog.Set("进程状态检查间隔（毫秒）：", "Intervalo de comprobación de procesos（milisegundos）:")
        catalog.Set("进程状态检查间隔必须为 500-86400000 毫秒的正整数！", "El intervalo de comprobación de procesos debe ser un entero positivo entre 500 y 86400000 milisegundos.")
        catalog.Set("扩展设置包含无效数值。`n`nGUI 程序关闭超时：1-300 秒`nCLI 程序关闭超时：1-60 秒`n运行日志显示上限：50-10000 条`n批处理日志保留天数：1-3650 天", "Hay valores no válidos en la configuración avanzada.`n`nTiempo de espera al cerrar aplicaciones GUI: 1-300 segundos`nTiempo de espera al cerrar aplicaciones CLI: 1-60 segundos`nLímite de visualización del registro de ejecución: 50-10000 entradas`nConservación de registros de salida por lotes: 1-3650 días")
        catalog.Set("配置通用、监控与启动、停止策略、日志`n以及关于选项", "Configura General, Supervisión e inicio, Política de detención,`nRegistros y Acerca de")
        catalog.Set("批处理日志保存路径：", "Ruta de los registros de salida por lotes:")
        catalog.Set("批处理日志保留天数：", "Días de conservación de los registros de salida por lotes:")
        catalog.Set("启动时显示主窗口", "Mostrar la ventana principal al iniciar")
        catalog.Set("设置已更新：进程检查间隔={1}ms，重启延迟序列=[{2}]，日志显示上限={3}", "Configuración actualizada: intervalo de procesos={1} ms, secuencia de demoras de reinicio=[{2}], límite de visualización del registro={3}")
        catalog.Set("停止策略", "Política de detención")
        catalog.Set("运行环境：", "Entorno de ejecución:")
        catalog.Set("运行日志显示上限（条）：", "Límite de visualización del registro de ejecución（entradas）:")
        catalog.Set("; Theme：界面主题；auto 表示跟随 Windows 系统，light 表示浅色，dark 表示深色。", "; Theme: tema de la interfaz`; auto sigue la configuración de Windows, light usa el tema claro y dark usa el tema oscuro.")
        catalog.Set("主题：", "Tema:")
        catalog.Set("浅色", "Claro")
        catalog.Set("深色", "Oscuro")
        catalog.Set("运行参数不是支持的界面主题：{1}", "El ajuste de ejecución no especifica un tema de interfaz compatible: {1}")
        catalog.Set("界面显示设置无法即时应用，已恢复原语言、字体和主题：{1}", "No se pudieron aplicar de inmediato los ajustes de visualización; se restauraron el idioma, la fuente y el tema anteriores: {1}")
        catalog.Set("无法即时切换界面语言、字体或主题，原显示设置已恢复。`n`n{1}", "No se pudo cambiar de inmediato el idioma, la fuente o el tema de la interfaz. Se restauraron los ajustes de visualización anteriores.`n`n{1}")
        catalog.Set("界面语言、字体和主题已即时更新，无需重新启动小助手。", "El idioma, la fuente y el tema de la interfaz se actualizaron de inmediato; no es necesario reiniciar el asistente.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。", "• General: crea accesos directos en el escritorio y el menú Inicio, activa o desactiva el inicio mediante una tarea programada, configura la ventana principal y la búsqueda de actualizaciones al iniciar, y elige el idioma, la fuente del contenido y el tema.")
        catalog.Set("• 界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Al guardar el idioma, la fuente del contenido o el tema, la ventana principal, los menús y la bandeja se actualizan de inmediato sin reiniciar.")
        catalog.Set("打开帮助信息`n可选择查看使用说明、运行日志或提交反馈", "Abrir Ayuda`nElige la guía de uso, el registro de ejecución o el envío de comentarios")
        catalog.Set("支持开源项目`n可使用微信支付或支付宝扫码捐赠", "Apoya el proyecto de código abierto`nDona con WeChat Pay o Alipay")
        catalog.Set("帮助信息", "Ayuda")
        catalog.Set("提交反馈", "Enviar comentarios")
        catalog.Set("支持开源项目", "Apoyar el proyecto de código abierto")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n进程守护小助手持续保持开源，项目的长期维护有赖于您的支持和鼓励~", "Si el asistente le ha ahorrado tiempo al diagnosticar problemas y restablecer programas, puede apoyar al autor mediante los códigos QR de abajo.`nProcess Watchdog seguirá siendo de código abierto, y su mantenimiento a largo plazo depende de su apoyo y ánimo.")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "No se encontró la imagen del código QR")
        catalog.Set("• 主界面的“帮助信息”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。", "• Abre Ayuda en la ventana principal para consultar la guía de uso, el registro de esta sesión o la página de comentarios del proyecto. El registro incluye supervisión, reinicios, protección de actualizaciones y acciones del usuario, y se actualiza automáticamente.")
        catalog.Set("⚙️ 进程识别与启动设置", "⚙️ Identificación del proceso y configuración de inicio")
        catalog.Set("进程识别与启动设置", "Identificación del proceso y configuración de inicio")
        catalog.Set("进程识别", "Identificación del proceso")
        catalog.Set("启动环境", "Entorno de inicio")
        catalog.Set("快捷方式仍用于启动；真实进程用于判断程序是否正在运行。", "El acceso directo sigue siendo el punto de inicio; el proceso real se usa para saber si la aplicación está en ejecución.")
        catalog.Set("该项目直接启动并监控同一个目标，无需额外识别真实进程。", "Este elemento inicia y supervisa directamente el mismo destino, por lo que no necesita identificar otro proceso real.")
        catalog.Set("用于判断运行状态的真实进程：", "Proceso real usado para comprobar el estado:")
        catalog.Set("用于判断运行状态的目标：", "Destino usado para comprobar el estado:")
        catalog.Set("重新识别", "Identificar de nuevo")
        catalog.Set("选择程序", "Elegir programa")
        catalog.Set("识别依据：{1}", "Origen de la identificación: {1}")
        catalog.Set("识别依据：暂无可靠结果", "Origen de la identificación: no hay un resultado fiable")
        catalog.Set("识别状态：路径有效。", "Estado de identificación: la ruta es válida.")
        catalog.Set("识别状态：路径暂时不可用，已保留上次可靠结果。", "Estado de identificación: la ruta no está disponible temporalmente; se ha conservado el último resultado fiable.")
        catalog.Set("识别状态：路径暂时不可用，将保留此身份等待恢复。", "Estado de identificación: la ruta no está disponible temporalmente; se conservará esta identidad mientras se espera su recuperación.")
        catalog.Set("识别状态：未找到可靠目标，请改为手动指定。", "Estado de identificación: no se encontró un destino fiable. Especifíquelo manualmente.")
        catalog.Set("识别状态：手动指定，保存时将验证路径。", "Estado de identificación: especificado manualmente; la ruta se validará al guardar.")
        catalog.Set("识别状态：启动入口与监控目标一致。", "Estado de identificación: el punto de inicio y el destino supervisado son el mismo.")
        catalog.Set("这些设置仅在小助手下次启动目标时生效，不会重启当前进程。", "Estos ajustes se aplicarán la próxima vez que el asistente inicie el destino y no reiniciarán el proceso que ya está en ejecución.")
        catalog.Set("留空时使用快捷方式工作目录或程序所在目录。", "Déjelo en blanco para usar la carpeta de trabajo del acceso directo o la carpeta del programa.")
        catalog.Set("留空时不附加额外参数。", "Déjelo en blanco para no añadir argumentos.")
        catalog.Set("留空时继承小助手当前环境。", "Déjelo en blanco para heredar el entorno actual del asistente.")
        catalog.Set("工作目录不存在或不可访问：{1}", "La carpeta de trabajo no existe o no es accesible: {1}")
        catalog.Set("工作目录无效", "Carpeta de trabajo no válida")
        catalog.Set("环境变量第 {1} 行缺少等号（KEY=VALUE）。", "A la línea {1} de las variables de entorno le falta el signo igual（KEY=VALUE）.")
        catalog.Set("环境变量第 {1} 行的名称无效：{2}", "La línea {1} de las variables de entorno contiene un nombre no válido: {2}")
        catalog.Set("环境变量第 {1} 行重复定义了 {2}。", "La línea {1} de las variables de entorno vuelve a definir {2}.")
        catalog.Set("环境变量配置无法解析。", "No se pudo interpretar la configuración de variables de entorno.")
        catalog.Set("环境变量配置无效", "Variables de entorno no válidas")
        catalog.Set("设置已应用到当前运行，但暂未写入配置文件；小助手将在后台自动重试。", "Los ajustes ya están activos en esta sesión, pero aún no se han escrito en el archivo de configuración. El asistente volverá a intentarlo automáticamente en segundo plano.")
        catalog.Set("配置暂未写入", "Configuración aún no escrita")
        catalog.Set("已更新进程识别与启动设置：{1}", "Se actualizaron la identificación del proceso y la configuración de inicio: {1}")
        catalog.Set("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。", "• Accesos directos: LNK, URL y APPREF-MS, incluidos los accesos directos MSI cuyo destino real pueda resolverse. En accesos especiales, especifique manualmente el proceso real en Identificación del proceso y configuración de inicio.")
        catalog.Set("• 右键项目可自定义主窗口名称和图标，也可打开所在位置、重新启动、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。要求管理员运行但当前权限不符时会显示警告；右键重新启动会按该设置提权启动。", "• Haga clic con el botón derecho en un elemento para personalizar su nombre e icono en la ventana principal, abrir su ubicación, reiniciarlo, editar su ruta, alternar el inicio como administrador, configurar la identificación del proceso, el inicio y la protección de actualizaciones, o ver el registro de salida de archivos por lotes. Si se exige ejecución como administrador pero el proceso actual no tiene permisos suficientes, se mostrará una advertencia; al reiniciarlo desde el menú contextual, se iniciará con elevación según ese ajuste.")
        catalog.Set("添加", "Añadir")
        catalog.Set("暂停", "Pausar")
        catalog.Set("恢复", "Reanudar")
        catalog.Set("删除", "Eliminar")
        catalog.Set("设置", "Configuración")
        catalog.Set("捐赠", "Donar")
        catalog.Set("保存", "Guardar")
        catalog.Set("取消", "Cancelar")
        catalog.Set("反转状态", "Invertir estado")
        catalog.Set("统计：运行", "En ejecución")
        catalog.Set("统计：停止", "Detenidos")
        catalog.Set("统计：恢复", "Recuperando")
        catalog.Set("统计：升级", "Actualizando")
        catalog.Set("统计：暂停", "En pausa")
        catalog.Set("统计：失效", "No válidos")
        catalog.Set("统计：总计", "Total")
        catalog.Set("配置未保存", "Configuración sin guardar")
        catalog.Set("创建", "Crear")
        catalog.Set("开启", "Activar")
        catalog.Set("关闭", "Desactivar")
        catalog.Set("切换", "Cambiar")
        catalog.Set("冲突", "Conflicto")
        catalog.Set("浏览", "Examinar")
        catalog.Set("监控配置", "Configuración de supervisión")
        catalog.Set("管理员运行状态", "Ejecución como administrador")
        catalog.Set("调整守护顺序", "Reordenar la lista de supervisión")
        catalog.Set("编辑完整路径", "Editar ruta completa")
        catalog.Set("自定义名称和图标", "Personalizar nombre e icono")
        catalog.Set("已撤销：{1}", "Deshecho: {1}")
        catalog.Set("已重做：{1}", "Rehecho: {1}")
        return catalog
    }
}

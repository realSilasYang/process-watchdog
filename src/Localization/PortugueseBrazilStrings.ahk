; pt-BR 本地化词条目录。
; 本目录由模型直接依据简体中文稳定键逐条翻译；生成步骤仅处理转义与格式。

class PortugueseBrazilStrings {
    static Create() {
        catalog := Map()
        catalog.CaseSense := "On"
        catalog.Set("按下", "Pressionar")
        catalog.Set(
            "`n位置：{1}",
                "`nLocal: {1}")
        catalog.Set(
            "`r`n      影响：该守护对象本次未加入守护列表。",
                "`r`n      Impacto: este item não foi adicionado à lista de monitoramento.")
        catalog.Set(
            "`r`n      目标：{1}",
                "`r`n      Destino: {1}")
        catalog.Set(
            "`r`n      问题：{1}：{2}",
                "`r`n      Problema: {1}: {2}")
        catalog.Set(
            "`r`n  [{1}] 位置：[{2}] {3}",
                "`r`n  [{1}] Local: [{2}] {3}")
        catalog.Set(
            "`r`n  处理建议：确认目标路径后，可在主界面重新添加该守护对象；也可退出小助手后检查上述配置位置。后续保存配置时，损坏记录会转存到 [Recovery]，不会被静默删除。",
                "`r`n  Ação recomendada: confirme o caminho de destino e adicione o item novamente pela janela principal. Você também pode sair do assistente e verificar o local da configuração indicado acima. Na próxima vez que a configuração for salva, os registros corrompidos serão movidos para [Recovery] e não serão excluídos sem aviso.")
        catalog.Set(
            "`r`n  配置文件：{1}",
                "`r`n  Arquivo de configuração: {1}")
        catalog.Set(
            "   ⚠️ 配置未保存",
                "   ⚠️ Configuração não salva")
        catalog.Set(
            "  --maintenance-begin `"目标完整路径`"    开始维护",
                "  --maintenance-begin `"caminho completo do destino`"    Iniciar manutenção")
        catalog.Set(
            "  --maintenance-end `"目标完整路径`"      结束维护",
                "  --maintenance-end `"caminho completo do destino`"      Encerrar manutenção")
        catalog.Set(
            " 已保留并保存此前添加的 {1} 个守护对象。",
                " Os {1} itens de monitoramento adicionados anteriormente foram mantidos e salvos.")
        catalog.Set(
            " 扫描达到时间或数量上限，结果已截断。",
                " A verificação atingiu o limite de tempo ou de resultados`; os resultados foram truncados.")
        catalog.Set(
            "`; AllowForceTerminate：正常退出超时后是否允许强制结束进程。",
                "`; AllowForceTerminate: define se o processo pode ser encerrado à força após o tempo limite da saída normal.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应，值为软件升级保护的 <HEX> 编码结构。",
                "`; Cada AppN corresponde ao item de mesmo nome em [Apps]`; seu valor contém a estrutura de proteção de atualizações codificada em <HEX>.")
        catalog.Set(
            "`; AppN 与 [Apps] 中同名的守护对象一一对应；留空时使用目标自身的名称和图标。",
                "`; Cada AppN corresponde ao item de mesmo nome em [Apps]`; itens vazios usam o nome e o ícone do próprio destino.")
        catalog.Set(
            "`; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。",
                "`; CheckInterval: intervalo de verificação de status em milissegundos`; faixa de 500 a 86400000.")
        catalog.Set(
            "`; CheckUpdatesOnStartup：启动后是否在后台检查小助手新版。",
                "`; CheckUpdatesOnStartup: define se uma nova versão do assistente deve ser procurada em segundo plano após a inicialização.")
        catalog.Set(
            "`; ClearLogsOnStartup：启动时是否清空历史日志。",
                "`; ClearLogsOnStartup: define se os logs anteriores devem ser apagados ao iniciar.")
        catalog.Set(
            "`; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col1W: largura da primeira coluna da lista principal, salva em pixels lógicos a 96 DPI.")
        catalog.Set(
            "`; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。",
                "`; Col2W: largura da segunda coluna da lista principal, salva em pixels lógicos a 96 DPI.")
        catalog.Set(
            "`; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。",
                "`; CtrlCWaitSeconds: espera máxima, em segundos, depois que um programa de linha de comando recebe Ctrl+C`; faixa de 1 a 60.")
        catalog.Set(
            "`; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。",
                "`; GracefulStopSeconds: espera máxima, em segundos, para um programa com janela fechar normalmente`; faixa de 1 a 300.")
        catalog.Set(
            "`; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。",
                "`; GuiH: altura da janela principal, salva em pixels lógicos a 96 DPI.")
        catalog.Set(
            "`; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。",
                "`; GuiW: largura da janela principal, salva em pixels lógicos a 96 DPI.")
        catalog.Set(
            "`; LogDirectory：留空时使用系统临时目录下的 ProcessWatchdogLogs。",
                "`; LogDirectory: se ficar em branco, será usada a pasta ProcessWatchdogLogs no diretório temporário do sistema.")
        catalog.Set(
            "`; LogMaxEntries：日志界面保留条数，范围 50～10000。",
                "`; LogMaxEntries: número de entradas mantidas na janela de log`; faixa de 50 a 10000.")
        catalog.Set(
            "`; LogRetentionDays：日志文件保留天数，范围 1～3650。",
                "`; LogRetentionDays: número de dias de retenção dos arquivos de log`; faixa de 1 a 3650.")
        catalog.Set(
            "`; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。",
                "`; RecursiveBatchImport: define se as subpastas serão verificadas durante a importação em lote de uma pasta.")
        catalog.Set(
            "`; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。",
                "`; RetrySequence: tempos de espera para reiniciar, em segundos e separados por vírgulas`; no máximo 10 valores, cada um entre 1 e 86400.")
        catalog.Set(
            "`; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。",
                "`; ShowAfterReload: indicador interno de recarregamento`; volta automaticamente para 0 após a conclusão.")
        catalog.Set(
            "`; ShowAtStartup：启动后是否显示主窗口。",
                "`; ShowAtStartup: define se a janela principal será exibida após a inicialização.")
        catalog.Set(
            "`; UiLanguage：界面语言；auto 表示跟随系统，也可填写受支持的语言代码。",
                "`; UiLanguage: idioma da interface`; auto acompanha o sistema, mas também é possível informar um código de idioma compatível.")
        catalog.Set(
            "`; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。",
                "`; Salva apenas o nome exibido e a origem do ícone na janela principal`; não interfere na identificação do processo, na inicialização nem na proteção de atualizações.")
        catalog.Set(
            "`; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
                "`; Os campos internos incluem Enabled, RootIsCustom, DetectionSeconds, StableSeconds, MaxWaitSeconds, InstallRoot e Actor.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。",
                "`; Valores booleanos usam 1 para ativar e 0 para desativar`; é recomendável alterá-los pela janela de configurações.")
        catalog.Set(
            "`; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。",
                "`; Valores booleanos usam 1 para ativar e 0 para desativar`; o programa codifica e decodifica automaticamente o conteúdo <HEX>.")
        catalog.Set(
            "`; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。",
                "`; É recomendável fazer alterações em “Proteção de atualizações de software” em vez de editar diretamente o conteúdo codificado.")
        catalog.Set(
            "`; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。",
                "`; Registros de monitoramento que não puderem ser interpretados com segurança serão mantidos temporariamente aqui para evitar perdas silenciosas`; normalmente não é preciso alterá-los manualmente.")
        catalog.Set(
            "`; 本区保存运行参数；以分号开头的注释不会参与软件读取。",
                "`; Esta seção armazena os parâmetros de execução`; comentários iniciados por ponto e vírgula não são lidos pelo programa.")
        catalog.Set(
            "`; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
                "`; Formato: status ativado｜executar como administrador｜caminho de destino｜pasta de trabalho｜argumentos de inicialização｜variáveis de ambiente｜destino real do atalho｜indicador de destino manual｜argumentos do atalho.")
        catalog.Set(
            "`; 每个 AppN 对应一个守护对象，九个字段使用竖线分隔。",
                "`; Cada AppN corresponde a um item de monitoramento`; os nove campos são separados por barras verticais.")
        catalog.Set(
            "DPI 变化后刷新图标失败：{1}",
                "Falha ao atualizar o ícone após a alteração de DPI: {1}")
        catalog.Set(
            "DPI 变化后重建图标列表失败：{1}",
                "Falha ao recriar a lista de ícones após a alteração de DPI: {1}")
        catalog.Set(
            "DPI 图标重建回调无效",
                "O retorno de chamada para recriar ícones após alteração de DPI é inválido")
        catalog.Set(
            "{1} 条监控配置未载入，相关守护对象当前不会被守护。点击查看具体位置和原因。",
                "{1} configurações de monitoramento não foram carregadas`; os itens correspondentes não estão sendo monitorados. Clique para ver o local e o motivo.")
        catalog.Set(
            "• Ahk2Exe 只在发布服务器上用于生成 EXE，不随小助手安装，普通用户和源码运行用户都不需要维护它。",
                "• O Ahk2Exe só é usado no servidor de lançamento para gerar o EXE. Ele não é instalado com o assistente, e nem usuários comuns nem quem executa o código-fonte precisam mantê-lo.")
        catalog.Set(
            "• Ctrl+A 全选。Esc 会先取消选择；没有选中项时再按 Esc 会隐藏主窗口。",
                "• Ctrl+A seleciona tudo. Esc primeiro desfaz a seleção`; quando não há item selecionado, pressionar Esc novamente oculta a janela principal.")
        catalog.Set(
            "• EXE 版已内嵌该版本发布时验证通过的 AutoHotkey；更新完整小助手发行包时，内嵌运行时会一同更新，电脑无需另装 AutoHotkey。",
                "• A edição EXE incorpora a versão do AutoHotkey validada no lançamento daquela versão. O ambiente incorporado é atualizado com o pacote completo do assistente, e não é necessário instalar o AutoHotkey no computador.")
        catalog.Set(
            "• EXE 版更新完整编译包；Git 源码版仅在受跟踪文件无修改且可快速前进时更新；其他源码版使用源码发行包。",
                "• A edição EXE atualiza o pacote compilado completo. A edição executada pelo código-fonte em Git só é atualizada se os arquivos rastreados não tiverem alterações e for possível avançar diretamente`; outras instalações pelo código-fonte usam o pacote de código-fonte.")
        catalog.Set(
            "• 主界面的“日志”显示本次运行中的监控、重启、升级保护和操作记录，并会自动更新。",
                "• “Log” na janela principal exibe e atualiza automaticamente os registros de monitoramento, reinicialização, proteção de atualizações e operações da sessão atual.")
        catalog.Set(
            "• 也可将文件或文件夹直接拖放到主列表；已经存在的守护对象不会重复添加。",
                "• Você também pode arrastar arquivos ou pastas diretamente para a lista principal`; itens que já existem não serão adicionados novamente.")
        catalog.Set(
            "• 停止：设置窗口程序和命令行程序的退出等待，以及是否允许强制终止。",
                "• Encerramento: configure o tempo de espera para a saída de programas com janela e de linha de comando, além da permissão para encerrar à força.")
        catalog.Set(
            "• 关闭主窗口后，小助手继续在托盘运行。托盘菜单可重新显示主界面、重新加载或退出程序。",
                "• Ao fechar a janela principal, o assistente continua em execução na bandeja do sistema. O menu da bandeja permite reabrir a interface, recarregar ou sair.")
        catalog.Set(
            "• 升级等待超时或判断不正确时，可选择“结束升级等待并恢复守护”；恢复前仍会检查目标文件是否可以安全启动。",
                "• Se a espera de uma atualização expirar ou a detecção estiver incorreta, escolha “Encerrar a espera da atualização e retomar o monitoramento”`; antes de retomar, ainda será verificado se o destino pode ser iniciado com segurança.")
        catalog.Set(
            "• 单击选择守护对象；按住 Ctrl 或 Shift 可多选；拖动列表行可调整守护顺序。",
                "• Clique para selecionar um item`; mantenha Ctrl ou Shift pressionado para selecionar vários`; arraste as linhas para alterar a ordem de monitoramento.")
        catalog.Set(
            "• 双击守护对象或按 F2 可编辑完整路径。Delete 删除，Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。",
                "• Clique duas vezes em um item ou pressione F2 para editar o caminho completo. Delete exclui, Ctrl+Z desfaz e Ctrl+Shift+Z ou Ctrl+Y refaz.")
        catalog.Set(
            "• 发现新版后会先询问；确认后校验完整发行包，退出当前实例、替换受管文件并自动重启，不会覆盖个人配置和升级保护会话。",
                "• Quando uma nova versão for encontrada, será solicitada confirmação. Em seguida, o pacote completo será validado, a instância atual será fechada, os arquivos gerenciados serão substituídos e o assistente será reiniciado automaticamente, sem sobrescrever configurações pessoais nem sessões de proteção de atualizações.")
        catalog.Set(
            "• 可控的更新脚本可显式发送维护指令：",
                "• Um script de atualização sob seu controle pode enviar comandos explícitos de manutenção:")
        catalog.Set(
            "• 在守护对象右键菜单打开“软件升级保护”，可调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待，也可清除已学习的更新程序特征。",
                "• Abra “Proteção de atualizações de software” no menu de contexto do item para ajustar a pasta de instalação, a janela de detecção de saída, a espera de estabilidade do arquivo e a espera máxima de atualização, ou para apagar as características aprendidas do atualizador.")
        catalog.Set(
            "• 多个守护对象状态一致时，“暂停”按钮会统一暂停或恢复；状态混合时会逐项反转。",
                "• Se todos os itens selecionados tiverem o mesmo status, o botão “Pausar” pausará ou retomará todos juntos`; se os status forem diferentes, cada um será invertido.")
        catalog.Set(
            "• 小助手会核对目标路径或命令行，避免只按进程名称造成误判。",
                "• O assistente compara o caminho ou a linha de comando do destino para evitar identificações incorretas baseadas apenas no nome do processo.")
        catalog.Set(
            "• 小助手版本与 AutoHotkey 版本彼此独立；“通用”页会同时显示当前小助手版本、运行形态和实际运行时版本。",
                "• A versão do assistente e a versão do AutoHotkey são independentes. A página “Geral” mostra a versão atual do assistente, o modo de execução e a versão real do ambiente.")
        catalog.Set(
            "• 程序搜索：仅使用 Everything 服务并显示全部匹配结果；使用前请保持 Everything 正在运行。",
                "• Pesquisa de programas: usa somente o serviço Everything e mostra todos os resultados correspondentes. Antes de pesquisar, mantenha o Everything em execução.")
        catalog.Set(
            "• 日志：设置运行日志内存上限、批处理输出日志的保存目录、保留时间和启动时清理策略。",
                "• Logs: configure o limite de registros de execução na memória, a pasta dos logs de saída em lote, o período de retenção e a limpeza ao iniciar.")
        catalog.Set(
            "• 暂停守护对象会取消它的重试和升级检测；恢复后会重新检查目标状态。",
                "• Pausar um item cancela suas novas tentativas e a detecção de atualizações`; ao retomá-lo, o status do destino será verificado novamente.")
        catalog.Set(
            "• 检测到目标停止后，会先确认状态，再按“重启等待序列”依次重试；连续失败时采用后续等待时间，避免频繁拉起。",
                "• Quando o destino para, o status é confirmado antes de fazer novas tentativas conforme a “Sequência de espera para reiniciar”. Após falhas seguidas, são usados os tempos posteriores para evitar inicializações frequentes.")
        catalog.Set(
            "• 每次正式发布开始时都会重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版（可能为预发布），冻结本次版本后完成全套测试；只有通过才生成发行包。",
                "• No início de cada lançamento oficial, são selecionadas novamente a versão estável mais recente do AutoHotkey e a última versão lançada do Ahk2Exe（que pode ser uma versão de pré-lançamento）. Elas são fixadas para aquele lançamento e passam por todos os testes`; o pacote só é gerado se tudo for aprovado.")
        catalog.Set(
            "• 源码版使用电脑当前安装的 AutoHotkey；小助手更新只更新项目源码，不会安装或升级本机解释器。",
                "• A edição executada pelo código-fonte usa a instalação atual do AutoHotkey no computador. A atualização do assistente atualiza apenas o código do projeto e não instala nem atualiza o interpretador local.")
        catalog.Set(
            "• 点击“添加”，可搜索应用，或选择程序、脚本、快捷方式及文件夹。",
                "• Clique em “Adicionar” para pesquisar um aplicativo ou selecionar programas, scripts, atalhos e pastas.")
        catalog.Set(
            "• 界面语言和字体可在“通用”中手动切换；保存后立即更新主窗口、菜单和托盘，无需重新启动。",
                "• O idioma e a fonte da interface podem ser alterados em “Geral”. Ao salvar, a janela principal, os menus e a bandeja são atualizados imediatamente, sem reiniciar.")
        catalog.Set(
            "• 启动 / 监控：设置状态检查间隔、重启等待序列、启动后是否显示主窗口、是否检查小助手更新，以及文件夹批量导入是否递归。",
                "• Inicialização / Monitoramento: defina o intervalo de verificação, a sequência de espera para reiniciar, se a janela principal será exibida e se haverá busca de atualizações ao iniciar, além da verificação de subpastas na importação em lote.")
        catalog.Set(
            "• 确认升级后会暂缓自动拉起；相关活动结束且目标文件稳定后，会自动恢复守护。真实升级过程中识别到的更新程序特征会自动记录。",
                "• Após confirmar uma atualização, as inicializações automáticas são suspensas. Quando a atividade relacionada termina e o arquivo de destino fica estável, o monitoramento é retomado automaticamente. As características do atualizador encontradas durante uma atualização real são gravadas automaticamente.")
        catalog.Set(
            "• 程序：EXE、COM、MSC。",
                "• Programas: EXE, COM e MSC.")
        catalog.Set(
            "• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，并可立即检查小助手更新。",
                "• Geral: crie atalhos na área de trabalho e no menu Iniciar, ative ou desative a inicialização automática por tarefa agendada e procure imediatamente atualizações do assistente.")
        catalog.Set(
            "• 脚本：AHK、Python、JavaScript、VBScript、PowerShell、批处理，以及 Ruby、Perl、PHP、Lua、JAR、Shell 等。",
                "• Scripts: AHK, Python, JavaScript, VBScript, PowerShell, arquivos em lote, além de Ruby, Perl, PHP, Lua, JAR, Shell e outros.")
        catalog.Set(
            "• 软件升级保护默认关闭。需要时在守护对象右键菜单打开“软件升级保护”，勾选“自动识别升级并保护启动过程”并保存。",
                "• A proteção de atualizações de software fica desativada por padrão. Quando precisar, abra “Proteção de atualizações de software” no menu de contexto, marque “Detectar atualizações automaticamente e proteger o processo de inicialização” e salve.")
        catalog.Set(
            "• 选中守护对象后可暂停、恢复或删除。暂停只停止守护，不会关闭当前正在运行的目标。",
                "• Após selecionar itens, você pode pausar, retomar ou excluir. Pausar interrompe apenas o monitoramento e não fecha os destinos que já estão em execução.")
        catalog.Set(
            "• 选择文件夹会批量导入其中支持的文件；是否扫描子目录由“设置”中的“监控”控制。",
                "• Ao selecionar uma pasta, os arquivos compatíveis nela serão importados em lote. A opção “Monitoramento” em “Configurações” define se as subpastas também serão verificadas.")
        catalog.Set(
            "• 守护对象右键菜单中的“查看运行日志”用于打开 BAT/CMD 目标生成的输出日志；其他类型或尚未生成时会提示文件不存在。",
                "• “Ver log de execução” no menu de contexto abre o log de saída gerado por destinos BAT/CMD. Para outros tipos ou se o log ainda não existir, será informado que o arquivo não foi encontrado.")
        catalog.Set(
            "⏳ 正在结束运行...",
                "⏳ Encerrando o alvo...")
        catalog.Set(
            "⏳ 判断是否正在升级",
                "⏳ Verificando se há uma atualização em andamento")
        catalog.Set(
            "⏳ 升级完成，准备恢复",
                "⏳ Atualização concluída`; preparando a retomada")
        catalog.Set(
            "⏳ 启动倒计时 {1} 秒",
                "⏳ Inicialização em {1} segundos")
        catalog.Set(
            "⏳ 启动失败，稍后自动重试",
                "⏳ Falha ao iniciar`; nova tentativa automática mais tarde")
        catalog.Set(
            "⏳ 确认升级文件稳定",
                "⏳ Confirmando a estabilidade dos arquivos de atualização")
        catalog.Set(
            "⏳ 确认升级文件稳定 {1}s",
                "⏳ Confirmando a estabilidade dos arquivos de atualização {1}s")
        catalog.Set(
            "⏳ 稍后自动重试 {1} 秒",
                "⏳ Nova tentativa automática em {1} segundos")
        catalog.Set(
            "⏳ 等待安全启动条件",
                "⏳ Aguardando condições seguras de inicialização")
        catalog.Set(
            "⏳ 等待进程状态...",
                "⏳ Aguardando o status do processo...")
        catalog.Set(
            "⏳ 重试倒计时 {1} 秒",
                "⏳ Nova tentativa em {1} segundos")
        catalog.Set(
            "⏳ 验证运行状态...",
                "⏳ Verificando o status de execução...")
        catalog.Set(
            "⏸️ 已暂停",
                "⏸️ Pausado")
        catalog.Set(
            "⏸️ 暂停",
                "⏸️ Pausar")
        catalog.Set(
            "▶️ 恢复",
                "▶️ Retomar")
        catalog.Set(
            "⚙️ 启动参数：{1}`n",
                "⚙️ Argumentos de inicialização: {1}`n")
        catalog.Set(
            "⚠️ 升级等待超时",
                "⚠️ Tempo limite da atualização excedido")
        catalog.Set(
            "⚠️ 疑似停止",
                "⚠️ Possivelmente parado")
        catalog.Set(
            "⚠️ 运行中（权限不符）",
                "⚠️ Em execução（permissão incompatível）")
        catalog.Set(
            "✅ 已启动（非驻留目标）",
                "✅ Iniciado（destino não residente）")
        catalog.Set(
            "✅ 运行中",
                "✅ Em execução")
        catalog.Set(
            "✅ 运行：{1}   🚫 停止：{2}   ⏳ 恢复：{3}   🔄 升级：{4}   ⏸️ 暂停：{5}   ❌ 失效：{6}   ｜   🎯 总计：{7}",
                "✅ Em execução: {1}   🚫 Parados: {2}   ⏳ Aguardando: {3}   🔄 Atualizando: {4}   ⏸️ Pausados: {5}   ❌ Inválidos: {6}   ｜   🎯 Total: {7}")
        catalog.Set(
            "✒️ 编辑完整路径（F2）",
                "✒️ Editar o caminho completo（F2）")
        catalog.Set(
            "确 定",
                "Confirmar")
        catalog.Set(
            "取 消",
                "Cancelar")
        catalog.Set(
            "❌ 无法结束运行",
                "❌ Não foi possível encerrar o alvo")
        catalog.Set(
            "❌ 目标不存在",
                "❌ O destino não existe")
        catalog.Set(
            "❌ 程序不存在",
                "❌ O programa não existe")
        catalog.Set(
            "❌ 脚本不存在",
                "❌ O script não existe")
        catalog.Set(
            "➕ 添加",
                "➕ Adicionar")
        catalog.Set(
            "。",
                ".")
        catalog.Set(
            "一、快速上手",
                "1. Início rápido")
        catalog.Set(
            "七、软件升级保护",
                "7. Proteção de atualizações de software")
        catalog.Set(
            "三、主界面操作",
                "3. Operações da janela principal")
        catalog.Set(
            "不允许的升级保护阶段转换：{1}",
                "Transição de etapa da proteção de atualizações não permitida: {1}")
        catalog.Set(
            "不支持的启动规格类型",
                "Tipo de especificação de inicialização não compatível")
        catalog.Set(
            "不支持的图标格式",
                "Formato de ícone não compatível")
        catalog.Set(
            "不是当前 <HEX> 编码格式",
                "O conteúdo não usa o formato de codificação <HEX> atual")
        catalog.Set(
            "与已加载守护对象重复，或目标格式无效",
                "Item duplicado em relação aos já carregados ou formato de destino inválido")
        catalog.Set(
            "主进程监控",
                "Monitoramento do processo principal")
        catalog.Set(
            "主进程监控异常：{1}",
                "Erro no monitoramento do processo principal: {1}")
        catalog.Set(
            "二、支持的守护对象",
                "2. Destinos compatíveis")
        catalog.Set(
            "五、设置",
                "5. Configurações")
        catalog.Set(
            "代码热重载完毕，界面已恢复显示。",
                "O recarregamento dinâmico do código foi concluído e a interface voltou a ser exibida.")
        catalog.Set(
            "仲裁期间捕获到升级活动",
                "Atividade de atualização detectada durante a arbitragem")
        catalog.Set(
            "使用说明",
                "Guia de uso")
        catalog.Set(
            "恢复默认",
                "Restaurar")
        catalog.Set(
            "保存",
                "Salvar")
        catalog.Set(
            "保存升级保护恢复状态失败：{1}",
                "Falha ao salvar o estado de retomada da proteção de atualizações: {1}")
        catalog.Set(
            "保存失败",
                "Falha ao salvar")
        catalog.Set(
            "保存显示设置失败，请查看运行日志。",
                "Não foi possível salvar as configurações de exibição. Consulte o log de execução.")
        catalog.Set(
            "保存监控配置失败：{1}",
                "Falha ao salvar a configuração de monitoramento: {1}")
        catalog.Set(
            "保存窗口布局失败：{1}",
                "Falha ao salvar o layout da janela: {1}")
        catalog.Set(
            "保存设置失败，请查看运行日志。",
                "Não foi possível salvar as configurações. Consulte o log de execução.")
        catalog.Set(
            "保存软件升级保护设置失败，请查看运行日志。",
                "Não foi possível salvar as configurações de proteção de atualizações de software. Consulte o log de execução.")
        catalog.Set(
            "保存运行参数失败：{1}",
                "Falha ao salvar os parâmetros de execução: {1}")
        catalog.Set(
            "值不是 0 或 1",
                "O valor não é 0 nem 1")
        catalog.Set(
            "停止",
                "Encerramento")
        catalog.Set(
            "八、日志与托盘",
                "8. Logs e bandeja do sistema")
        catalog.Set(
            "六、版本与小助手自身更新",
                "6. Versões e atualização do assistente")
        catalog.Set(
            "内容为空",
                "O conteúdo está vazio")
        catalog.Set(
            "内容无法解析",
                "Não foi possível interpretar o conteúdo")
        catalog.Set(
            "创建快捷方式失败：{1}",
                "Falha ao criar o atalho: {1}")
        catalog.Set(
            "初始化...",
                "Inicializando...")
        catalog.Set(
            "删除选中的守护对象（支持多选，可撤销）`n快捷键：Delete",
                "Excluir os itens de monitoramento selecionados（permite seleção múltipla e desfazer）`nTecla: Delete")
        catalog.Set(
            "刷新主窗口状态失败，已暂停界面倒计时刷新：{1}",
                "Falha ao atualizar o status da janela principal`; a atualização da contagem regressiva da interface foi pausada: {1}")
        catalog.Set(
            "刷新运行日志窗口失败，已暂停自动刷新：{1}",
                "Falha ao atualizar a janela de log de execução`; a atualização automática foi pausada: {1}")
        catalog.Set(
            "升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。",
                "A proteção de atualizações só aceita programas ou scripts com um caminho completo válido. A pasta de instalação deve existir e conter o arquivo de destino.")
        catalog.Set(
            "升级保护仍在进行",
                "A proteção de atualizações ainda está ativa")
        catalog.Set(
            "升级保护初始化时无法建立进程基线，将在下一轮重试。",
                "Não foi possível criar a linha de base dos processos durante a inicialização da proteção de atualizações`; uma nova tentativa será feita no próximo ciclo.")
        catalog.Set(
            "升级保护协调器未能初始化，核心守护不会启动。",
                "O coordenador de proteção de atualizações não pôde ser inicializado`; o monitoramento principal não será iniciado.")
        catalog.Set(
            "升级保护配置",
                "Configuração da proteção de atualizações")
        catalog.Set(
            "升级文件监听",
                "Monitoramento dos arquivos de atualização")
        catalog.Set(
            "升级文件监听异常（{1}）：{2}",
                "Erro no monitoramento dos arquivos de atualização（{1}）: {2}")
        catalog.Set(
            "升级文件监听异常：{1}",
                "Erro no monitoramento dos arquivos de atualização: {1}")
        catalog.Set(
            "升级等待已超时",
                "Tempo limite da atualização excedido")
        catalog.Set(
            "升级进程扫描",
                "Verificação dos processos de atualização")
        catalog.Set(
            "升级进程扫描异常：{1}",
                "Erro na verificação dos processos de atualização: {1}")
        catalog.Set(
            "参数错误",
                "Erro de parâmetros")
        catalog.Set(
            "发现小助手新版本：{1}（当前版本：{2}）",
                "Nova versão do assistente disponível: {1}（versão atual: {2}）")
        catalog.Set(
            "发现新版本 {1}，当前版本为 {2}。{3}{3}{4}{3}{3}是否立即更新？",
                "A nova versão {1} está disponível`; a versão atual é {2}.{3}{3}{4}{3}{3}Deseja atualizar agora?")
        catalog.Set(
            "取消",
                "Cancelar")
        catalog.Set(
            "名称",
                "Nome")
        catalog.Set(
            "后台任务耗时较长：{1}，本次 {2} 毫秒",
                "Uma tarefa em segundo plano demorou demais: {1}`; esta execução levou {2} ms")
        catalog.Set(
            "后台扫描进程未返回 PID",
                "O processo de verificação em segundo plano não retornou um PID")
        catalog.Set(
            "后台调度任务异常（{1}）：{2}",
                "Erro em uma tarefa agendada em segundo plano（{1}）: {2}")
        catalog.Set(
            "后台进程快照为空或不完整，已忽略本次结果并安排重试。",
                "O instantâneo de processos em segundo plano está vazio ou incompleto`; o resultado foi ignorado e uma nova tentativa foi agendada.")
        catalog.Set(
            "后台进程快照已确认",
                "Instantâneo de processos em segundo plano confirmado")
        catalog.Set(
            "后台进程快照未及时返回，已等待完整检测窗口",
                "O instantâneo de processos em segundo plano não chegou a tempo`; toda a janela de detecção foi aguardada")
        catalog.Set(
            "启动前没有可用的启动目标，已停止重试：{1}{2}",
                "Não há destino de inicialização disponível antes de iniciar`; as novas tentativas foram interrompidas: {1}{2}")
        catalog.Set(
            "启动参数",
                "Argumentos de inicialização")
        catalog.Set(
            "启动参数（Args）：",
                "Argumentos de inicialização（Args）：")
        catalog.Set(
            "启动器需要 LaunchSpec",
                "O inicializador exige LaunchSpec")
        catalog.Set(
            "启动失败",
                "Falha ao iniciar")
        catalog.Set(
            "启动失败 [{1}/{2}]：{3} - {4}",
                "Falha ao iniciar [{1}/{2}]: {3} - {4}")
        catalog.Set(
            "启动成功且运行稳定：{1}",
                "Inicialização bem-sucedida e execução estável: {1}")
        catalog.Set(
            "启动批量导入失败",
                "Falha ao iniciar a importação em lote")
        catalog.Set(
            "启动时检查小助手更新",
                "Procurar atualizações do assistente ao iniciar")
        catalog.Set(
            "启动时清空批处理日志",
                "Apagar os logs em lote ao iniciar")
        catalog.Set(
            "启动目标不可用",
                "O destino de inicialização não está disponível")
        catalog.Set(
            "启动目标不存在",
                "O destino de inicialização não existe")
        catalog.Set(
            "启用状态",
                "Status de ativação")
        catalog.Set(
            "四、守护与重启",
                "4. Monitoramento e reinicialização")
        catalog.Set(
            "图标来源无效",
                "A origem do ícone é inválida")
        catalog.Set(
            "图标来源：",
                "Origem do ícone：")
        catalog.Set(
            "图标缩放器",
                "Redimensionador de ícones")
        catalog.Set(
            "处理后台进程快照时发生错误：{1}",
                "Erro ao processar o instantâneo de processos em segundo plano: {1}")
        catalog.Set(
            "处理应用更新结果失败：{1}",
                "Falha ao processar o resultado de atualização do aplicativo: {1}")
        catalog.Set(
            "字段数量应为 {1}，实际为 {2}",
                "Eram esperados {1} campos, mas foram encontrados {2}")
        catalog.Set(
            "守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！",
                "As operações de monitoramento exigem permissões elevadas de leitura e gravação no sistema. Execute este programa como administrador.")
        catalog.Set(
            "守护对象：",
                "Alvo monitorado:")
        catalog.Set(
            "安全启动门暂缓启动：{1}（{2}）",
                "A barreira de inicialização segura adiou a inicialização: {1}（{2}）")
        catalog.Set(
            "安装目录特征",
                "Características da pasta de instalação")
        catalog.Set(
            "安装足迹目录：",
                "Pasta de instalação：")
        catalog.Set(
            "完整路径",
                "Caminho completo")
        catalog.Set(
            "完整路径：{1}",
                "Caminho completo: {1}")
        catalog.Set(
            "导出诊断包",
                "Exportar pacote de diagnóstico")
        catalog.Set(
            "导出诊断包失败：{1}",
                "Falha ao exportar o pacote de diagnóstico: {1}")
        catalog.Set(
            "将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。",
                "O pacote completo de distribuição será baixado e validado. Depois que o assistente for fechado, os arquivos do programa serão substituídos e ele será reiniciado automaticamente.")
        catalog.Set(
            "将下载并校验源码发行包，保留个人配置后替换源码并自动重启。",
                "O pacote de código-fonte será baixado e validado. Em seguida, o código será substituído e o assistente será reiniciado automaticamente, preservando suas configurações pessoais.")
        catalog.Set(
            "将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。",
                "Será verificado se o repositório de código-fonte não possui alterações sem commit`; em seguida, ele avançará diretamente até a tag oficial de lançamento e será reiniciado automaticamente.")
        catalog.Set(
            "小助手在后台检查程序、脚本和快捷方式。目标异常退出后，会按设置的等待序列重新启动。关闭主窗口只会隐藏到系统托盘，不会停止守护。",
                "O assistente verifica programas, scripts e atalhos em segundo plano. Quando um destino termina inesperadamente, ele é reiniciado conforme a sequência de espera configurada. Fechar a janela principal apenas a oculta na bandeja do sistema e não interrompe o monitoramento.")
        catalog.Set(
            "小助手已是最新版本：{1}",
                "O assistente já está atualizado: {1}")
        catalog.Set(
            "小助手更新",
                "Atualização do assistente")
        catalog.Set(
            "小助手设置",
                "Configurações do assistente")
        catalog.Set(
            "进程守护小助手更新",
                "Atualização do Assistente de Monitoramento de Processos")
        catalog.Set(
            "进程守护小助手设置",
                "Configurações do Assistente de Monitoramento de Processos")
        catalog.Set(
            "尚未从真实升级过程学习到更新程序特征。",
                "Ainda não foram aprendidas características do atualizador a partir de uma atualização real.")
        catalog.Set(
            "展示配置",
                "Configuração de exibição")
        catalog.Set(
            "工作目录",
                "Pasta de trabalho")
        catalog.Set(
            "工作目录（CWD）：",
                "Pasta de trabalho（CWD）：")
        catalog.Set(
            "已从本次升级过程学习更新程序特征：{1}",
                "Características do atualizador aprendidas nesta atualização: {1}")
        catalog.Set(
            "已保存身份",
                "Identidade salva")
        catalog.Set(
            "已关闭以管理员身份运行：{1}",
                "Execução como administrador desativada: {1}")
        catalog.Set(
            "已创建最高权限的开机自启计划任务（Win10 配置，适配笔记本）。",
                "Foi criada uma tarefa agendada de inicialização automática com privilégios máximos（configuração do Windows 10 compatível com notebooks）.")
        catalog.Set(
            "已创建桌面与开始菜单快捷方式。",
                "Foram criados atalhos na área de trabalho e no menu Iniciar.")
        catalog.Set(
            "已删除自启计划任务。",
                "A tarefa agendada de inicialização automática foi excluída.")
        catalog.Set(
            "已刷新快捷方式内置参数：{1}",
                "Os argumentos internos do atalho foram atualizados: {1}")
        catalog.Set(
            "已刷新快捷方式真实进程（{1}）：{2} -> {3}",
                "O processo real do atalho foi atualizado（{1}）: {2} -> {3}")
        catalog.Set(
            "已发送启动指令：{1}{2}",
                "Comando de inicialização enviado: {1}{2}")
        catalog.Set(
            "已取消监控：{1}",
                "Monitoramento cancelado: {1}")
        catalog.Set(
            "已启动批处理并重定向输出到：{1}",
                "O processo em lote foi iniciado e a saída está sendo redirecionada para: {1}")
        catalog.Set(
            "已启动非驻留目标：{1}",
                "Destino não residente iniciado: {1}")
        catalog.Set(
            "已启用以管理员身份运行：{1}",
                "Execução como administrador ativada: {1}")
        catalog.Set(
            "已导出本地诊断包：{1}",
                "Pacote de diagnóstico local exportado: {1}")
        catalog.Set(
            "已恢复未完成的升级保护会话：{1}",
                "Uma sessão inacabada de proteção de atualizações foi restaurada: {1}")
        catalog.Set(
            "已撤销上一步操作。",
                "A última operação foi desfeita.")
        catalog.Set(
            "已更新主窗口显示设置：{1}",
                "As configurações de exibição da janela principal foram atualizadas: {1}")
        catalog.Set(
            "已更新守护对象路径。",
                "O caminho do alvo monitorado foi atualizado.")
        catalog.Set(
            "已更新软件升级保护设置：{1}",
                "As configurações de proteção de atualizações de software foram atualizadas: {1}")
        catalog.Set(
            "已添加 {1} 个守护对象。",
                "Foram adicionados {1} itens de monitoramento.")
        catalog.Set(
            "已用完快速重试，将每隔 {1} 秒继续尝试启动：{2}",
                "As novas tentativas rápidas acabaram`; uma tentativa de inicialização continuará sendo feita a cada {1} segundos: {2}")
        catalog.Set(
            "已自动学习的更新程序特征：",
                "Características do atualizador aprendidas automaticamente:")
        catalog.Set(
            "已进入软件升级保护：{1}{2}",
                "A proteção de atualizações de software foi ativada: {1}{2}")
        catalog.Set(
            "已重做操作。",
                "A operação foi refeita.")
        catalog.Set(
            "常规终止权限不足，已提权终止进程 PID：{1}",
                "Não havia permissão para o encerramento normal`; o processo de PID {1} foi encerrado com privilégios elevados.")
        catalog.Set(
            "序号",
                "Nº")
        catalog.Set(
            "应用更新助手不存在",
                "O assistente de atualização do aplicativo não existe")
        catalog.Set(
            "应用更新参数无效",
                "Os parâmetros de atualização do aplicativo são inválidos")
        catalog.Set(
            "应用更新安装进程未返回 PID",
                "O processo de instalação da atualização não retornou um PID")
        catalog.Set(
            "应用更新本地化资源不存在",
                "Os recursos de localização da atualização do aplicativo não existem")
        catalog.Set(
            "应用更新检查进程未返回 PID",
                "O processo de verificação de atualizações não retornou um PID")
        catalog.Set(
            "守护对象",
                "Alvo monitorado")
        catalog.Set(
            "应用资源",
                "Recursos do aplicativo")
        catalog.Set(
            "开机自动启动（计划任务）",
                "Inicialização automática ao ligar（tarefa agendada）")
        catalog.Set(
            "当前陪伴您的已经是最新版本的小助手啦！",
                "O assistente que acompanha você já está na versão mais recente!")
        catalog.Set(
            "当前应用版本无效",
                "A versão atual do aplicativo é inválida")
        catalog.Set(
            "当前版本：{1}（EXE 版；内嵌 AutoHotkey {2} x64）",
                "Versão atual: {1}（edição EXE`; AutoHotkey {2} x64 incorporado）")
        catalog.Set(
            "当前版本：{1}（源码版；本机 AutoHotkey {2} x64）",
                "Versão atual: {1}（edição de código-fonte`; AutoHotkey local {2} x64）")
        catalog.Set(
            "当前状态：升级活动已结束，正在确认程序文件稳定",
                "Status atual: a atividade de atualização terminou`; confirmando a estabilidade dos arquivos do programa")
        catalog.Set(
            "当前状态：升级等待超时，需要确认后恢复",
                "Status atual: o tempo limite da atualização foi excedido`; é preciso confirmar para retomar")
        catalog.Set(
            "当前状态：已从上次运行恢复未完成的升级保护",
                "Status atual: a proteção de atualizações inacabada da execução anterior foi restaurada")
        catalog.Set(
            "当前状态：已暂停自动启动，正在等待升级完成",
                "Status atual: a inicialização automática está pausada enquanto a atualização termina")
        catalog.Set(
            "当前状态：显式升级维护已开始，正在等待结束命令",
                "Status atual: a manutenção explícita da atualização foi iniciada`; aguardando o comando de encerramento")
        catalog.Set(
            "当前状态：正在判断本次退出是否由升级引起",
                "Status atual: verificando se esta saída foi causada por uma atualização")
        catalog.Set(
            "当前状态：正常守护",
                "Status atual: monitoramento normal")
        catalog.Set(
            "快捷方式参数",
                "Argumentos do atalho")
        catalog.Set(
            "快捷方式及已解析目标均不可用",
                "O atalho e o destino resolvido estão indisponíveis")
        catalog.Set(
            "快捷方式目标",
                "Destino do atalho")
        catalog.Set(
            "快捷方式真实目标",
                "Destino real do atalho")
        catalog.Set(
            "快捷方式真实进程刷新被拒绝，目标已由其它守护对象守护：{1} -> {2}",
                "A atualização do processo real do atalho foi recusada porque o destino já é monitorado por outro item: {1} -> {2}")
        catalog.Set(
            "恢复守护：{1}",
                "Retomar monitoramento: {1}")
        catalog.Set(
            "恢复记录列表无效",
                "A lista de registros de restauração é inválida")
        catalog.Set(
            "恢复记录无效",
                "O registro de restauração é inválido")
        catalog.Set(
            "恢复记录缺少字段：{1}",
                "Falta um campo no registro de restauração: {1}")
        catalog.Set(
            "成功",
                "Sucesso")
        catalog.Set(
            "所选文件夹内未找到支持的程序、脚本或快捷方式。",
                "Nenhum programa, script ou atalho compatível foi encontrado na pasta selecionada.")
        catalog.Set(
            "手动添加守护对象：{1}",
                "Monitoramento adicionado manualmente: {1}")
        catalog.Set(
            "已结束运行：{1}",
                "Alvo encerrado: {1}")
        catalog.Set(
            "结束运行失败，目标进程未能停止：{1}",
                "Não foi possível encerrar o processo de destino: {1}")
        catalog.Set(
            "托管窗口生命周期尚未配置",
                "O ciclo de vida da janela gerenciada ainda não foi configurado")
        catalog.Set(
            "托管窗口生命周期适配器无效",
                "O adaptador do ciclo de vida da janela gerenciada é inválido")
        catalog.Set(
            "扩展设置包含无效数值。`n`n窗口程序关闭等待：1-300 秒`n命令行程序退出等待：1-60 秒`n日志条数：50-10000`n日志保留：1-3650 天",
                "Uma ou mais configurações avançadas são inválidas.`n`nEspera para fechar aplicativos com janela: 1-300 segundos`nEspera para encerrar aplicativos de linha de comando: 1-60 segundos`nEntradas de log: 50-10000`nRetenção de logs: 1-3650 dias")
        catalog.Set(
            "批处理启动需要输出日志路径",
                "A inicialização em lote exige um caminho para o log de saída")
        catalog.Set(
            "批量导入中断",
                "Importação em lote interrompida")
        catalog.Set(
            "批量导入完成",
                "Importação em lote concluída")
        catalog.Set(
            "批量导入已取消，已保留并保存此前添加的 {1} 个守护对象。",
                "A importação em lote foi cancelada. Os {1} itens de monitoramento adicionados anteriormente foram mantidos e salvos.")
        catalog.Set(
            "拒绝修改路径，真实进程已由其它守护对象守护：{1}",
                "A alteração do caminho foi recusada porque o processo real já é monitorado por outro item: {1}")
        catalog.Set(
            "拒绝更新路径，已存在相同的守护对象：{1}",
                "A alteração do caminho foi recusada porque já existe um alvo monitorado idêntico: {1}")
        catalog.Set(
            "按钮绘制器",
                "Renderizador de botões")
        catalog.Set(
            "捕获守护对象历史失败：{1}",
                "Falha ao capturar o histórico dos itens de monitoramento: {1}")
        catalog.Set(
            "提示",
                "Aviso")
        catalog.Set(
            "⚡️搜索⚡️",
                "⚡️ Pesquisa ⚡️")
        catalog.Set(
            "操作计划任务时发生错误！`n`n{1}",
                "Ocorreu um erro ao operar a tarefa agendada.`n`n{1}")
        catalog.Set(
            "支持的图标与图片",
                "Ícones e imagens compatíveis")
        catalog.Set(
            "支持的程序、脚本与快捷方式",
                "Programas, scripts e atalhos compatíveis")
        catalog.Set(
            "支持的程序与脚本",
                "Programas e scripts compatíveis")
        catalog.Set(
            "收到显式维护开始命令",
                "Comando explícito de início de manutenção recebido")
        catalog.Set(
            "收到显式维护结束命令，开始执行安全恢复检查：{1}",
                "Comando explícito de encerramento da manutenção recebido`; iniciando a verificação de retomada segura: {1}")
        catalog.Set(
            "整条展示配置",
                "Configuração de exibição completa")
        catalog.Set(
            "整条记录",
                "Registro completo")
        catalog.Set(
            "文件稳定等待（秒）：",
                "Espera de estabilidade do arquivo（segundos）：")
        catalog.Set(
            "新脚本未通过 AutoHotkey 解析检查",
                "O novo script não passou na verificação de sintaxe do AutoHotkey")
        catalog.Set(
            "无法从损坏记录中提取",
                "Não foi possível extrair dados do registro corrompido")
        catalog.Set(
            "无法停止进程 PID：{1}{2}",
                "Não foi possível encerrar o processo de PID {1}{2}")
        catalog.Set(
            "无法写入诊断文件：{1}",
                "Não foi possível gravar o arquivo de diagnóstico: {1}")
        catalog.Set(
            "无法启动后台文件扫描：{1}",
                "Não foi possível iniciar a verificação de arquivos em segundo plano: {1}")
        catalog.Set(
            "无法启动后台进程快照任务：{1}",
                "Não foi possível iniciar a tarefa de instantâneo dos processos em segundo plano: {1}")
        catalog.Set(
            "无法启动小助手更新安装：{1}",
                "Não foi possível iniciar a instalação da atualização do assistente: {1}")
        catalog.Set(
            "无法启动小助手更新检查：{1}",
                "Não foi possível iniciar a verificação de atualizações do assistente: {1}")
        catalog.Set(
            "无法导出诊断包：`n{1}",
                "Não foi possível exportar o pacote de diagnóstico:`n{1}")
        catalog.Set(
            "无法建立单实例运行锁，小助手将退出。",
                "Não foi possível obter o bloqueio de instância única`; o assistente será encerrado.")
        catalog.Set(
            "无法开始更新：{1}",
                "Não foi possível iniciar a atualização: {1}")
        catalog.Set(
            "无法收集此部分诊断信息：{1}",
                "Não foi possível coletar esta parte das informações de diagnóstico: {1}")
        catalog.Set(
            "无法检查更新：{1}",
                "Não foi possível verificar se há atualizações: {1}")
        catalog.Set(
            "无法清理后台扫描临时文件：{1}",
                "Não foi possível limpar o arquivo temporário da verificação em segundo plano: {1}")
        catalog.Set(
            "无法清理后台扫描结果文件：{1}",
                "Não foi possível limpar o arquivo de resultados da verificação em segundo plano: {1}")
        catalog.Set(
            "无法生成守护对象快照：{1}",
                "Não foi possível criar o instantâneo dos itens de monitoramento: {1}")
        catalog.Set(
            "日志",
                "Log")
        catalog.Set(
            "日志文件不存在：{1}",
                "O arquivo de log não existe: {1}")
        catalog.Set("📄 查看批处理输出日志", "📄 Ver log de saída em lote")
        catalog.Set("尚未生成批处理输出日志", "Ainda não há log de saída em lote")
        catalog.Set(
            "小助手只有在启动 BAT 或 CMD 守护对象时才会创建此文件。",
                "Este arquivo só é criado quando o assistente inicia um item BAT ou CMD.")
        catalog.Set("日志保存位置：", "Local do log:")
        catalog.Set("确定", "OK")
        catalog.Set(
            "时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间",
                "As configurações de tempo são inválidas.`n`nJanela de detecção de saída: 2-120 segundos`nEspera de estabilidade do arquivo: 2-300 segundos`nEspera máxima da atualização: 60-86400 segundos e deve ser maior que a espera de estabilidade")
        catalog.Set(
            "显式升级维护命令执行异常：{1}",
                "Erro ao executar o comando explícito de manutenção da atualização: {1}")
        catalog.Set(
            "显式升级维护命令未找到监控目标：{1}",
                "O comando explícito de manutenção da atualização não encontrou o destino monitorado: {1}")
        catalog.Set(
            "显式升级维护命令被忽略，目标未启用升级保护：{1}",
                "O comando explícito de manutenção da atualização foi ignorado porque a proteção de atualizações não está ativada para o destino: {1}")
        catalog.Set(
            "显示主界面",
                "Exibir a interface principal")
        catalog.Set(
            "显示名称：",
                "Nome exibido：")
        catalog.Set(
            "暂停守护：{1}",
                "Pausar monitoramento: {1}")
        catalog.Set(
            "暂停或恢复选中守护对象，不会退出目标`n支持多选；混合状态时逐项反转`n快捷键：Space",
                "Pausar ou retomar o monitoramento dos itens selecionados sem fechar os destinos`nPermite seleção múltipla`; quando os status são diferentes, cada um é invertido`nAtalho: Espaço")
        catalog.Set(
            "暂时无法查询进程状态，稍后重试结束运行：{1}",
                "Não é possível consultar o status do processo no momento`; o encerramento será tentado novamente mais tarde: {1}")
        catalog.Set(
            "暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                "Não é possível conferir os processos existentes no momento`; a inicialização foi adiada para evitar instâncias duplicadas: {1}")
        catalog.Set(
            "暂时无法结束运行",
                "Não é possível encerrar no momento")
        catalog.Set(
            "更新助手已启动，小助手即将退出并完成更新。",
                "O assistente de atualização foi iniciado. O assistente será encerrado para concluir a atualização.")
        catalog.Set(
            "更新应用搜索结果失败：{1}",
                "Falha ao atualizar os resultados da pesquisa de aplicativos: {1}")
        catalog.Set(
            "更新检查未返回结果",
                "A verificação de atualizações não retornou um resultado")
        catalog.Set(
            "更新检查正在进行，请稍候。",
                "Já existe uma verificação de atualizações em andamento. Aguarde.")
        catalog.Set(
            "更新检查返回了无法识别的状态：{1}",
                "A verificação de atualizações retornou um status desconhecido: {1}")
        catalog.Set(
            "最长升级等待（秒）：",
                "Espera máxima da atualização（segundos）：")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），恢复普通重启流程：{3}",
                "Nenhuma atividade de atualização foi detectada（{1}, duração de {2} segundos）`; retomando o processo normal de reinicialização: {3}")
        catalog.Set(
            "未发现升级活动（{1}，耗时 {2} 秒），目标仍不存在：{3}",
                "Nenhuma atividade de atualização foi detectada（{1}, duração de {2} segundos）e o destino continua ausente: {3}")
        catalog.Set(
            "未找到目标",
                "Destino não encontrado")
        catalog.Set(
            "未添加",
                "Não adicionado")
        catalog.Set(
            "未知升级保护阶段",
                "Etapa desconhecida da proteção de atualizações")
        catalog.Set(
            "未知守护阶段",
                "Etapa de monitoramento desconhecida")
        catalog.Set(
            "未知版本",
                "Versão desconhecida")
        catalog.Set(
            "未知解析错误",
                "Erro de interpretação desconhecido")
        catalog.Set(
            "未知错误",
                "Erro desconhecido")
        catalog.Set(
            "查看实时运行日志`n涵盖监控、重启、升级保护与操作记录",
                "Ver o log de execução em tempo real`nInclui registros de monitoramento, reinicialização, proteção de atualizações e operações")
        catalog.Set(
            "查看支持类型、操作方法、守护设置`n以及升级保护说明",
                "Ver os tipos compatíveis, como usar e as configurações de monitoramento`nInclui instruções sobre a proteção de atualizações")
        catalog.Set(
            "核心守护",
                "Monitoramento principal")
        catalog.Set(
            "核心守护计时器启动失败。",
                "Falha ao iniciar o temporizador do monitoramento principal.")
        catalog.Set(
            "桌面与开始菜单快捷方式",
                "Atalhos da área de trabalho e do menu Iniciar")
        catalog.Set(
            "创建成功！",
                "Criados!")
        catalog.Set(
            "检查小助手更新",
                "Procurar atualizações do assistente")
        catalog.Set(
            "检查小助手更新失败：{1}",
                "Falha ao procurar atualizações do assistente: {1}")
        catalog.Set(
            "检查更新",
                "Procurar atualizações")
        catalog.Set(
            "检查更新失败：{1}",
                "Falha ao procurar atualizações: {1}")
        catalog.Set(
            "检查更新超时",
                "A verificação de atualizações excedeu o tempo limite")
        catalog.Set(
            "检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。",
                "Foi encontrada uma tarefa agendada com o mesmo nome, mas ela não foi criada por este programa. Para evitar uma exclusão acidental, gerencie-a primeiro no Agendador de Tarefas.")
        catalog.Set(
            "检测到安装目录变化",
                "Alteração na pasta de instalação detectada")
        catalog.Set(
            "检测到相关安装进程",
                "Processo de instalação relacionado detectado")
        catalog.Set(
            "检测到程序文件变化",
                "Alteração nos arquivos do programa detectada")
        catalog.Set(
            "检测到运行中的目标未使用管理员权限：{1}",
                "O destino em execução não usa permissões de administrador: {1}")
        catalog.Set(
            "检测到进程停止，准备重启：{1}（将在 {2} 秒后启动）",
                "Foi detectado que o processo parou`; preparando a reinicialização: {1}（será iniciado em {2} segundos）")
        catalog.Set(
            "正在扫描...",
                "Verificando...")
        catalog.Set(
            "正在扫描文件夹，可点击取消停止",
                "Verificando a pasta`; clique em Cancelar para interromper")
        catalog.Set(
            "正在扫描：{1}",
                "Verificando: {1}")
        catalog.Set(
            "正在添加扫描结果...",
                "Adicionando os resultados da verificação...")
        catalog.Set(
            "正在添加：{1} / {2}",
                "Adicionando: {1} / {2}")
        catalog.Set(
            "正常关闭超时后允许强制终止",
                "Permitir encerramento forçado após o tempo limite da saída normal")
        catalog.Set(
            "正常关闭超时，已强制终止进程 PID：{1}",
                "O tempo limite da saída normal foi excedido`; o processo de PID {1} foi encerrado à força")
        catalog.Set(
            "正常关闭超时，已按设置跳过强制终止 PID：{1}",
                "O tempo limite da saída normal foi excedido`; conforme configurado, o encerramento forçado do PID {1} foi ignorado")
        catalog.Set(
            "没有可安装的应用更新",
                "Não há atualização de aplicativo disponível para instalação")
        catalog.Set(
            "浏览",
                "Procurar")
        catalog.Set(
            "添加扫描结果失败",
                "Falha ao adicionar os resultados da verificação")
        catalog.Set(
            "添加守护对象",
                "Adicionar item de monitoramento")
        catalog.Set(
            "添加守护对象失败，已回滚内存状态：{1}",
                "Falha ao adicionar o item de monitoramento`; o estado na memória foi revertido: {1}")
        catalog.Set(
            "添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放",
                "Adicionar programa, script ou atalho`nPermite pesquisa, importação de pastas em lote e arrastar arquivos")
        catalog.Set(
            "清除记录",
                "Limpar registros")
        catalog.Set(
            "状态",
                "Status")
        catalog.Set(
            "独立环境配置 💡`n",
                "Configuração de ambiente independente 💡`n")
        catalog.Set(
            "环境变量",
                "Variáveis de ambiente")
        catalog.Set(
            "环境变量（每行一个 KEY=VALUE）：",
                "Variáveis de ambiente（uma por linha no formato KEY=VALUE）：")
        catalog.Set(
            "用户指定",
                "Definido pelo usuário")
        catalog.Set(
            "用户结束了升级等待，重新执行安全启动检查：{1}",
                "O usuário encerrou a espera da atualização`; repetindo a verificação de inicialização segura: {1}")
        catalog.Set(
            "界面语言和字体已即时更新，无需重新启动小助手。",
                "O idioma e a fonte da interface foram atualizados imediatamente; não é necessário reiniciar o assistente.")
        catalog.Set(
            "更新配置注释语言失败：{1}",
                "Não foi possível atualizar o idioma dos comentários da configuração: {1}")
        catalog.Set(
            "；恢复配置失败：{1}",
                "; também não foi possível restaurar a configuração: {1}")
        catalog.Set(
            "界面显示设置无法即时应用，已恢复原语言和字体：{1}",
                "Não foi possível aplicar imediatamente as configurações de exibição. O idioma e a fonte anteriores foram restaurados: {1}")
        catalog.Set(
            "无法即时切换界面语言或字体，原显示设置已恢复。`n`n{1}",
                "Não foi possível alterar imediatamente o idioma ou a fonte da interface. As configurações de exibição anteriores foram restauradas.`n`n{1}")
        catalog.Set(
            "显示设置应用失败",
                "Não foi possível aplicar as configurações de exibição")
        catalog.Set(
            "跟随语言默认（{1}）",
                "Usar a fonte padrão do idioma（{1}）")
        catalog.Set(
            "正在检查更新…",
                "Verificando atualizações…")
        catalog.Set(
            "`; UiFont：界面字体；auto 表示使用当前语言的默认字体，也可填写本机已安装字体名称。",
                "`; UiFont: fonte da interface. auto usa a fonte padrão do idioma atual`; também é possível informar o nome de uma fonte instalada.")
        catalog.Set(
            "界面语言：",
                "Idioma da interface：")
        catalog.Set(
            "界面资源",
                "Recursos da interface")
        catalog.Set("启动", "Inicialização")
        catalog.Set("监控", "Monitoramento")
        catalog.Set(
            "守护对象重复",
                "Destino de monitoramento duplicado")
        catalog.Set(
            "监控配置加载异常",
                "Erro ao carregar a configuração de monitoramento")
        catalog.Set(
            "监控配置加载异常：共 {1} 条记录未能载入。",
                "Erro ao carregar a configuração de monitoramento: {1} registros não puderam ser carregados.")
        catalog.Set(
            "监控配置尚未保存，请查看运行日志。",
                "A configuração de monitoramento ainda não foi salva. Consulte o log de execução.")
        catalog.Set(
            "守护对象保存状态无效",
                "O status de salvamento do item de monitoramento é inválido")
        catalog.Set(
            "守护对象注册回调无效",
                "O retorno de chamada para registrar o item de monitoramento é inválido")
        catalog.Set(
            "守护对象路径无效：{1}",
                "O caminho do item de monitoramento é inválido: {1}")
        catalog.Set(
            "监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核：{1}",
                "Foi detectado que o arquivo de destino não existe mais. O monitoramento passou para o estado de arquivo ausente e fará uma nova verificação automaticamente quando ele reaparecer: {1}")
        catalog.Set(
            "目标任务需要 WatchdogScheduler",
                "A tarefa de destino exige WatchdogScheduler")
        catalog.Set(
            "目标文件已恢复，重新核对运行状态：{1}",
                "O arquivo de destino reapareceu`; verificando novamente o status de execução: {1}")
        catalog.Set(
            "目标文件缺失时检测到升级活动",
                "Atividade de atualização detectada enquanto o arquivo de destino estava ausente")
        catalog.Set(
            "目标程序文件不存在",
                "O arquivo do programa de destino não existe")
        catalog.Set(
            "目标程序：{1}",
                "Programa de destino: {1}")
        catalog.Set(
            "目标路径",
                "Caminho de destino")
        catalog.Set(
            "目标退出时检测到升级信号",
                "Sinal de atualização detectado quando o destino saiu")
        catalog.Set(
            "真实目标来源标记",
                "Indicador da origem do destino real")
        catalog.Set(
            "真实进程路径无效",
                "O caminho do processo real é inválido")
        catalog.Set(
            "确 定",
                "Confirmar")
        catalog.Set(
            "程序文件刚刚发生变化",
                "O arquivo do programa acabou de ser alterado")
        catalog.Set(
            "程序文件尚未达到稳定等待时间",
                "O arquivo do programa ainda não atingiu o tempo de estabilidade necessário")
        catalog.Set(
            "程序文件正在写入或结构不完整",
                "O arquivo do programa está sendo gravado ou sua estrutura está incompleta")
        catalog.Set(
            "稍后",
                "Mais tarde")
        catalog.Set(
            "窗口层级平台适配器无效",
                "O adaptador de plataforma da hierarquia de janelas é inválido")
        catalog.Set(
            "窗口层级管理器无效",
                "O gerenciador da hierarquia de janelas é inválido")
        catalog.Set(
            "窗口布局字段不是整数：{1}",
                "O campo de layout da janela não é um inteiro: {1}")
        catalog.Set(
            "窗口布局字段超出范围：{1}",
                "O campo de layout da janela está fora do intervalo: {1}")
        catalog.Set(
            "窗口布局对象无效",
                "O objeto de layout da janela é inválido")
        catalog.Set(
            "立即更新",
                "Atualizar agora")
        catalog.Set(
            "等待 {1} 秒后进行第 {2} 次尝试...",
                "Aguarde {1} segundos antes da tentativa {2}...")
        catalog.Set(
            "管理员运行状态",
                "Status da execução como administrador")
        catalog.Set(
            "系统 PowerShell 不可用",
                "O PowerShell do sistema não está disponível")
        catalog.Set(
            "系统压缩工具未能创建诊断包",
                "A ferramenta de compactação do sistema não conseguiu criar o pacote de diagnóstico")
        catalog.Set(
            "系统权限拦截",
                "Bloqueado pelas permissões do sistema")
        catalog.Set(
            "通用",
                "Geral")
        catalog.Set(
            "显示",
                "Exibição")
        catalog.Set(
            "结束升级等待并恢复守护",
                "Encerrar a espera da atualização e retomar o monitoramento")
        catalog.Set(
            "编码损坏",
                "Codificação corrompida")
        catalog.Set(
            "缺少窗口布局字段：{1}",
                "Falta um campo de layout da janela: {1}")
        catalog.Set(
            "缺少窗口生命周期回调：{1}",
                "Falta um retorno de chamada do ciclo de vida da janela: {1}")
        catalog.Set(
            "缺少诊断信息提供器：{1}",
                "Falta um provedor de informações de diagnóstico: {1}")
        catalog.Set(
            "缺少运行参数：{1}",
                "Falta um parâmetro de execução: {1}")
        catalog.Set(
            "自动",
                "Automático")
        catalog.Set(
            "自动识别升级并保护启动过程",
                "Detectar atualizações automaticamente e proteger o processo de inicialização")
        catalog.Set(
            "自动识别进程",
                "Identificar o processo automaticamente")
        catalog.Set(
            "自定义名称",
                "Nome personalizado")
        catalog.Set(
            "自定义图标",
                "Ícone personalizado")
        catalog.Set(
            "计划任务冲突",
                "Conflito de tarefa agendada")
        catalog.Set(
            "计划任务操作失败：{1}",
                "Falha ao operar a tarefa agendada: {1}")
        catalog.Set(
            "设置已更新：轮询={1}ms，序列=[{2}]，日志上限={3}",
                "Configurações atualizadas: sondagem={1}ms, sequência=[{2}], limite do log={3}")
        catalog.Set(
            "设置无效",
                "Configurações inválidas")
        catalog.Set(
            "诊断临时目录已存在",
                "A pasta temporária de diagnóstico já existe")
        catalog.Set(
            "诊断包保存目录不存在",
                "A pasta de destino do pacote de diagnóstico não existe")
        catalog.Set(
            "诊断包已导出到：`n{1}",
                "Pacote de diagnóstico exportado para:`n{1}")
        catalog.Set(
            "诊断包目标文件名已被占用",
                "O nome do arquivo de destino do pacote de diagnóstico já está em uso")
        catalog.Set(
            "诊断压缩包未生成",
                "O arquivo compactado de diagnóstico não foi gerado")
        catalog.Set(
            "该文件不是受支持的图标或图片格式。`n`n支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。",
                "Este arquivo não usa um formato de ícone ou imagem compatível.`n`nSão aceitos ICO, EXE, DLL, CPL, LNK, PNG, JPG, JPEG, JPE, JFIF, BMP, GIF, TIF, TIFF, WebP, SVG e ANI.")
        catalog.Set(
            "该目标已存在、无效或指向目录。",
                "Este destino já existe, é inválido ou aponta para uma pasta.")
        catalog.Set(
            "该真实进程已由其他守护对象守护。",
                "Este processo real já é protegido por outro item de monitoramento.")
        catalog.Set(
            "该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再结束运行。",
                "Este software está sob proteção de atualização. Aguarde a atualização terminar ou encerre a espera em “Proteção de atualizações de software” antes de encerrá-lo.")
        catalog.Set(
            "语义版本无效",
                "A versão semântica é inválida")
        catalog.Set(
            "请通过上方按钮搜索或选择，或在下方填写进程名或目标路径：`n【支持程序、脚本、快捷方式，以及文件夹批量导入】",
                "Use os botões acima para pesquisar ou selecionar.`nOu informe abaixo o nome do processo ou o caminho de destino.`n【Programas, scripts, atalhos e importação de pastas em lote】")
        catalog.Set(
            "请选择现有且可执行的真实程序或脚本路径。",
                "Selecione o caminho existente e executável de um programa ou script real.")
        catalog.Set(
            "请选择现有的图标、程序、资源库或快捷方式文件。",
                "Selecione um arquivo existente de ícone, programa, biblioteca de recursos ou atalho.")
        catalog.Set(
            "读取后台扫描结果失败",
                "Falha ao ler os resultados da verificação em segundo plano")
        catalog.Set(
            "调度器已停止",
                "O agendador foi interrompido")
        catalog.Set(
            "跟随系统",
                "Acompanhar o sistema")
        catalog.Set(
            "路径",
                "Caminho")
        catalog.Set(
            "轮询间隔必须为 500-86400000 毫秒的正整数！",
                "O intervalo de sondagem deve ser um inteiro positivo entre 500 e 86400000 milissegundos.")
        catalog.Set(
            "软件升级保护",
                "Proteção de atualizações de software")
        catalog.Set(
            "软件升级保护超过最长等待时间，需要用户确认后恢复：{1}",
                "A proteção de atualizações de software excedeu a espera máxima`; é preciso confirmar para retomar: {1}")
        catalog.Set(
            "软件升级完成，准备恢复启动：{1}",
                "A atualização de software terminou`; preparando a retomada da inicialização: {1}")
        catalog.Set(
            "软件升级完成，已恢复正常守护：{1}",
                "A atualização de software terminou`; o monitoramento normal foi retomado: {1}")
        catalog.Set(
            "载入中...",
                "Carregando...")
        catalog.Set(
            "运行参数不是支持的界面语言：{1}",
                "O parâmetro de execução não é um idioma de interface compatível: {1}")
        catalog.Set(
            "运行参数不是整数：{1}",
                "O parâmetro de execução não é um inteiro: {1}")
        catalog.Set(
            "运行参数不能为空：{1}",
                "O parâmetro de execução não pode ficar vazio: {1}")
        catalog.Set(
            "运行参数对象无效",
                "O objeto de parâmetros de execução é inválido")
        catalog.Set(
            "运行参数超出范围：{1}",
                "O parâmetro de execução está fora do intervalo: {1}")
        catalog.Set(
            "运行日志",
                "Log de execução")
        catalog.Set(
            "进程仍在运行，忽略重复启动：{1}",
                "O processo ainda está em execução`; a inicialização duplicada foi ignorada: {1}")
        catalog.Set(
            "进程启动后迅速退出或未成功常驻后台",
                "O processo terminou logo depois de iniciar ou não conseguiu permanecer em execução em segundo plano")
        catalog.Set(
            "进程守护小助手",
                "Assistente de Monitoramento de Processos")
        catalog.Set(
            "持续守护重要程序与自动化任务，让日常工作稳定运行",
                "Mantenha aplicativos e automações essenciais funcionando com estabilidade todos os dias")
        catalog.Set(
            "进程守护小助手 - 开机自启守护程序",
                "Assistente de Monitoramento de Processos - Monitor de inicialização automática")
        catalog.Set(
            "进程守护小助手已静默启动。",
                "O Assistente de Monitoramento de Processos foi iniciado silenciosamente.")
        catalog.Set(
            "退出检测窗口（秒）：",
                "Janela de detecção de saída（segundos）：")
        catalog.Set(
            "退出清理异常（{1}）：{2}",
                "Erro na limpeza ao sair（{1}）: {2}")
        catalog.Set(
            "退出程序",
                "Sair do programa")
        catalog.Set(
            "选择主窗口图标",
                "Selecionar o ícone da janela principal")
        catalog.Set(
            "选择工作目录",
                "Selecionar a pasta de trabalho")
        catalog.Set(
            "选择快捷方式对应的真实进程",
                "Selecionar o processo real correspondente ao atalho")
        catalog.Set(
            "选择批处理日志目录",
                "Selecionar a pasta dos logs em lote")
        catalog.Set(
            "选择文件",
                "Selecionar arquivo")
        catalog.Set(
            "选择文件夹",
                "Selecionar pasta")
        catalog.Set(
            "选择要监控的文件",
                "Selecionar o arquivo que será monitorado")
        catalog.Set(
            "选择要监控的文件夹",
                "Selecionar a pasta que será monitorada")
        catalog.Set(
            "选择诊断包保存位置",
                "Selecionar onde salvar o pacote de diagnóstico")
        catalog.Set(
            "选择软件安装目录",
                "Selecionar a pasta de instalação do software")
        catalog.Set(
            "通过拖拽添加了 {1} 个守护对象。",
                "Foram adicionados {1} itens de monitoramento por arrastar e soltar.")
        catalog.Set(
            "配置仓储无效",
                "O repositório de configurações é inválido")
        catalog.Set(
            "配置写入器无效",
                "O gravador de configurações é inválido")
        catalog.Set(
            "配置文件写入事务正在进行",
                "Há uma transação de gravação do arquivo de configuração em andamento")
        catalog.Set(
            "重新加载",
                "Recarregar")
        catalog.Set(
            "重新加载失败",
                "Falha ao recarregar")
        catalog.Set(
            "重新加载失败，已保留当前实例：{1}",
                "Falha ao recarregar`; a instância atual foi mantida: {1}")
        catalog.Set(
            "重新加载失败，当前守护仍在运行。`n`n{1}",
                "Falha ao recarregar`; o monitoramento atual continua em execução.`n`n{1}")
        catalog.Set(
            "重试序列不能为空！",
                "A sequência de novas tentativas não pode ficar vazia.")
        catalog.Set(
            "重试序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。",
                "O formato da sequência de novas tentativas está incorreto. Ela deve conter inteiros positivos separados por vírgulas（por exemplo: 1,10,60）, cada um entre 1 e 86400 segundos.")
        catalog.Set(
            "重试延迟序列不能为空",
                "A sequência de atrasos para novas tentativas não pode ficar vazia")
        catalog.Set(
            "重试延迟序列无效",
                "A sequência de atrasos para novas tentativas é inválida")
        catalog.Set(
            "错误",
                "Erro")
        catalog.Set(
            "名称：{1}`n真实路径：{2}",
                "Nome: {1}`nCaminho real: {2}")
        catalog.Set(
            "🌿 环境变量：{1} 项`n",
                "🌿 Variáveis de ambiente: {1}`n")
        catalog.Set(
            "🎨 自定义名称和图标",
                "🎨 Personalizar nome e ícone")
        catalog.Set(
            "📁 工作目录：{1}`n",
                "📁 Pasta de trabalho: {1}`n")
        catalog.Set(
            "📂 打开所在位置",
                "📂 Abrir local")
        catalog.Set(
            "📂 浏览文件夹...",
                "📂 Procurar pasta...")
        catalog.Set(
            "选择...",
                "Selecionar...")
        catalog.Set(
            "📄 查看运行日志",
                "📄 Ver log de execução")
        catalog.Set(
            "📄 浏览文件...",
                "📄 Procurar arquivo...")
        catalog.Set(
            "🔄 反转状态",
                "🔄 Inverter status")
        catalog.Set(
            "🔄 恢复升级保护状态",
                "🔄 Estado restaurado da proteção de atualizações")
        catalog.Set(
            "🔄 显式升级维护中",
                "🔄 Manutenção explícita da atualização em andamento")
        catalog.Set(
            "🔄 检查",
                "🔄 Verificar")
        catalog.Set(
            "🔄 等待程序文件可用",
                "🔄 Aguardando o arquivo do programa ficar disponível")
        catalog.Set(
            "🔄 等待程序文件恢复",
                "🔄 Aguardando a restauração do arquivo do programa")
        catalog.Set(
            "🔄 软件升级中",
                "🔄 Software sendo atualizado")
        catalog.Set(
            "🔄 软件升级保护",
                "🔄 Proteção de atualizações de software")
        catalog.Set(
            "⏹️ 结束运行",
                "⏹️ Encerrar execução")
        catalog.Set(
            "搜索...",
                "Pesquisar...")
        catalog.Set(
            "搜索：",
                "Pesquisar：")
        catalog.Set(
            "扩展名",
                "Extensão")
        catalog.Set(
            "🗑️ 删除",
                "🗑️ Excluir")
        catalog.Set(
            "🚀 正在启动...",
                "🚀 Iniciando...")
        catalog.Set(
            "🛡️ 以管理员身份运行",
                "🛡️ Executar como administrador")
        catalog.Set(
            "（{1}）",
                "（{1}）")
        catalog.Set(
            "（第 {1} 行）",
                "（linha {1}）")
        catalog.Set(
            "（管理员权限）",
                "（permissões de administrador）")
        catalog.Set(
            "：{1}",
                "：{1}")
        catalog.Set(
            "Everything 搜索不可用，请确认 Everything 正在运行。",
                "A pesquisa do Everything não está disponível. Verifique se o Everything está em execução.")
        catalog.Set(
            "正在载入 Everything 搜索结果：{1}／{2}",
                "Carregando resultados da pesquisa do Everything: {1}/{2}")
        catalog.Set(
            "Everything 搜索结果：{1} 项",
                "Resultados da pesquisa do Everything: {1} itens")
        catalog.Set("{1}（EXE 版）", "{1}（versão EXE）")
        catalog.Set("{1}（源码版）", "{1}（versão de código-fonte）")
        catalog.Set("• “结束运行”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• “Encerrar execução” primeiro solicita que o destino seja encerrado normalmente. Se o tempo limite expirar, a opção em “Política de encerramento” determina se o processo será finalizado à força.")
        catalog.Set("• 关于：查看软件版本和 AutoHotkey 运行环境，手动检查更新或打开开源地址。", "• Sobre: consulte a versão do aplicativo e o ambiente de execução do AutoHotkey, procure atualizações manualmente ou abra o projeto de código aberto.")
        catalog.Set("• 检测到目标停止后，会先确认状态，再按“崩溃自动重启延迟序列”依次重试；连续失败时采用后续延迟，避免频繁拉起。", "• Ao detectar que um destino parou, o assistente confirma o estado e tenta novamente conforme a “Sequência de atrasos para reinício automático após falha”. Em caso de falhas seguidas, os atrasos seguintes evitam reinicializações muito frequentes.")
        catalog.Set("• 界面语言和内容字体保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Ao salvar o idioma da interface ou a fonte do conteúdo, a janela principal, os menus e a bandeja são atualizados imediatamente, sem reiniciar.")
        catalog.Set("• 日志：设置运行日志显示上限、批处理日志保存路径、保留天数和启动时清理策略。", "• Logs: defina o limite de exibição do log de execução, o caminho e os dias de retenção dos logs de saída em lote e a limpeza ao iniciar.")
        catalog.Set("• 停止策略：设置 GUI 程序和 CLI 程序的关闭超时，以及正常关闭超时后是否允许强制终止。", "• Política de encerramento: defina o tempo limite para fechar aplicativos GUI e CLI e se a finalização forçada será permitida quando o encerramento normal exceder esse tempo.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时是否显示主窗口，以及界面语言和内容字体。", "• Geral: crie atalhos na área de trabalho e no menu Iniciar, ative ou desative a inicialização por tarefa agendada, escolha se a janela principal será exibida ao iniciar e defina o idioma e a fonte do conteúdo da interface.")
        catalog.Set("• 小助手版本与 AutoHotkey 版本彼此独立；“关于”页会分别显示当前小助手版本、运行形态和实际运行时版本。", "• As versões do assistente e do AutoHotkey são independentes. A página “Sobre” mostra separadamente a versão atual do assistente, o tipo de distribuição e a versão real do ambiente de execução.")
        catalog.Set("CLI 程序关闭超时（秒）：", "Tempo limite para fechar aplicativos CLI（segundos）:")
        catalog.Set("GUI 程序关闭超时（秒）：", "Tempo limite para fechar aplicativos GUI（segundos）:")
        catalog.Set("崩溃自动重启延迟序列（秒）：", "Atrasos para reinício automático após falha（segundos）:")
        catalog.Set("崩溃自动重启延迟序列不能为空！", "A sequência de atrasos para reinício automático após falha não pode ficar vazia!")
        catalog.Set("崩溃自动重启延迟序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。", "A sequência de atrasos para reinício automático após falha é inválida! Digite números inteiros positivos separados por vírgulas（por exemplo: 1,10,60）, cada um entre 1 e 86400 segundos.")
        catalog.Set("当前版本：", "Versão atual:")
        catalog.Set("导入文件夹时包含子目录", "Incluir subpastas ao importar uma pasta")
        catalog.Set("开源地址", "Projeto de código aberto")
        catalog.Set("关于", "Sobre")
        catalog.Set("界面内容字体：", "Fonte do conteúdo da interface:")
        catalog.Set("进程状态检查间隔（毫秒）：", "Intervalo de verificação dos processos（milissegundos）:")
        catalog.Set("进程状态检查间隔必须为 500-86400000 毫秒的正整数！", "O intervalo de verificação dos processos deve ser um número inteiro positivo entre 500 e 86400000 milissegundos!")
        catalog.Set("扩展设置包含无效数值。`n`nGUI 程序关闭超时：1-300 秒`nCLI 程序关闭超时：1-60 秒`n运行日志显示上限：50-10000 条`n批处理日志保留天数：1-3650 天", "As configurações avançadas contêm valores inválidos.`n`nTempo limite para fechar aplicativos GUI: 1-300 segundos`nTempo limite para fechar aplicativos CLI: 1-60 segundos`nLimite de exibição do log de execução: 50-10000 entradas`nRetenção dos logs de saída em lote: 1-3650 dias")
        catalog.Set("配置显示、启动、监控、停止策略与日志", "Configure Exibição, Inicialização, Monitoramento, Política de encerramento e Logs")
        catalog.Set("批处理日志保存路径：", "Caminho dos logs de saída em lote:")
        catalog.Set("批处理日志保留天数：", "Dias de retenção dos logs de saída em lote:")
        catalog.Set("启动时显示主窗口", "Exibir a janela principal ao iniciar")
        catalog.Set("设置已更新：进程检查间隔={1}ms，重启延迟序列=[{2}]，日志显示上限={3}", "Configurações atualizadas: intervalo dos processos={1} ms, sequência de atrasos para reinício=[{2}], limite de exibição do log={3}")
        catalog.Set("停止策略", "Política de encerramento")
        catalog.Set("运行环境：", "Ambiente de execução:")
        catalog.Set("运行日志显示上限（条）：", "Limite de exibição do log de execução（entradas）:")
        catalog.Set("; Theme：界面主题；auto 表示跟随 Windows 系统，light 表示浅色，dark 表示深色。", "; Theme: tema da interface`; auto acompanha as configurações do Windows, light usa o tema claro e dark usa o tema escuro.")
        catalog.Set("主题：", "Tema:")
        catalog.Set("浅色", "Claro")
        catalog.Set("深色", "Escuro")
        catalog.Set("运行参数不是支持的界面主题：{1}", "A configuração de execução não especifica um tema de interface compatível: {1}")
        catalog.Set("界面显示设置无法即时应用，已恢复原语言、字体和主题：{1}", "Não foi possível aplicar imediatamente as configurações de exibição; o idioma, a fonte e o tema anteriores foram restaurados: {1}")
        catalog.Set("无法即时切换界面语言、字体或主题，原显示设置已恢复。`n`n{1}", "Não foi possível trocar imediatamente o idioma, a fonte ou o tema da interface. As configurações de exibição anteriores foram restauradas.`n`n{1}")
        catalog.Set("界面语言、字体和主题已即时更新，无需重新启动小助手。", "O idioma, a fonte e o tema da interface foram atualizados imediatamente; não é necessário reiniciar o assistente.")
        catalog.Set("• 通用：创建桌面与开始菜单快捷方式，开启或关闭计划任务自启，设置启动时显示主窗口和启动时检查小助手更新，以及界面语言、内容字体和主题。", "• Geral: crie atalhos na área de trabalho e no menu Iniciar, ative ou desative a inicialização agendada, escolha exibir a janela principal e procurar atualizações ao iniciar e defina o idioma, a fonte do conteúdo e o tema.")
        catalog.Set("• 显示：界面语言、内容字体和主题保存后会立即更新主窗口、菜单和托盘，无需重新启动。", "• Exibição: ao salvar o idioma, a fonte do conteúdo ou o tema, a janela principal, os menus e a bandeja são atualizados imediatamente, sem reiniciar.")
        catalog.Set("打开帮助`n可选择查看使用说明、运行日志或提交反馈", "Abrir Ajuda`nEscolha o guia do usuário, o log de execução ou o envio de feedback")
        catalog.Set("快揭不开锅了（≥Д≤）", "O orçamento está quase no fim（≥Д≤）")
        catalog.Set("帮助", "Ajuda")
        catalog.Set("提交反馈", "Enviar feedback")
        catalog.Set("支持开源项目", "Apoiar o projeto de código aberto")
        catalog.Set("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式：", "Se o assistente poupou seu tempo ao diagnosticar problemas e restaurar programas, considere apoiar o autor pelos códigos QR abaixo!`nEscolha como deseja contribuir:")
        catalog.Set("微信支付", "WeChat Pay")
        catalog.Set("支付宝", "Alipay")
        catalog.Set("二维码图片未找到", "Imagem do código QR não encontrada")
        catalog.Set("• 主界面的“帮助”可打开使用说明、本次运行日志或项目反馈页面；日志包含监控、重启、升级保护和操作记录，并会自动更新。", "• Abra Ajuda na janela principal para consultar o guia do usuário, o log desta sessão ou a página de feedback do projeto. O log inclui monitoramento, reinicializações, proteção de atualizações e ações do usuário, e é atualizado automaticamente.")
        catalog.Set("⚙️ 进程识别与启动设置", "⚙️ Identificação do processo e configurações de inicialização")
        catalog.Set("进程识别与启动设置", "Identificação do processo e configurações de inicialização")
        catalog.Set("进程识别", "Identificação do processo")
        catalog.Set("启动环境", "Ambiente de inicialização")
        catalog.Set("快捷方式仍用于启动；真实进程用于判断程序是否正在运行。", "O atalho continua sendo o ponto de inicialização; o processo real é usado para determinar se o aplicativo está em execução.")
        catalog.Set("该守护对象直接启动并监控同一个目标，无需额外识别真实进程。", "Este item inicia e monitora diretamente o mesmo destino, portanto não é necessário identificar outro processo real.")
        catalog.Set("用于判断运行状态的真实进程：", "Processo real usado para verificar o estado:")
        catalog.Set("用于判断运行状态的目标：", "Destino usado para verificar o estado:")
        catalog.Set("重新识别", "Identificar novamente")
        catalog.Set("选择程序", "Escolher programa")
        catalog.Set("识别依据：{1}", "Origem da identificação: {1}")
        catalog.Set("识别依据：暂无可靠结果", "Origem da identificação: nenhum resultado confiável")
        catalog.Set("识别状态：路径有效。", "Estado da identificação: o caminho é válido.")
        catalog.Set("识别状态：路径暂时不可用，已保留上次可靠结果。", "Estado da identificação: o caminho está temporariamente indisponível; o último resultado confiável foi mantido.")
        catalog.Set("识别状态：路径暂时不可用，将保留此身份等待恢复。", "Estado da identificação: o caminho está temporariamente indisponível; esta identidade será mantida enquanto se aguarda a recuperação.")
        catalog.Set("识别状态：未找到可靠目标，请改为手动指定。", "Estado da identificação: nenhum destino confiável foi encontrado. Especifique-o manualmente.")
        catalog.Set("识别状态：手动指定，保存时将验证路径。", "Estado da identificação: especificado manualmente; o caminho será validado ao salvar.")
        catalog.Set("识别状态：启动入口与监控目标一致。", "Estado da identificação: o ponto de inicialização e o destino monitorado são o mesmo.")
        catalog.Set("这些设置仅在小助手下次启动目标时生效，不会重启当前进程。", "Estas configurações entram em vigor na próxima vez que o assistente iniciar o destino e não reiniciam o processo que já está em execução.")
        catalog.Set("留空时使用快捷方式工作目录或程序所在目录。", "Deixe em branco para usar a pasta de trabalho do atalho ou a pasta do programa.")
        catalog.Set("留空时不附加额外参数。", "Deixe em branco para não acrescentar argumentos.")
        catalog.Set("留空时继承小助手当前环境。", "Deixe em branco para herdar o ambiente atual do assistente.")
        catalog.Set("工作目录不存在或不可访问：{1}", "A pasta de trabalho não existe ou não pode ser acessada: {1}")
        catalog.Set("工作目录无效", "Pasta de trabalho inválida")
        catalog.Set("环境变量第 {1} 行缺少等号（KEY=VALUE）。", "A linha {1} das variáveis de ambiente não contém o sinal de igual（KEY=VALUE）.")
        catalog.Set("环境变量第 {1} 行的名称无效：{2}", "A linha {1} das variáveis de ambiente contém um nome inválido: {2}")
        catalog.Set("环境变量第 {1} 行重复定义了 {2}。", "A linha {1} das variáveis de ambiente redefine {2}.")
        catalog.Set("环境变量配置无法解析。", "Não foi possível interpretar a configuração das variáveis de ambiente.")
        catalog.Set("环境变量配置无效", "Variáveis de ambiente inválidas")
        catalog.Set("设置已应用到当前运行，但暂未写入配置文件；小助手将在后台自动重试。", "As configurações já estão ativas nesta sessão, mas ainda não foram gravadas no arquivo de configuração. O assistente tentará novamente em segundo plano.")
        catalog.Set("配置暂未写入", "Configuração ainda não gravada")
        catalog.Set("已更新进程识别与启动设置：{1}", "Identificação do processo e configurações de inicialização atualizadas: {1}")
        catalog.Set("• 快捷方式：LNK、URL、APPREF-MS，包括可解析真实目标的 MSI 快捷方式。特殊快捷方式可在“进程识别与启动设置”中手动指定真实进程。", "• Atalhos: LNK, URL e APPREF-MS, inclusive atalhos MSI cujo destino real possa ser identificado. Em atalhos especiais, especifique manualmente o processo real em Identificação do processo e configurações de inicialização.")
        catalog.Set("• 右键守护对象可自定义主窗口名称和图标，也可打开所在位置、结束运行、编辑路径、切换管理员运行、配置进程识别与启动设置及软件升级保护，并查看批处理输出日志。“结束运行”会同时暂停守护，目标不会被自动重新启动；要求管理员运行但当前权限不符时仍会显示警告。", "• Clique com o botão direito em um item para personalizar nome e ícone, abrir o local, encerrar a execução, editar o caminho e configurar identificação, inicialização e proteção. Encerrar execução também pausa o monitoramento, portanto o alvo não será reiniciado automaticamente; permissões administrativas insuficientes continuarão sendo avisadas.")
        catalog.Set("添加", "Adicionar")
        catalog.Set("暂停", "Pausar")
        catalog.Set("恢复", "Retomar")
        catalog.Set("删除", "Excluir")
        catalog.Set("设置", "Configurações")
        catalog.Set("打赏", "Doar")
        catalog.Set("保存", "Salvar")
        catalog.Set("取消", "Cancelar")
        catalog.Set("反转状态", "Inverter status")
        catalog.Set("统计：运行", "Em execução")
        catalog.Set("统计：停止", "Parados")
        catalog.Set("统计：恢复", "Recuperando")
        catalog.Set("统计：升级", "Atualizando")
        catalog.Set("统计：暂停", "Pausados")
        catalog.Set("统计：失效", "Inválidos")
        catalog.Set("统计：总计", "Total")
        catalog.Set("配置未保存", "Configuração não salva")
        catalog.Set("创建", "Criar")
        catalog.Set("开启", "Ativar")
        catalog.Set("关闭", "Desativar")
        catalog.Set("切换", "Alternar")
        catalog.Set("冲突", "Conflito")
        catalog.Set("浏览", "Procurar")
        catalog.Set("监控配置", "Configuração de monitoramento")
        catalog.Set("管理员运行状态", "Executar como administrador")
        catalog.Set("调整守护顺序", "Reordenar lista de monitoramento")
        catalog.Set("编辑完整路径", "Editar caminho completo")
        catalog.Set("自定义名称和图标", "Personalizar nome e ícone")
        catalog.Set("已撤销：{1}", "Desfeito: {1}")
        catalog.Set("已重做：{1}", "Refeito: {1}")
        catalog.Set("Everything 搜索暂时不可用，请稍后重试。", "A pesquisa do Everything está temporariamente indisponível. Tente novamente em instantes.")
        catalog.Set("Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。", "O componente de pesquisa do Everything está ausente ou não pôde ser carregado. Extraia o assistente por completo ou reinstale-o.")
        catalog.Set("已找到 Everything，但无法后台启动，请手动启动后重试。", "O Everything foi encontrado, mas não pôde ser iniciado em segundo plano. Inicie-o manualmente e tente novamente.")
        catalog.Set("后台启动 Everything 失败：{1}", "Falha ao iniciar o Everything em segundo plano: {1}")
        catalog.Set("正在后台启动 Everything 并等待搜索服务就绪...", "Iniciando o Everything em segundo plano e aguardando o serviço de pesquisa ficar pronto...")
        catalog.Set("已在后台启动 Everything：{1}", "O Everything foi iniciado em segundo plano: {1}")
        catalog.Set("等待 Everything 搜索服务就绪超时：{1}", "O tempo de espera pelo serviço de pesquisa do Everything se esgotou: {1}")
        catalog.Set("未找到 Everything，点击前往官网下载最新版：{1}", "O Everything não foi encontrado. Clique para baixar a versão mais recente no site oficial: {1}")
        catalog.Set("本机未找到 Everything；程序搜索需要 Everything 后台服务。", "O Everything não foi encontrado neste computador; a pesquisa de programas precisa do serviço do Everything em segundo plano.")
        catalog.Set("• 程序搜索：使用 Everything 服务并显示全部匹配结果；未运行时会尝试在本机查找并后台启动，未找到时提供官网最新版下载地址。", "• Pesquisa de programas: usa o serviço do Everything e mostra todos os resultados correspondentes. Se o Everything não estiver em execução, o assistente o procura no computador e o inicia em segundo plano; se não o encontrar, oferece o link oficial para baixar a versão mais recente.")
        catalog.Set("• 小助手随包的 Everything64.dll 只是连接 Everything 后台实例的 SDK 客户端，不负责扫描磁盘或建立索引，不能替代 Everything 本体。", "• O Everything64.dll incluído com o assistente é apenas um cliente do SDK que se conecta à instância do Everything em segundo plano. Ele não examina discos, não cria o índice e não substitui o aplicativo Everything.")
        catalog.Set("六、进程识别与启动设置", "6. Identificação do processo e configurações de inicialização")
        catalog.Set("• 此设置只作用于当前守护对象，并将“用什么启动”和“用什么判断正在运行”分开处理。启动环境只在小助手下次启动目标时生效，不会重启当前进程。", "• Estas configurações se aplicam somente ao item monitorado atual e separam o modo de iniciá-lo das evidências usadas para determinar se ele está em execução. O ambiente de inicialização só entra em vigor na próxima vez que o assistente iniciar o destino e não reinicia o processo atual.")
        catalog.Set("• 直接添加程序或脚本时，启动入口与监控目标相同；EXE 按完整路径识别，脚本按宿主进程命令行中的脚本路径识别。", "• Quando um programa ou script é adicionado diretamente, a entrada de inicialização e o destino monitorado são o mesmo. Arquivos EXE são identificados pelo caminho completo; scripts, pelo caminho do script na linha de comando do processo hospedeiro.")
        catalog.Set("• 添加 LNK 快捷方式时，快捷方式始终作为启动入口；自动识别出的真实程序或脚本只用于判断运行状态。", "• Ao adicionar um atalho LNK, ele sempre permanece como entrada de inicialização. O programa ou script real identificado automaticamente é usado apenas para determinar o estado de execução.")
        catalog.Set("• 自动识别会综合快捷方式目标、参数、Windows Installer 信息、安装目录、文件版本信息和已观察进程；证据不唯一时不会随意绑定。", "• A identificação automática combina o destino e os argumentos do atalho, dados do Windows Installer, diretório de instalação, informações de versão do arquivo e processos observados. Ela não vincula um destino quando as evidências são ambíguas.")
        catalog.Set("• 自动结果不正确时改用“用户指定”，选择程序正常运行期间持续存在的主程序或脚本；不要选择启动器、更新器或短暂子进程。", "• Se o resultado automático estiver incorreto, escolha Especificado pelo usuário e selecione o programa principal ou o script que permanece ativo durante o funcionamento normal do aplicativo. Não selecione um iniciador, atualizador ou processo filho de curta duração.")
        catalog.Set("启动程序或解释器：", "Iniciador ou interpretador:")
        catalog.Set("留空时按目标类型自动启动；可选择 Python、AutoHotkey、PowerShell、Node.js、Java 等运行时。", "Deixe em branco para iniciar de acordo com o tipo de destino ou selecione um ambiente de execução como Python, AutoHotkey, PowerShell, Node.js ou Java.")
        catalog.Set("启动程序参数：", "Argumentos do iniciador:")
        catalog.Set("参数顺序为：启动程序参数、目标路径、目标参数；例如 Java 使用 -jar。", "A ordem é: argumentos do iniciador, caminho do destino e argumentos do destino. Por exemplo, use -jar com Java.")
        catalog.Set("目标参数（Args）：", "Argumentos do destino（Args）:")
        catalog.Set("留空时继承小助手当前环境；值中可用 %变量名% 引用已有环境变量。", "Deixe em branco para herdar o ambiente atual do assistente. Use %VARIÁVEL% em um valor para fazer referência a uma variável de ambiente existente.")
        catalog.Set("选择启动程序或解释器", "Escolher iniciador ou interpretador")
        catalog.Set("可执行程序", "Programas executáveis")
        catalog.Set("请先选择启动程序或解释器，再填写它的参数。", "Escolha um iniciador ou interpretador antes de informar seus argumentos.")
        catalog.Set("启动程序未设置", "Iniciador não definido")
        catalog.Set("启动程序或解释器不存在：{1}", "O iniciador ou interpretador não existe: {1}")
        catalog.Set("启动程序无效", "Iniciador inválido")
        catalog.Set("整条启动配置", "configuração de inicialização completa")
        catalog.Set("启动程序或解释器", "iniciador ou interpretador")
        catalog.Set("解释器参数", "argumentos do interpretador")
        catalog.Set("• 直接脚本可指定“启动程序或解释器”，选择实际执行脚本的可执行文件，例如 Python、AutoHotkey、PowerShell、Node.js、Ruby、Perl、PHP、Lua、Java 或 Bash；留空时沿用系统默认启动方式。", "• Para um script adicionado diretamente, Iniciador ou interpretador permite escolher o executável que realmente o executa, como Python, AutoHotkey, PowerShell, Node.js, Ruby, Perl, PHP, Lua, Java ou Bash. Deixe em branco para usar o método de inicialização padrão do sistema.")
        catalog.Set("• “启动程序参数”位于目标路径之前，“目标参数（Args）”位于目标路径之后。Java 可填写 -jar；PowerShell 可填写 -NoProfile -ExecutionPolicy Bypass -File。", "• Os Argumentos do iniciador são colocados antes do caminho do destino; os Argumentos do destino（Args）, depois. Para Java, use -jar; para PowerShell, você pode usar -NoProfile -ExecutionPolicy Bypass -File.")
        catalog.Set("• Python 虚拟环境请选择该环境的 Scripts\python.exe；其他语言也可选择项目要求的确切运行时版本。进程识别仍以目标脚本路径为准，不会误把解释器本身当成守护目标。", "• Para um ambiente virtual do Python, selecione o arquivo Scripts\python.exe desse ambiente. Em outras linguagens, você também pode escolher a versão exata do ambiente de execução exigida pelo projeto. A identificação do processo continua usando o caminho do script de destino, portanto o interpretador não será confundido com o destino monitorado.")
        catalog.Set("• 工作目录（CWD）用于解析相对路径；留空时使用快捷方式工作目录或目标所在目录。", "• O diretório de trabalho（CWD）é usado para resolver caminhos relativos. Se ficar em branco, será usado o diretório de trabalho do atalho ou o diretório do destino.")
        catalog.Set("• 环境变量每行填写一个 KEY=VALUE，只覆盖列出的变量；值中可用 %变量名% 引用已有环境变量。启动完成后小助手会恢复自身环境。", "• Informe uma variável de ambiente KEY=VALUE por linha. Somente as variáveis listadas são substituídas, e %VARIÁVEL% pode fazer referência a um valor existente. O assistente restaura seu próprio ambiente depois da inicialização.")
        catalog.Set("; AppN 与 [Apps] 中同名的守护对象一一对应，依次保存启动程序或解释器路径及其参数。", "; Cada AppN corresponde ao alvo monitorado de mesmo nome em [Apps] e armazena, nesta ordem, o caminho do iniciador ou interpretador e seus argumentos.")
        catalog.Set("; 两个字段均为 <HEX> 编码；留空时由小助手按目标类型使用默认启动方式。", "; Os dois campos usam codificação <HEX>. Quando estão vazios, o assistente usa o método de inicialização padrão para o tipo de destino.")
        catalog.Set("守护对象不能指向文件夹：{1}", "Um item monitorado não pode apontar para uma pasta: {1}")
        catalog.Set("自动识别目标新位置", "Identificar automaticamente o novo local do destino")
        catalog.Set("检测到的目标新位置已失效，请重新操作。", "O novo local detectado do destino não é mais válido. Tente novamente.")
        catalog.Set("已更新已更名的守护目标：{1} -> {2}", "O destino monitorado renomeado foi atualizado: {1} -> {2}")
        catalog.Set("守护目标内容迁移识别服务未能启动。", "Não foi possível iniciar o serviço de detecção de movimentação de conteúdo dos destinos monitorados.")
        catalog.Set("检测到守护目标可能已更名，等待用户确认：{1} -> {2}", "Um destino monitorado pode ter sido renomeado`; aguardando confirmação: {1} -> {2}")
        catalog.Set("确认窗口暂时无法显示，将稍后重试", "A janela de confirmação está temporariamente indisponível. Uma nova tentativa será feita em instantes.")
        catalog.Set("发现多个内容完全相同的迁移候选，已暂停自动迁移：{1}", "Foram encontrados vários candidatos com conteúdo idêntico`; a movimentação automática foi pausada: {1}")
        catalog.Set("检测到内容一致的守护目标新位置，等待用户确认：{1} -> {2}", "Novo local com conteúdo correspondente detectado`; aguardando confirmação: {1} -> {2}")
        catalog.Set("守护目标内容迁移识别异常：{1}", "Erro ao detectar a movimentação do conteúdo do destino: {1}")
        catalog.Set("等待确认目标新位置", "Aguardando confirmação do novo local do destino")
        catalog.Set("确认目标新位置", "Confirmar novo local do destino")
        catalog.Set("检测到守护目标可能已更名", "Um destino monitorado pode ter sido renomeado")
        catalog.Set("小助手找到了与原文件内容完全一致的新路径。确认后将更新守护目标，名称、图标和启动设置保持不变。", "O assistente encontrou um novo caminho cujo conteúdo é exatamente igual ao arquivo original. Ao confirmar, o destino monitorado será atualizado sem alterar nome, ícone ou configurações de inicialização.")
        catalog.Set("原路径：", "Caminho anterior:")
        catalog.Set("新路径：", "Novo caminho:")
        catalog.Set("识别依据：", "Evidência da identificação: ")
        catalog.Set("更新守护路径", "Atualizar caminho monitorado")
        catalog.Set("忽略", "Ignorar")
        catalog.Set("更新已更名的守护目标", "Atualizar destino monitorado renomeado")
        catalog.Set("• 直接添加的程序或脚本本身或上级目录被更名、跨目录或跨磁盘移动后，小助手会按文件大小筛选并以 SHA-256 内容哈希确认新路径；即使移动发生在小助手关闭期间也能识别。", "• Se um programa, script ou pasta superior for renomeado ou movido entre pastas ou unidades, o assistente filtra pelo tamanho e confirma o novo caminho com o hash SHA-256 do conteúdo, mesmo que a movimentação tenha ocorrido enquanto ele estava fechado.")
        catalog.Set("• 文件名、文件 ID 和目录监听不参与迁移判断。发现多个内容相同的副本或扫描未完整完成时不会猜测目标；确认后只更新守护路径，名称、图标和启动设置保持不变。", "• Nomes, IDs de arquivo e monitoramento de diretórios não participam da decisão. O assistente não adivinha quando há cópias idênticas ou a varredura está incompleta. A confirmação altera apenas o caminho monitorado e preserva nome, ícone e configurações de inicialização.")
        catalog.Set("; AppN 与 [Apps] 中同名的直接文件目标一一对应，依次保存文件大小和 SHA-256 内容哈希。", "; Cada entrada AppN corresponde ao arquivo monitorado diretamente com o mesmo nome em [Apps] e armazena o tamanho seguido do hash SHA-256 do conteúdo.")
        catalog.Set("; 此节由小助手自动维护，用于在文件或目录改名、跨目录或跨磁盘移动后确认内容未变；请勿手动编辑。", "; O assistente mantém esta seção automaticamente para confirmar que o conteúdo não mudou após renomeações ou movimentações entre pastas ou unidades. Não edite manualmente.")
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
        catalog.Set("🔄 重新启动", "🔄 Reiniciar")
        catalog.Set("点个 star 吧~", "Dê uma estrelinha para nós~")
        catalog.Set("⏳ 停止原进程...", "⏳ Encerrando o processo original...")
        catalog.Set("❌ 无法停止原进程", "❌ Não foi possível encerrar o processo original")
        catalog.Set("手动触发了重新启动：{1}", "Reinicialização acionada manualmente: {1}")
        catalog.Set("手动重启已取消，原进程未能停止：{1}", "A reinicialização manual foi cancelada porque não foi possível encerrar o processo original: {1}")
        catalog.Set("暂时无法查询进程状态，稍后重试手动重启：{1}", "Não é possível consultar o status do processo no momento`; a reinicialização manual será tentada mais tarde: {1}")
        catalog.Set("暂时无法重新启动", "Não é possível reiniciar no momento")
        catalog.Set("该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。", "Este software está sob proteção de atualização. Aguarde a atualização terminar ou encerre a espera em “Proteção de atualizações de software” antes de reiniciá-lo.")
        catalog.Set("• “重新启动”会先请求目标正常退出；超过设置时间后，是否强制终止由“停止策略”中的选项决定。", "• “Reiniciar” primeiro solicita que o destino seja encerrado normalmente. Se o tempo limite expirar, a opção em “Política de encerramento” determina se o processo será finalizado à força.")
        catalog.Set("查看版本、运行环境和项目入口", "Ver versão, ambiente de execução e links do projeto")
        catalog.Set("找作者对线", "Fale com o autor")
        return catalog
    }
}

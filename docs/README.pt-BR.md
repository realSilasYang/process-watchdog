<div align="center">
  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <strong>Português</strong> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Assistente de monitoramento de processos</h1>

  <p><strong>Mantenha aplicativos e automações essenciais funcionando com estabilidade todos os dias</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="Versão mais recente"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="Downloads no GitHub"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="Status da CI"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="Licença"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Compatível com Windows 10 e Windows 11">
  </p>

  <p>
    <a href="#visão-geral-da-interface">Interface</a> ·
    <a href="#guia-do-usuário">Guia do usuário</a> ·
    <a href="#3-estados-e-recuperação">Estados</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">Versões</a> ·
    <a href="./CHANGELOG.en.md">Alterações</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">Relatar um problema</a> ·
    <a href="#guia-do-desenvolvedor">Desenvolvimento</a>
  </p>
</div>

O Assistente de monitoramento de processos foi criado para aplicativos de desktop, scripts e atalhos que precisam permanecer ativos por longos períodos na sessão atual do Windows. Após um encerramento inesperado, ele restaura o alvo de forma automática e criteriosa, distinguindo uma parada confirmada de um estado temporariamente indeterminado para evitar inicializações incorretas ou duplicadas. Todas as decisões, configurações e informações de log permanecem no computador. O projeto é desenvolvido com AutoHotkey v2 x64 e oferece suporte ao Windows 10 e ao Windows 11.

O assistente não decide que um alvo está em execução apenas pelo nome do processo. Ele cruza o caminho completo, a identidade de criação do processo, o destino real do atalho e evidências da linha de comando. Quando faltam evidências, aguarda a próxima verificação em vez de tratar um estado desconhecido como parado.

O projeto oferece interface clara e escura, recuperação automática, proteção durante atualizações, log de execução, desfazer e refazer, nomes e ícones personalizados e um pacote Windows x64 com SBOM SPDX, somas SHA-256 e procedência da compilação.

# Visão geral da interface

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/process-watchdog-overview.png">
  <source media="(prefers-color-scheme: light)" srcset="images/process-watchdog-overview-light.png">
  <img src="images/process-watchdog-overview-light.png" alt="Janela principal nos temas claro e escuro" width="100%">
</picture>

A janela principal reúne a ordem dos itens monitorados, o ícone do aplicativo, o nome, os requisitos de privilégio e o estado atual. A barra superior permite adicionar, excluir, pausar, abrir as configurações, consultar a ajuda ou fazer uma doação; pela Ajuda é possível abrir o manual ou o log de execução. A barra inferior resume os alvos em execução, recuperação, atualização, pausa e falha, enquanto o log mostra as evidências por trás de cada estado anormal.

## Principais recursos

- Monitora alvos EXE, AHK, Python, JavaScript, PowerShell, BAT, CMD e LNK.
- Usa os resultados `Running`, `Stopped` e `Unknown`; um resultado desconhecido nunca causa uma reinicialização às cegas.
- Cada alvo recebe controlador, geração e tokens de tarefa próprios. Retornos antigos são invalidados imediatamente após pausar, excluir ou alterar o caminho.
- Pode exigir privilégios de administrador. Avisa quando uma instância em execução não cumpre o requisito e eleva uma reinicialização manual conforme a configuração.
- A proteção de atualização fica desativada por padrão. Quando ativada, combina processos de atualização, relações pai-filho, atividade da pasta de instalação e estabilidade dos arquivos antes de pausar ou retomar o monitoramento.
- Substitui a configuração de forma atômica. Registros que não podem ser analisados vão para `[Recovery]` em vez de desaparecer silenciosamente.
- A busca de aplicativos usa exclusivamente o serviço Everything, sem varredura local de todo o disco nem limite de resultados imposto pelo aplicativo. Conjuntos grandes são adicionados em lotes curtos para que a extração de ícones não bloqueie a interface.
- Oferece chinês simplificado, chinês tradicional de Hong Kong, chinês tradicional de Taiwan, inglês, japonês, vietnamita, coreano, espanhol, francês, português do Brasil, russo, alemão e italiano. A interface segue o idioma do Windows por padrão, usa inglês quando o idioma não é compatível e também pode ser escolhida em Geral. Alterações de idioma e fonte de conteúdo entram em vigor imediatamente no processo atual sem interromper nem reinicializar as tarefas de monitoramento.
- Em “Seguir o padrão do idioma”, prioriza PingFang, SF Pro Text, Harano Aji Gothic ou Apple SD Gothic Neo. Quando ausentes, carrega de forma privada o recurso incluído com licença comercial ou OFL e depois recorre à família Noto correspondente. A fonte de conteúdo vale para texto, campos, listas e informações Sobre; botões, abas e a barra inferior sempre usam a fonte de interface do Windows em negrito adequada ao idioma.
- Os temas claro e escuro oferecem minimização independente das janelas secundárias, reconstrução de ícones conforme o DPI, botões arredondados e ícones personalizados.
- O pacote de diagnóstico é gerado apenas localmente e não é enviado de forma automática; os artefatos oficiais podem ser verificados de maneira independente.

## Escopo

É indicado para aplicativos, scripts e atalhos comuns que devem continuar ativos na sessão de desktop atual do Windows e ser recuperados após um encerramento inesperado. Não fazem parte do escopo:

- Serviços do Windows, drivers, componentes do kernel ou serviços entre sessões de usuário.
- Windows 7, Windows de 32 bits e plataformas que não sejam Windows.
- Sistemas de tempo real rígido, clusters de alta disponibilidade ou orquestração de processos que exija isolamento de segurança.
- Políticas agressivas que forcem qualquer estado desconhecido a significar “parado”.

A matriz física de escala de exibição atualmente testada cobre 100% a 200%. Outros fatores e alterações contínuas de DPI entre monitores não podem ser considerados verificados apenas pelo código. Consulte [Compatibilidade e limitações conhecidas](en/compatibility.md).

---

**[Guia do usuário](#guia-do-usuário)**<br>
[Instalação](#1-instalação-e-primeira-execução) · [Gerenciamento](#2-adicionar-e-gerenciar-itens) · [Estados](#3-estados-e-recuperação) · [Atualizações](#4-proteção-durante-atualizações) · [Configurações](#5-configurações) · [Logs](#6-logs-diagnóstico-e-privacidade)

**[Guia do desenvolvedor](#guia-do-desenvolvedor)**<br>
[Pastas](#1-pastas-e-responsabilidades) · [Correção](#2-limites-de-correção) · [Verificação](#3-comandos-de-verificação) · [Publicação](#4-publicação-e-contribuição)

# Apoie o projeto

O Assistente de monitoramento de processos continuará sendo código aberto. Sua manutenção de longo prazo depende do apoio e do incentivo da comunidade. Se ele poupou seu tempo ao diagnosticar falhas ou recuperar aplicativos, você pode fazer uma doação voluntária por um dos códigos QR abaixo. As contribuições financiam a manutenção, os testes de compatibilidade e as próximas versões.

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="Código QR para doação via WeChat Pay">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Código QR para doação via Alipay">
</p>

# Guia do usuário

## 1. Instalação e primeira execução

1. Escolha em [Releases](https://github.com/realSilasYang/process-watchdog/releases) uma das três edições: EXE independente, ZIP portátil completo ou ZIP completo do código-fonte.
2. O EXE independente dispensa o AutoHotkey; o ZIP portátil é indicado para uso permanente; o ZIP do código-fonte requer AutoHotkey v2 x64.
3. Execute `进程守护小助手.exe`. O aplicativo solicitará privilégios de administrador e, conforme a configuração, mostrará a janela principal ou ficará na área de notificação.
4. Selecione Adicionar para escolher um alvo ou arraste arquivos compatíveis para a janela principal.
5. Abra o Log para ver as evidências de identidade, as verificações de estado, as tentativas de recuperação e os sinais de atualização usados de fato.

Para executar pelo código-fonte, instale o AutoHotkey v2 x64 e abra `进程守护小助手.ahk`. Ao clonar o repositório com Git, instale também o Git LFS e execute `git lfs pull` para obter os arquivos de fontes completos, em vez de ponteiros LFS. O ZIP de código-fonte anexado ao Release já contém esses recursos e não precisa do Git LFS. As versões oficiais incorporam o runtime do AutoHotkey aprovado em todos os testes de publicação, portanto usuários comuns não precisam instalá-lo separadamente.

### Versões e formas de execução

| Componente | Edição EXE | Edição de código-fonte |
| --- | --- | --- |
| Assistente | Lê a versão do arquivo EXE; a atualização substitui o pacote completo | Lê `VERSION` ao lado do ponto de entrada; atualização por avanço rápido seguro do Git ou pacote-fonte |
| AutoHotkey | Incorporado e atualizado com um pacote completo posterior do assistente | Usa o interpretador local; atualizar o assistente não atualiza o AutoHotkey |
| Ahk2Exe | Usado apenas para produzir o EXE oficial e nunca instalado no computador do usuário | Desnecessário |

“O assistente está atualizado” e “o AutoHotkey local está atualizado” são afirmações diferentes. No início de cada publicação oficial, o fluxo seleciona a versão estável mais recente do AutoHotkey e a versão publicada mais recente do Ahk2Exe, congela essa escolha e executa todos os testes antes de incorporar o AutoHotkey. Configurações do assistente → Sobre mostra a versão do assistente, o formato EXE/fonte e a versão real do AutoHotkey, além da verificação manual. Consulte [Versões, formas de execução e responsabilidades](en/versioning.md).

Fechar a janela principal apenas a oculta na área de notificação; o monitoramento continua. Use Sair no menu da área de notificação para encerrar de verdade. Consulte [Instalação, atualização e remoção](en/installation.md) para atalhos, inicialização agendada e atualizações.

## 2. Adicionar e gerenciar itens

| Botão | Função |
| --- | --- |
| Adicionar | Escolher um alvo, buscar aplicativos instalados ou importar uma pasta; inclui subpastas por padrão |
| Excluir | Remover os itens selecionados; aceita seleção múltipla e desfazer |
| Pausar / Retomar | Alterar apenas o monitoramento automático sem fechar o alvo ativo; uma seleção mista é invertida item a item |
| Configurações | Configurar Geral, Monitoramento e inicialização, Política de parada, Logs e Sobre |
| Ajuda | Escolher o manual integrado, o log de execução ou a página de comentários no GitHub |
| Doar | Mostrar os códigos QR do WeChat Pay e do Alipay que apoiam a manutenção |

Um item pode definir seu ponto de entrada, pasta de trabalho, argumentos e exigência de administrador. O LNK permanece como ponto de entrada e o caminho real do programa é armazenado separadamente para identificar o processo. Assim, um atalho indireto criado pelo instalador não precisa ser substituído manualmente por um EXE interno que pode mudar.

O menu de contexto permite abrir a pasta, reiniciar, mudar o caminho, configurar a identificação do processo e a inicialização, alternar a exigência de administrador, configurar a proteção e personalizar o nome ou ícone exibido apenas na janela principal. A apresentação não muda a identidade, a inicialização nem a proteção. Se a exibição já for a padrão, a restauração fica desativada.

Somente itens BAT e CMD exibem também a opção Ver log de saída em lote; os demais tipos de alvo não mostram esse comando. O arquivo de log separado só é criado quando o assistente realmente inicia o item e captura sua saída padrão e de erro. Um processo em lote que já estava em execução não recebe esse arquivo automaticamente.

Arraste as linhas para reordenar; a ordem é salva. `Ctrl+Z`, `Ctrl+Y` e `Ctrl+Shift+Z` desfazem ou refazem adições, exclusões, ordenação e mudanças de configuração. O número à esquerda é recriado conforme a ordem visível e não participa da identidade, inicialização nem persistência. Consulte [Cenários comuns](en/quick-start.md).

## 3. Estados e recuperação

O estado da lista descreve as evidências disponíveis e a próxima ação. Não conclua o resultado apenas pela cor do ícone.

| Estado | Significado |
| --- | --- |
| Em execução | Foi encontrada uma instância ativa correspondente à identidade do alvo |
| Em execução (privilégio incompatível) | A instância existe, mas não cumpre a exigência de administrador |
| Aguardando estado / Possivelmente parado | As evidências são insuficientes ou uma saída acabou de ocorrer; nova verificação sem lançamento duplicado |
| Iniciando / Contagem regressiva | A recuperação foi confirmada e a próxima tentativa segue a sequência de espera |
| Atualizando / Confirmando estabilidade | O início automático aguarda o fim da atividade e a estabilidade dos arquivos |
| Pausado | Verificações e recuperação automáticas estão pausadas sem fechar o processo-alvo |
| Parado / Falha ao iniciar / Tempo esgotado | A recuperação falhou ou requer confirmação; o log informa as evidências e o motivo |

Os atrasos padrão são 1, 10 e 60 segundos. Após a sequência rápida, o último atraso é reutilizado para evitar um ciclo intenso de inicializações. Excluir, pausar, mudar um caminho ou desfazer invalida tarefas agendadas e resultados assíncronos antigos.

## 4. Proteção durante atualizações

A proteção fica desativada por padrão e precisa ser habilitada para cada item:

1. Clique com o botão direito no alvo e abra Proteção durante atualizações.
2. Ative a detecção automática e a proteção da inicialização.
3. Verifique a área de instalação, a janela de detecção de saída, a espera de estabilidade e a espera máxima.
4. Salve e deixe o aplicativo fazer uma atualização real normalmente. O assistente combina processos de atualização, relações pai-filho, atividade de pastas, notificações de arquivo e características aprendidas para decidir quando iniciar a proteção.

Depois que a atualização é confirmada, a inicialização automática fica suspensa. O monitoramento normal só volta quando a atividade termina e os arquivos ficam estáveis. Se a detecção expirar ou não corresponder à realidade, use Encerrar espera e retomar monitoramento. A segurança do ponto de entrada ainda é verificada antes da recuperação.

O recurso não é um instalador universal nem um gerenciador de serviços do Windows. Para aplicativos portáteis, atualizadores fora da pasta ou inicializadores incomuns, consulte primeiro o log e então ajuste a área e as regras.

## 5. Configurações

| Categoria | Opções |
| --- | --- |
| Geral | Atalhos na Área de Trabalho e no menu Iniciar, inicialização agendada, dois comportamentos ao iniciar, idioma, fonte do conteúdo e tema |
| Monitoramento e inicialização | Intervalo de estado do processo, sequência de atrasos após falha e inclusão de subpastas na importação |
| Política de parada | Tempos para fechar aplicativos GUI/CLI e permissão para encerramento forçado após o limite |
| Logs | Limpeza ao iniciar, limite de exibição, dias de retenção do log em lote e pasta de salvamento |
| Sobre | Versões do aplicativo e ambiente, verificação imediata e link do projeto aberto |

A janela valida os intervalos numéricos. Os comentários de `watchdog.ini` ficam junto das seções e opções correspondentes; prefira a interface para não danificar campos codificados. Consulte [Configuração, backup e recuperação](en/configuration.md).

## 6. Logs, diagnóstico e privacidade

O Log de execução permite selecionar e copiar texto, maximizar e redimensionar a janela. As barras de rolagem aparecem apenas quando necessárias e o texto não pode ser editado.

Para um problema difícil, exporte um pacote de diagnóstico local pela janela do log. Ele contém resumos do aplicativo, Windows, AutoHotkey, DPI, identificadores de recurso, fase de monitoramento, avisos de configuração e log atual, sem upload automático.

A configuração pessoal fica em `watchdog.ini` ao lado do programa e sessões de atualização inacabadas em `watchdog.maintenance.ini`. O Git ignora ambos e nenhuma versão os inclui ou sobrescreve. `config/watchdog.example.ini` apenas documenta campos e padrões atuais.

O EXE e o código-fonte usam a pasta do próprio ponto de entrada como diretório de configuração. Juntos, compartilham os dois arquivos; em pastas distintas, ficam independentes. Um bloqueio de instância única em todo o sistema impede a execução simultânea. Atalhos e tarefa agendada apontam para a forma que criou ou alterou a integração por último, portanto escolha um único ponto de entrada diário por pasta. Para manter duas instalações com atualização independente, use pastas diferentes. Consulte [Configuração, backup e recuperação](en/configuration.md) e [Instalação, atualização e remoção](en/installation.md).

Logs podem conter caminhos, argumentos ou variáveis de ambiente. Revise e oculte dados sensíveis antes de publicar. Use os [formulários estruturados de Issue](https://github.com/realSilasYang/process-watchdog/issues/new/choose) para relatos comuns e o canal privado para vulnerabilidades ainda não corrigidas. Consulte [Diagnóstico local](en/diagnostics.md), [Solução de problemas](en/troubleshooting.md) e [Suporte](../.github/SUPPORT.en.md).

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# Guia do desenvolvedor

## 1. Pastas e responsabilidades

```text
process-watchdog/
├─ .github/                 formulários de Issue, fluxos e modelos de colaboração
├─ app/                     estado do aplicativo, integração da interface e janelas
├─ assets/                  ícones, imagens de doação e fontes privadas do processo
├─ config/                  exemplo atual com comentários junto às opções
├─ docs/                    documentação de usuário, arquitetura, idiomas, imagens e governança
├─ src/                     configuração, núcleo, diagnóstico, execução, inspeção, atualização, plataforma e UI
├─ runtime/                 auxiliar de atualização em segundo plano para EXE e fonte
├─ tests/                   verificações do núcleo, GUI, versão e repositório
├─ third_party/             DLLs, licenças e manifestos de dependências fixados
├─ tools/                   compilação, SBOM, verificação e preparação de ferramentas
└─ 进程守护小助手.ahk      raiz de composição e ponto de início
```

O script raiz apenas inclui módulos, monta dependências e inicia o aplicativo. `src` não lê as variáveis globais `App`, `Main` ou `GuiModules`; `app` conecta o núcleo puro às janelas, logs e operações do sistema. Consulte [Arquitetura e limites de correção](en/architecture.md).

## 2. Limites de correção

- Identidade do alvo, ponto de entrada e apresentação personalizada são independentes; a apresentação não pode alterar decisões de monitoramento.
- `Running`, `Stopped` e `Unknown` são resultados de evidências externas; a recuperação só começa após confirmar a parada.
- Cada temporizador, callback, observador, processo de trabalho, janela e recurso nativo precisa de limpeza idempotente.
- Instantâneos de configuração, itens e proteção são confirmados na mesma transação; testes não podem ler nem sobrescrever o `watchdog.ini` pessoal.
- A rolagem suave descartada por sobreposição de capturas GDI não deve voltar; ListView e log mantêm a rolagem nativa.
- Declarações sobre DPI, ícones, modo escuro, hierarquia e acessibilidade exigem provas reais no Windows; automação não substitui uma matriz física.

## 3. Comandos de verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-gui-tests.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

`verify.ps1` verifica hashes, análise AHK, restrições de arquitetura, testes do núcleo, limites do repositório, vazamentos no histórico Git, sintaxe dos fluxos e inicialização. `run-gui-tests.ps1` cria controles Windows reais e verifica troca imediata entre 13 idiomas e fontes, três níveis de janela e liberação de identificadores GDI/USER. `reproducible-build.ps1` gera duas vezes os pacotes EXE, fonte e SBOM e compara as somas.

AutoHotkey e Ahk2Exe não são fixados previamente no repositório. Cada publicação manual consulta a versão estável mais recente do AutoHotkey e a versão publicada mais recente do Ahk2Exe, congela uma única resolução e usa exatamente a mesma nos testes, nas duas compilações, no SBOM e no pacote. Ferramentas de validação como actionlint e Gitleaks continuam fixadas. A versão registra as versões, fontes, commits e SHA-256 reais. Consulte [Avisos de terceiros](project/THIRD_PARTY_NOTICES.en.md).

## 4. Publicação e contribuição

Toda alteração visível deve atualizar cada README localizado e o histórico. Use o [modelo de changelog](en/changelog-template.md) em novas versões e descreva adições, melhorias e correções observáveis, não mensagens de commit ou nomes de classes internas.

Consulte o [processo de publicação](en/release-process.md) e a [lista de verificação pública](en/publication-checklist.md). Um Pull Request comum não deve criar tags de versão nem reescrever tags publicadas. Issues e Pull Requests devem incluir reprodução, risco e evidências; para janelas, DPI, ícones ou modo escuro, informe também a versão real do Windows e a escala testada. Consulte [Como contribuir](../.github/CONTRIBUTING.en.md) e [Governança](project/GOVERNANCE.en.md).

O código é publicado sob a [MIT License](../LICENSE). Componentes integrados mantêm suas licenças; o pacote inclui a licença do AutoHotkey e o arquivo-fonte correspondente. PingFang, SF Pro Text e Apple SD Gothic Neo são distribuídas sob autorização comercial do proprietário do projeto e não fazem parte da MIT License.

<div align="center">
  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <strong>Italiano</strong></p>

  <h1>Assistente di sorveglianza dei processi</h1>

  <p><strong>Mantieni stabili ogni giorno le applicazioni e le automazioni essenziali</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="Ultima versione"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="Download da GitHub"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="Stato CI"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="Licenza"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Compatibile con Windows 10 e Windows 11">
  </p>

  <p>
    <a href="#panoramica-dellinterfaccia">Interfaccia</a> ·
    <a href="#guida-per-lutente">Guida utente</a> ·
    <a href="#3-stati-e-ripristino">Stati</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">Versioni</a> ·
    <a href="./CHANGELOG.en.md">Novità</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">Segnala un problema</a> ·
    <a href="#guida-per-gli-sviluppatori">Sviluppo</a>
  </p>
</div>

L’Assistente di sorveglianza dei processi è pensato per applicazioni desktop, script e collegamenti che devono rimanere disponibili a lungo nella sessione Windows corrente. Dopo un arresto imprevisto ripristina automaticamente e con prudenza la destinazione, distinguendo un arresto confermato da uno stato temporaneamente indeterminato per evitare avvii errati o duplicati. Decisioni, impostazioni e registri restano tutti sul computer locale. Il progetto è realizzato con AutoHotkey v2 x64 e supporta Windows 10 e Windows 11.

L’assistente non stabilisce che una destinazione è in esecuzione basandosi solo sul nome del processo. Incrocia il percorso completo, l’identità di creazione del processo, la destinazione reale del collegamento e gli elementi della riga di comando. Se le prove non bastano, attende il controllo successivo invece di trattare uno stato sconosciuto come arrestato.

Il progetto offre interfaccia chiara e scura, ripristino automatico, protezione durante gli aggiornamenti, registro di esecuzione, annulla e ripristina, nomi e icone personalizzati e un pacchetto Windows x64 con SBOM SPDX, checksum SHA-256 e provenienza della compilazione.

# Panoramica dell’interfaccia

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/process-watchdog-overview.png">
  <source media="(prefers-color-scheme: light)" srcset="images/process-watchdog-overview-light.png">
  <img src="images/process-watchdog-overview-light.png" alt="Finestra principale nei temi chiaro e scuro" width="100%">
</picture>

La finestra principale riunisce l’ordine degli elementi sorvegliati, l’icona dell’app, il nome, i privilegi richiesti e lo stato corrente. La barra superiore consente di aggiungere, eliminare, sospendere, aprire le impostazioni, consultare l’aiuto o fare una donazione; da Aiuto si possono aprire il manuale e il registro di esecuzione. La barra inferiore riepiloga le destinazioni in esecuzione, ripristino, aggiornamento, pausa ed errore, mentre il registro espone le prove alla base di ciascuno stato anomalo.

## Funzioni principali

- Sorveglia destinazioni EXE, AHK, Python, JavaScript, PowerShell, BAT, CMD e LNK.
- Usa i risultati `Running`, `Stopped` e `Unknown`; uno stato sconosciuto non provoca mai un riavvio alla cieca.
- Ogni destinazione dispone di controller, generazione e token di attività indipendenti. I vecchi callback diventano subito invalidi dopo una pausa, eliminazione o modifica del percorso.
- Può richiedere privilegi di amministratore. Segnala un’istanza attiva con privilegi insufficienti e innalza un riavvio manuale secondo la configurazione.
- La protezione degli aggiornamenti è disattivata per impostazione predefinita. Quando è attiva, combina processi di aggiornamento, relazioni padre-figlio, attività della cartella di installazione e stabilità dei file prima di sospendere o riprendere la sorveglianza.
- Sostituisce la configurazione in modo atomico. I record non analizzabili vengono spostati in `[Recovery]` anziché scartati in silenzio.
- La ricerca delle applicazioni usa esclusivamente il servizio Everything, senza scansione locale dell’intero disco né limite di risultati imposto dall’app. I gruppi grandi vengono aggiunti in piccoli lotti per evitare che l’estrazione delle icone blocchi l’interfaccia.
- Supporta cinese semplificato, cinese tradizionale di Hong Kong, cinese tradizionale di Taiwan, inglese, giapponese, vietnamita, coreano, spagnolo, francese, portoghese brasiliano, russo, tedesco e italiano. Per impostazione predefinita segue la lingua di Windows, torna all’inglese per una lingua non supportata e può essere scelta in Generale. Le modifiche a lingua e carattere dei contenuti si applicano immediatamente al processo corrente senza arrestare o reinizializzare le attività di sorveglianza.
- Con «Segui il valore predefinito della lingua» vengono preferiti PingFang, SF Pro Text, Harano Aji Gothic o Apple SD Gothic Neo. Se assenti, viene caricata privatamente la risorsa inclusa con licenza commerciale o OFL, poi la famiglia Noto corrispondente. Il carattere dei contenuti si applica a testo, campi, elenchi e informazioni; pulsanti, schede e barra inferiore usano sempre il carattere dell’interfaccia Windows in grassetto adatto alla lingua.
- I temi chiaro e scuro consentono la riduzione indipendente delle finestre secondarie, la ricostruzione delle icone in base al DPI, pulsanti arrotondati e icone personalizzate.
- Il pacchetto diagnostico viene creato solo in locale e non è caricato automaticamente; gli artefatti ufficiali possono essere verificati in modo indipendente.

## Ambito

È adatto ad applicazioni, script e collegamenti comuni che devono restare attivi nella sessione desktop Windows corrente e riprendersi dopo un arresto imprevisto. Non rientrano nell’ambito:

- Servizi Windows, driver, componenti del kernel o servizi tra sessioni utente.
- Windows 7, Windows a 32 bit e piattaforme diverse da Windows.
- Sistemi hard real-time, cluster ad alta disponibilità o orchestrazione dei processi che richieda isolamento di sicurezza.
- Politiche aggressive che forzino qualsiasi stato sconosciuto a significare «arrestato».

La matrice fisica di ridimensionamento attualmente verificata copre dal 100% al 200%. Altri fattori e i cambi continui di DPI tra monitor non possono essere considerati verificati solo dal codice. Consulta [Compatibilità e limitazioni note](en/compatibility.md).

---

**[Guida per l’utente](#guida-per-lutente)**<br>
[Installazione](#1-installazione-e-primo-avvio) · [Gestione](#2-aggiungere-e-gestire-elementi) · [Stati](#3-stati-e-ripristino) · [Aggiornamenti](#4-protezione-durante-gli-aggiornamenti) · [Impostazioni](#5-impostazioni) · [Registri](#6-registri-diagnostica-e-riservatezza)

**[Guida per gli sviluppatori](#guida-per-gli-sviluppatori)**<br>
[Cartelle](#1-cartelle-e-responsabilità) · [Correttezza](#2-limiti-di-correttezza) · [Verifica](#3-comandi-di-verifica) · [Pubblicazione](#4-pubblicazione-e-contributi)

# Sostieni il progetto

L’Assistente di sorveglianza dei processi resterà open source. La sua manutenzione a lungo termine dipende dal sostegno e dall’incoraggiamento della comunità. Se ti ha fatto risparmiare tempo nella diagnosi o nel ripristino di applicazioni, puoi fare una donazione volontaria con uno dei codici QR seguenti. I contributi finanziano manutenzione, test di compatibilità e nuove versioni.

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="Codice QR per donazione WeChat Pay">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Codice QR per donazione Alipay">
</p>

# Guida per l’utente

## 1. Installazione e primo avvio

1. Scegli in [Releases](https://github.com/realSilasYang/process-watchdog/releases) una delle tre edizioni: EXE autonomo, ZIP portatile completo o ZIP completo del codice sorgente.
2. L’EXE autonomo non richiede AutoHotkey; lo ZIP portatile è adatto all’uso continuativo; lo ZIP del codice sorgente richiede AutoHotkey v2 x64.
3. Avvia `进程守护小助手.exe`. L’app richiede i privilegi di amministratore e, secondo le impostazioni, mostra la finestra principale oppure resta nell’area di notifica.
4. Seleziona Aggiungi per scegliere una destinazione oppure trascina un file supportato nella finestra principale.
5. Apri il Registro per vedere le prove di identità, i controlli di stato, i tentativi di ripristino e i segnali di aggiornamento effettivamente usati.

Per avviare il codice sorgente, installa AutoHotkey v2 x64 ed esegui `进程守护小助手.ahk`. Se cloni il repository con Git, installa anche Git LFS ed esegui `git lfs pull` per ottenere i file dei font completi anziché i puntatori LFS. Lo ZIP del codice sorgente allegato a ogni release contiene già queste risorse e non richiede Git LFS. Le versioni ufficiali incorporano il runtime AutoHotkey che ha superato tutti i test di pubblicazione, quindi un utente normale non deve installarlo separatamente.

### Versioni e modalità di esecuzione

| Componente | Edizione EXE | Edizione sorgente |
| --- | --- | --- |
| Assistente | Legge la versione del file EXE; un aggiornamento sostituisce il pacchetto completo | Legge `VERSION` accanto al punto di ingresso; aggiornamento tramite avanzamento rapido Git sicuro o pacchetto sorgente |
| AutoHotkey | Incorporato e aggiornato con una successiva versione completa dell’assistente | Usa l’interprete locale; aggiornare l’assistente non aggiorna AutoHotkey |
| Ahk2Exe | Usato solo per produrre l’EXE ufficiale e mai installato nei computer degli utenti | Non necessario |

«L’assistente è aggiornato» e «AutoHotkey locale è aggiornato» sono affermazioni diverse. All’inizio di ogni pubblicazione ufficiale, il flusso sceglie l’ultima versione stabile di AutoHotkey e l’ultima versione pubblicata di Ahk2Exe, congela la scelta ed esegue tutti i test prima di incorporare AutoHotkey. Impostazioni dell’assistente → Informazioni mostra versione dell’assistente, formato EXE/sorgente e versione reale di AutoHotkey, oltre al controllo manuale degli aggiornamenti. Consulta [Versioni, modalità di esecuzione e responsabilità](en/versioning.md).

Chiudere la finestra principale la nasconde soltanto nell’area di notifica; la sorveglianza continua. Usa Esci dal menu dell’area di notifica per arrestare completamente l’app. Consulta [Installazione, aggiornamento e rimozione](en/installation.md) per collegamenti, avvio pianificato e aggiornamenti.

## 2. Aggiungere e gestire elementi

| Pulsante | Funzione |
| --- | --- |
| Aggiungi | Scegliere una destinazione, cercare app installate o importare una cartella; le sottocartelle sono incluse per impostazione predefinita |
| Elimina | Rimuovere gli elementi selezionati; supporta selezione multipla e annullamento |
| Sospendi / Riprendi | Cambiare solo la sorveglianza automatica senza chiudere la destinazione attiva; una selezione mista viene invertita elemento per elemento |
| Impostazioni | Configurare Generale, Sorveglianza e avvio, Criteri di arresto, Registri e Informazioni |
| Aiuto | Scegliere il manuale integrato, il registro di esecuzione o la pagina dei commenti GitHub |
| Dona | Mostrare i codici QR WeChat Pay e Alipay che sostengono la manutenzione |

Un elemento può definire punto di ingresso, cartella di lavoro, argomenti e requisito di amministratore. Il file LNK resta il punto di ingresso e il percorso reale del programma viene memorizzato separatamente per identificare il processo. Non serve quindi sostituire manualmente un collegamento indiretto dell’installatore con un EXE interno soggetto a cambiamenti.

Il menu contestuale permette di aprire la posizione, riavviare, cambiare il percorso, configurare l’identificazione del processo e le impostazioni di avvio, alternare il requisito di amministratore, configurare la protezione e personalizzare nome o icona mostrati solo nella finestra principale. La presentazione non modifica identità, avvio o protezione. Se è già predefinita, il ripristino è disabilitato.

Solo gli elementi BAT e CMD mostrano anche il comando Visualizza registro di output batch; per gli altri tipi di destinazione non compare. Il file di registro separato viene creato soltanto quando l’assistente avvia realmente l’elemento e ne acquisisce l’output standard e quello di errore. Un processo batch già in esecuzione non riceve automaticamente questo file.

Trascina le righe per riordinarle; l’ordine viene salvato. `Ctrl+Z`, `Ctrl+Y` e `Ctrl+Shift+Z` annullano o ripristinano aggiunte, eliminazioni, ordinamento e modifiche. Il numero a sinistra viene rigenerato in base all’ordine visibile e non partecipa a identità, avvio o persistenza. Consulta [Scenari comuni](en/quick-start.md).

## 3. Stati e ripristino

Lo stato nell’elenco descrive le prove disponibili e l’azione successiva. Non dedurre il risultato solo dal colore dell’icona.

| Stato | Significato |
| --- | --- |
| In esecuzione | È stata trovata un’istanza attiva corrispondente all’identità della destinazione |
| In esecuzione (privilegi non conformi) | L’istanza esiste ma non soddisfa il requisito di amministratore |
| In attesa dello stato / Possibile arresto | Le prove sono insufficienti o l’uscita è appena avvenuta; nuovo controllo senza avvio duplicato |
| Avvio / Conto alla rovescia | Il ripristino è confermato e il prossimo tentativo segue la sequenza di attesa |
| Aggiornamento / Verifica stabilità | L’avvio automatico attende la fine dell’attività e la stabilità dei file |
| In pausa | I controlli e il ripristino automatici sono sospesi senza chiudere il processo di destinazione |
| Arrestato / Avvio non riuscito / Tempo scaduto | Il ripristino non è riuscito o richiede conferma; il registro mostra prove e motivo |

I ritardi predefiniti sono 1, 10 e 60 secondi. Esaurita la sequenza rapida, l’ultimo valore viene riutilizzato per evitare un ciclo serrato di avvii. Eliminare, sospendere, cambiare un percorso o annullare invalida vecchie attività e risultati asincroni.

## 4. Protezione durante gli aggiornamenti

La protezione è disattivata per impostazione predefinita e va abilitata per ogni elemento:

1. Fai clic destro sulla destinazione e apri Protezione aggiornamenti.
2. Attiva il riconoscimento automatico e la protezione dell’avvio.
3. Controlla l’area di installazione, la finestra di rilevamento dell’uscita, l’attesa di stabilità e l’attesa massima.
4. Salva e lascia che l’app esegua normalmente un vero aggiornamento. L’assistente combina processi di aggiornamento, relazioni padre-figlio, attività delle cartelle, notifiche dei file e caratteristiche apprese per decidere l’avvio della protezione.

Dopo la conferma, l’avvio automatico resta sospeso. La sorveglianza normale riprende solo quando l’attività termina e i file sono stabili. Se il rilevamento scade o non corrisponde alla realtà, usa Termina attesa e riprendi sorveglianza. La sicurezza del punto di ingresso viene comunque ricontrollata prima del ripristino.

La funzione non è un installatore universale né un gestore di servizi Windows. Per app portatili, updater esterni alla cartella o launcher insoliti, consulta prima il registro e poi adatta area e regole.

## 5. Impostazioni

| Categoria | Opzioni |
| --- | --- |
| Generale | Collegamenti Desktop e menu Start, avvio pianificato, due comportamenti all’avvio, lingua, carattere dei contenuti e tema |
| Sorveglianza e avvio | Intervallo di stato del processo, sequenza di ritardi dopo un arresto anomalo e inclusione delle sottocartelle nell’importazione |
| Criteri di arresto | Tempi per chiudere app GUI/CLI e autorizzazione alla terminazione forzata dopo la scadenza |
| Registri | Pulizia all’avvio, limite di visualizzazione, giorni di conservazione dei registri in batch e percorso di salvataggio |
| Informazioni | Versioni dell’app e dell’ambiente, controllo immediato e collegamento al progetto open source |

La finestra convalida gli intervalli numerici. I commenti di `watchdog.ini` sono accanto alle sezioni e opzioni corrispondenti; preferisci l’interfaccia per non danneggiare i campi codificati. Consulta [Configurazione, backup e ripristino](en/configuration.md).

## 6. Registri, diagnostica e riservatezza

Il Registro di esecuzione consente di selezionare e copiare testo, massimizzare e ridimensionare la finestra. Le barre di scorrimento compaiono solo quando necessarie e il testo non è modificabile.

Per un problema difficile, esporta un pacchetto diagnostico locale dal registro. Contiene riepiloghi di app, Windows, AutoHotkey, DPI, handle delle risorse, fase di sorveglianza, avvisi di configurazione e registro corrente, senza caricamento automatico.

La configurazione personale è in `watchdog.ini` accanto al programma e le sessioni di aggiornamento non concluse in `watchdog.maintenance.ini`. Git ignora entrambi e nessuna release li include o sovrascrive. `config/watchdog.example.ini` documenta soltanto campi e valori predefiniti correnti.

L’EXE e il sorgente usano la cartella del proprio punto di ingresso come directory di configurazione. Se sono insieme condividono i due file; in cartelle diverse sono indipendenti. Un blocco di istanza unica a livello di sistema ne impedisce l’esecuzione simultanea. Collegamenti e attività pianificata puntano alla modalità che ha creato o modificato per ultima l’integrazione: scegli quindi un solo punto di ingresso quotidiano per cartella. Per due installazioni aggiornate indipendentemente usa cartelle diverse. Consulta [Configurazione, backup e ripristino](en/configuration.md) e [Installazione, aggiornamento e rimozione](en/installation.md).

I registri possono contenere percorsi, argomenti o variabili d’ambiente. Controlla e oscura i dati sensibili prima di pubblicarli. Usa i [moduli Issue strutturati](https://github.com/realSilasYang/process-watchdog/issues/new/choose) per le segnalazioni comuni e il canale privato per vulnerabilità non risolte. Consulta [Diagnostica locale](en/diagnostics.md), [Risoluzione dei problemi](en/troubleshooting.md) e [Supporto](../.github/SUPPORT.en.md).

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# Guida per gli sviluppatori

## 1. Cartelle e responsabilità

```text
process-watchdog/
├─ .github/                 moduli Issue, workflow e modelli di collaborazione
├─ app/                     stato dell’app, collegamento dell’interfaccia e finestre
├─ assets/                  icone, immagini di donazione e caratteri privati del processo
├─ config/                  esempio attuale con commenti vicino alle opzioni
├─ docs/                    documenti utente, architettura, lingue, immagini e governance
├─ src/                     configurazione, nucleo, diagnostica, esecuzione, ispezione, aggiornamenti, piattaforma e UI
├─ runtime/                 helper di aggiornamento in background per EXE e sorgente
├─ tests/                   verifiche del nucleo, GUI, release e repository
├─ third_party/             DLL, licenze e manifesti di dipendenze bloccati
├─ tools/                   compilazione, SBOM, verifica e preparazione degli strumenti
└─ 进程守护小助手.ahk      radice di composizione e punto di avvio
```

Lo script radice include soltanto i moduli, assembla le dipendenze e avvia l’app. `src` non legge le globali radice `App`, `Main` o `GuiModules`; `app` collega il nucleo puro a finestre, registri e operazioni di sistema. Consulta [Architettura e limiti di correttezza](en/architecture.md).

## 2. Limiti di correttezza

- Identità della destinazione, punto di avvio e presentazione personalizzata sono indipendenti; la presentazione non può cambiare le decisioni di sorveglianza.
- `Running`, `Stopped` e `Unknown` sono risultati di prove esterne; il ripristino parte solo dopo la conferma dell’arresto.
- Timer, callback, osservatori, processi di lavoro, finestre e risorse native devono avere una pulizia idempotente.
- Istantanee di configurazione, elementi e protezione vengono confermati nella stessa transazione; i test non devono leggere o sovrascrivere il `watchdog.ini` personale.
- Lo scorrimento fluido scartato basato su sovrapposizione di schermate GDI non deve tornare; ListView e registro mantengono lo scorrimento nativo.
- Le dichiarazioni su DPI, icone, modalità scura, gerarchia e accessibilità richiedono prove reali in Windows; l’automazione non sostituisce la matrice fisica.

## 3. Comandi di verifica

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-gui-tests.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

`verify.ps1` controlla hash, analisi AHK, vincoli architetturali, test del nucleo, confini del repository, perdite nell’intera cronologia Git, sintassi dei workflow e avvio. `run-gui-tests.ps1` crea controlli Windows reali e verifica il cambio immediato fra 13 lingue e caratteri, tre livelli di finestre e il rilascio degli handle GDI/USER. `reproducible-build.ps1` crea due volte i pacchetti EXE, sorgente e SBOM e ne confronta i checksum.

AutoHotkey e Ahk2Exe non sono bloccati in anticipo nel repository. Ogni pubblicazione manuale interroga l’ultima versione stabile di AutoHotkey e l’ultima pubblicata di Ahk2Exe, congela una singola risoluzione e usa esattamente quella per test, due compilazioni, SBOM e confezionamento. Gli strumenti di convalida come actionlint e Gitleaks restano bloccati. La release registra versioni, fonti, commit e SHA-256 reali. Consulta gli [avvisi sul software di terze parti](project/THIRD_PARTY_NOTICES.en.md).

## 4. Pubblicazione e contributi

Ogni modifica visibile deve aggiornare tutti i README localizzati e la cronologia. Per una nuova versione usa il [modello del changelog](en/changelog-template.md) e descrivi aggiunte, miglioramenti e correzioni osservabili, non messaggi di commit o nomi di classi interne.

Consulta il [processo di pubblicazione](en/release-process.md) e la [lista di controllo pubblica](en/publication-checklist.md). Una normale Pull Request non deve creare tag di versione né riscrivere tag pubblicati. Issue e Pull Request devono includere riproduzione, rischio e prove; per finestre, DPI, icone o modalità scura, indica anche la versione reale di Windows e la scala testata. Consulta [Contribuire](../.github/CONTRIBUTING.en.md) e [Governance](project/GOVERNANCE.en.md).

Il codice è pubblicato con [MIT License](../LICENSE). I componenti integrati conservano le proprie licenze; il pacchetto include la licenza AutoHotkey e il relativo archivio sorgente. PingFang, SF Pro Text e Apple SD Gothic Neo sono distribuiti con l’autorizzazione commerciale del proprietario del progetto e non rientrano nella MIT License.

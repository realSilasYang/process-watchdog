<div align="center">
  <img src="../assets/app/watchdog-logo.png" width="112" height="112" alt="Logo von Process Watchdog Assistant">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <strong>Deutsch</strong> · <a href="./README.it.md">Italiano</a></p>

  <h1>Prozessüberwachungs-Assistent</h1>

  <p><strong>Hält wichtige Anwendungen und Automatisierungen zuverlässig am Laufen</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="Neueste Version"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="GitHub-Downloads"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="CI-Status"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="Lizenz"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Unterstützt Windows 10 und Windows 11">
  </p>

  <p>
    <a href="#oberflächenübersicht">Oberfläche</a> ·
    <a href="#benutzerhandbuch">Benutzerhandbuch</a> ·
    <a href="#3-status-und-wiederherstellung">Status</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">Versionen</a> ·
    <a href="./CHANGELOG.en.md">Änderungen</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">Problem melden</a> ·
    <a href="#entwicklerhandbuch">Entwicklung</a>
  </p>
</div>

Der Prozessüberwachungs-Assistent richtet sich an Desktop-Anwendungen, Skripte und Verknüpfungen, die in der aktuellen Windows-Sitzung über längere Zeit verfügbar bleiben sollen. Nach einem unerwarteten Ende stellt er das Ziel automatisch und umsichtig wieder her. Dabei unterscheidet er zwischen einem bestätigten Stopp und einem vorübergehend unklaren Zustand, um falsche oder doppelte Starts zu vermeiden. Entscheidungen, Einstellungen und Protokolle bleiben vollständig auf dem lokalen Rechner. Das Projekt basiert auf AutoHotkey v2 x64 und unterstützt Windows 10 und Windows 11.

Der Assistent entscheidet nicht allein anhand des Prozessnamens, ob ein Ziel läuft. Er gleicht den vollständigen Pfad, die Erstellungsidentität des Prozesses, das tatsächliche Verknüpfungsziel und Befehlszeilenhinweise ab. Reichen die Belege nicht aus, wartet er auf die nächste Prüfung, statt einen unbekannten Zustand als Stopp zu behandeln.

Das Projekt bietet eine helle und dunkle Oberfläche, automatische Wiederherstellung, Schutz während Softwareupdates, ein Laufzeitprotokoll, Rückgängig/Wiederholen, benutzerdefinierte Namen und Symbole sowie ein Windows-x64-Paket mit SPDX-SBOM, SHA-256-Prüfsummen und Build-Herkunftsnachweis.

# Oberflächenübersicht

<p align="center">
  <img src="images/process-watchdog-overview.png" alt="Hauptfenster von Process Watchdog Assistant" width="100%">
</p>

Das Hauptfenster zeigt Reihenfolge, Anwendungssymbol, Namen, Rechteanforderung und aktuellen Status aller überwachten Einträge. Über die obere Leiste können Einträge hinzugefügt, gelöscht und pausiert sowie Einstellungen, Hilfe und Spenden geöffnet werden; in der Hilfe stehen Handbuch und Laufzeitprotokoll bereit. Die untere Leiste fasst laufende, wiederherzustellende, aktualisierte, pausierte und fehlgeschlagene Ziele zusammen. Das Protokoll erläutert die Belege hinter ungewöhnlichen Zuständen.

## Wichtigste Funktionen

- Überwacht EXE-, AHK-, Python-, JavaScript-, PowerShell-, BAT-, CMD- und LNK-Ziele.
- Verwendet `Running`, `Stopped` und `Unknown`; ein unbekannter Zustand löst niemals blind einen Neustart aus.
- Jedes Ziel besitzt eigenen Controller, eigene Generation und Aufgabentoken. Alte Rückrufe werden nach Pause, Löschen oder Pfadänderung sofort ungültig.
- Administratorrechte können vorgeschrieben werden. Eine laufende Instanz mit unpassenden Rechten wird gemeldet; ein manueller Neustart wird entsprechend erhöht ausgeführt.
- Der Updateschutz ist standardmäßig aus. Nach Aktivierung verbindet er Updateprozesse, Eltern-Kind-Beziehungen, Aktivitäten im Installationsordner und Dateistabilität, bevor die Überwachung pausiert oder fortgesetzt wird.
- Die Konfiguration wird atomar ersetzt. Nicht lesbare Datensätze werden nach `[Recovery]` verschoben, statt still verloren zu gehen.
- Die Anwendungssuche verwendet ausschließlich den Everything-Dienst, ohne eingebaute Vollplattensuche und ohne Ergebnisgrenze. Große Ergebnismengen werden in kurzen Blöcken ergänzt, damit die Symbolgewinnung die Oberfläche nicht blockiert.
- Unterstützt vereinfachtes Chinesisch, traditionelles Chinesisch für Hongkong, traditionelles Chinesisch für Taiwan, Englisch, Japanisch, Vietnamesisch, Koreanisch, Spanisch, Französisch, brasilianisches Portugiesisch, Russisch, Deutsch und Italienisch. Standardmäßig folgt die Oberfläche der Windows-Sprache, bei nicht unterstützten Sprachen wird Englisch verwendet; unter Allgemein ist eine manuelle Auswahl möglich. Sprache und Inhaltsschrift werden sofort im aktuellen Prozess angewendet, ohne Überwachungsaufgaben anzuhalten oder neu zu initialisieren.
- „Sprachstandard verwenden“ bevorzugt PingFang, SF Pro Text, Harano Aji Gothic oder Apple SD Gothic Neo. Fehlt die Schrift, wird die mitgelieferte kommerziell lizenzierte oder unter OFL stehende Ressource prozessintern geladen, anschließend die passende Noto-Familie. Die Inhaltsschrift gilt für Text, Eingabefelder, Listen und Infoangaben; Schaltflächen, Registerkarten und die untere Statusleiste verwenden stets die fette Windows-UI-Schrift der aktuellen Sprache.
- Helles und dunkles Design unterstützen unabhängig minimierbare Unterfenster, DPI-abhängigen Symbolneuaufbau, abgerundete Schaltflächen und benutzerdefinierte Symbole.
- Diagnosepakete entstehen ausschließlich lokal und werden nicht automatisch hochgeladen; offizielle Artefakte sind unabhängig überprüfbar.

## Einsatzbereich

Geeignet sind gewöhnliche Anwendungen, Skripte und Verknüpfungen, die in der aktuellen Windows-Desktopsitzung weiterlaufen und nach unerwartetem Ende wiederhergestellt werden sollen. Nicht abgedeckt sind:

- Windows-Dienste, Treiber, Kernelkomponenten oder sitzungsübergreifende Dienste.
- Windows 7, 32-Bit-Windows und andere Betriebssysteme.
- Harte Echtzeitsysteme, Hochverfügbarkeitscluster oder sicherheitsisolierte Prozessorchestrierung.
- Aggressive Strategien, die jeden unbekannten Prozesszustand zwangsweise als gestoppt behandeln.

Ein vollständiger GUI-Automatisierungslauf ist unter Windows 11 mit echten 200 % DPI dokumentiert; die Renderberechnungen werden per Regression bei 100 % und 300 % geprüft. Manuelle Sichtprüfungen aller Skalierungen, fortlaufende DPI-Wechsel zwischen Monitoren und hoher Kontrast sind noch nicht verifiziert und dürfen nicht allein aus dem Code abgeleitet werden. Siehe den [GUI-Validierungsnachweis](../tests/gui/VALIDATION-EVIDENCE.en.md) und [Kompatibilität und bekannte Einschränkungen](en/compatibility.md).

---

**[Benutzerhandbuch](#benutzerhandbuch)**<br>
[Installation](#1-installation-und-erster-start) · [Verwaltung](#2-einträge-hinzufügen-und-verwalten) · [Status](#3-status-und-wiederherstellung) · [Updates](#4-schutz-bei-updates) · [Einstellungen](#5-einstellungen) · [Protokolle](#6-protokolle-diagnose-und-datenschutz)

**[Entwicklerhandbuch](#entwicklerhandbuch)**<br>
[Verzeichnisse](#1-verzeichnisse-und-zuständigkeiten) · [Korrektheit](#2-korrektheitsgrenzen) · [Prüfung](#3-prüfbefehle) · [Veröffentlichung](#4-veröffentlichung-und-mitarbeit)

# Projekt unterstützen

Der Prozessüberwachungs-Assistent bleibt Open Source. Seine langfristige Pflege hängt von Unterstützung und Zuspruch aus der Gemeinschaft ab. Wenn er Zeit bei Fehlersuche oder Wiederherstellung gespart hat, ist über einen der folgenden QR-Codes eine freiwillige Spende möglich. Beiträge finanzieren Wartung, Kompatibilitätsprüfungen und kommende Versionen.

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="QR-Code für eine Spende über WeChat Pay">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="QR-Code für eine Spende über Alipay">
</p>

# Benutzerhandbuch

## 1. Installation und erster Start

1. Wählen Sie unter [Releases](https://github.com/realSilasYang/process-watchdog/releases) eine der drei Ausgaben: eigenständige EXE, vollständiges portables ZIP oder vollständiges Quellcode-ZIP.
2. Die eigenständige EXE benötigt kein AutoHotkey und installiert beim ersten Start ihr geprüftes Paket unter `%LOCALAPPDATA%\ProcessWatchdog\Standalone`; das portable ZIP bleibt nach vollständigem Entpacken im gewählten Ordner; für das Quellcode-ZIP muss AutoHotkey v2 x64 installiert sein.
3. Starten Sie `进程守护小助手.exe`. Die Anwendung fordert Administratorrechte an und zeigt je nach Einstellung das Hauptfenster oder bleibt im Infobereich.
4. Wählen Sie „Hinzufügen“ oder ziehen Sie unterstützte Dateien in das Hauptfenster.
5. Öffnen Sie das Protokoll, um die tatsächlich verwendeten Identitätsbelege, Statusprüfungen, Wiederherstellungsversuche und Updatesignale zu sehen.

Für den Start aus dem Quellcode installieren Sie AutoHotkey v2 x64 und führen `进程守护小助手.ahk` aus. Wenn Sie das Repository mit Git klonen, installieren Sie zusätzlich Git LFS und führen `git lfs pull` aus, damit die vollständigen Schriftdateien statt der LFS-Zeiger geladen werden. Das einem Release beigefügte Quellcode-ZIP enthält diese Ressourcen bereits und benötigt Git LFS nicht. Offizielle Versionen enthalten die AutoHotkey-Laufzeit, die sämtliche Veröffentlichungstests bestanden hat; normale Benutzer benötigen keine separate Installation.

### Versionen und Ausführungsformen

| Komponente | EXE-Ausgabe | Quellcode-Ausgabe |
| --- | --- | --- |
| Assistent | Liest die EXE-Dateiversion; ein Update ersetzt das vollständige Paket | Liest `VERSION` neben dem Einstiegspunkt; Update per sicherem Git-Fast-Forward oder Quellpaket |
| AutoHotkey | Eingebettet und mit einem späteren vollständigen Assistentenpaket aktualisiert | Verwendet den lokalen Interpreter; ein Assistentenupdate aktualisiert AutoHotkey nicht |
| Ahk2Exe | Nur zur Erstellung der offiziellen EXE verwendet und nicht auf Benutzerrechnern installiert | Nicht erforderlich |

„Der Assistent ist aktuell“ und „das lokale AutoHotkey ist aktuell“ sind verschiedene Aussagen. Zu Beginn jeder offiziellen Veröffentlichung werden die neueste stabile AutoHotkey-Version und die neueste veröffentlichte Ahk2Exe-Version gewählt, diese Auswahl eingefroren und alle Tests vor der Einbettung ausgeführt. Assistenteneinstellungen → Info zeigt Assistentenversion, EXE-/Quellform und tatsächliche AutoHotkey-Version und erlaubt eine manuelle Updateprüfung. Siehe [Versionen, Ausführungsformen und Updateverantwortung](en/versioning.md).

Das Schließen des Hauptfensters blendet es nur im Infobereich aus; die Überwachung läuft weiter. Verwenden Sie „Beenden“ im Infobereichsmenü, um die Anwendung vollständig zu stoppen. Siehe [Installation, Aktualisierung und Entfernung](en/installation.md) für Verknüpfungen, geplanten Start und Updates.

## 2. Einträge hinzufügen und verwalten

| Schaltfläche | Funktion |
| --- | --- |
| Hinzufügen | Ziel wählen, installierte Anwendungen suchen oder Ordner importieren; Unterordner sind standardmäßig eingeschlossen |
| Löschen | Ausgewählte Einträge entfernen; Mehrfachauswahl und Rückgängig werden unterstützt |
| Pausieren / Fortsetzen | Nur automatische Überwachung ändern, ohne das laufende Ziel zu schließen; gemischte Auswahl wird einzeln umgeschaltet |
| Einstellungen | Allgemein, Überwachung und Start, Stopprichtlinie, Protokolle und Info konfigurieren |
| Hilfe | Eingebautes Handbuch, Laufzeitprotokoll oder GitHub-Feedbackseite auswählen |
| Spenden | QR-Codes von WeChat Pay und Alipay zur Unterstützung der Wartung anzeigen |

Ein Eintrag kann Einstiegspunkt, Arbeitsordner, Argumente und Administratoranforderung festlegen. Die LNK-Datei bleibt Startpunkt, während der tatsächliche Programmpfad getrennt zur Prozessidentifikation gespeichert wird. Eine vom Installationsprogramm angelegte indirekte Verknüpfung muss deshalb nicht manuell durch eine wechselnde interne EXE ersetzt werden.

Das Kontextmenü öffnet den Speicherort, startet neu, ändert den Pfad, konfiguriert Prozesserkennung und Starteinstellungen, schaltet die Administratoranforderung um, richtet Updateschutz ein und passt Namen oder Symbol nur im Hauptfenster an. Die Darstellung ändert weder Identität, Start noch Schutz. Sind bereits Standardwerte aktiv, ist das Zurücksetzen deaktiviert.

Nur BAT- und CMD-Einträge zeigen zusätzlich den Befehl „Batch-Ausgabeprotokoll anzeigen“; bei anderen Zieltypen erscheint er nicht. Die eigenständige Protokolldatei wird nur angelegt, wenn der Assistent den Batch-Eintrag tatsächlich startet und dessen Standardausgabe und Fehlerausgabe erfasst. Für einen bereits laufenden Batch-Prozess entsteht sie nicht automatisch.

Ziehen Sie Zeilen zum Sortieren; die Reihenfolge wird gespeichert. `Ctrl+Z`, `Ctrl+Y` und `Ctrl+Shift+Z` machen Hinzufügen, Löschen, Sortieren und Konfigurationsänderungen rückgängig oder wiederholen sie. Die linke Nummer wird aus der sichtbaren Reihenfolge neu gebildet und gehört nicht zu Identität, Start oder Speicherung. Siehe [Typische Szenarien](en/quick-start.md).

## 3. Status und Wiederherstellung

Der Listenstatus beschreibt verfügbare Belege und den nächsten Schritt. Schließen Sie nicht allein aus der Symbolfarbe auf das Ergebnis.

| Status | Bedeutung |
| --- | --- |
| Läuft | Eine laufende Instanz passend zur Zielidentität wurde gefunden |
| Läuft (Rechte stimmen nicht) | Die Instanz existiert, erfüllt aber die Administratoranforderung nicht |
| Status wird geprüft / Möglicherweise gestoppt | Belege fehlen oder ein Ende wurde gerade erkannt; erneute Prüfung ohne Doppelstart |
| Start / Wiederholungs-Countdown | Wiederherstellung ist bestätigt und der nächste Versuch folgt der Wartefolge |
| Update / Stabilität wird geprüft | Automatischer Start wartet auf Aktivitätsende und stabile Dateien |
| Pausiert | Automatische Prüfungen und Wiederherstellung sind pausiert, der Zielprozess bleibt geöffnet |
| Gestoppt / Start fehlgeschlagen / Zeitüberschreitung | Wiederherstellung blieb erfolglos oder braucht Bestätigung; Belege und Grund stehen im Protokoll |

Die Standardverzögerungen betragen 1, 10 und 60 Sekunden. Nach der schnellen Folge wird der letzte Wert wiederverwendet, um enge Startschleifen zu vermeiden. Löschen, Pausieren, Pfadänderung oder Rückgängig machen alte Aufgaben und asynchrone Ergebnisse ungültig.

## 4. Schutz bei Updates

Der Schutz ist standardmäßig aus und muss je Eintrag aktiviert werden:

1. Rechtsklicken Sie das Ziel und öffnen Sie den Updateschutz.
2. Aktivieren Sie automatische Erkennung und Startschutz.
3. Prüfen Sie Installationsumfang, Ende-Erkennungsfenster, Stabilitätswartezeit und maximale Updatewartezeit.
4. Speichern Sie und lassen Sie die Anwendung einmal normal ein echtes Update durchführen. Der Assistent kombiniert Updateprozesse, Eltern-Kind-Beziehungen, Ordneraktivität, Dateibenachrichtigungen und gelernte Merkmale, um den Schutzbeginn zu bestimmen.

Nach Bestätigung bleibt der automatische Start ausgesetzt. Die normale Überwachung kehrt erst zurück, wenn die Aktivität endet und Dateien stabil sind. Läuft die Erkennung ab oder passt nicht zur Realität, verwenden Sie „Updatewartezeit beenden und Überwachung fortsetzen“. Die Sicherheit des Einstiegspunkts wird vor der Wiederherstellung erneut geprüft.

Die Funktion ist weder universelles Installationsprogramm noch Windows-Dienstverwaltung. Prüfen Sie bei portablen Apps, externen Updatern oder ungewöhnlichen Startprogrammen zuerst das Protokoll und passen Sie anschließend Umfang und Regeln an.

## 5. Einstellungen

| Bereich | Optionen |
| --- | --- |
| Allgemein | Desktop- und Startmenüverknüpfungen, geplanter Autostart, zwei Startverhalten, Sprache, Inhaltsschrift und Design |
| Überwachung und Start | Prozessprüfintervall, Verzögerungsfolge nach Absturz und Einbeziehung von Unterordnern beim Import |
| Stopprichtlinie | Zeitlimits zum Schließen von GUI-/CLI-Anwendungen und Erlaubnis zum erzwungenen Beenden nach Ablauf |
| Protokolle | Löschen beim Start, Anzeigegrenze, Aufbewahrungstage für Stapelprotokolle und Speicherpfad |
| Info | Versionen von Anwendung und Umgebung, sofortige Updateprüfung und Link zum Open-Source-Projekt |

Das Fenster prüft Zahlenbereiche. Kommentare in `watchdog.ini` stehen neben den passenden Abschnitten und Einstellungen; verwenden Sie bevorzugt die Oberfläche, damit codierte Felder unbeschädigt bleiben. Siehe [Konfiguration, Sicherung und Wiederherstellung](en/configuration.md).

## 6. Protokolle, Diagnose und Datenschutz

Im Laufzeitprotokoll können Text markiert und kopiert, das Fenster maximiert und seine Größe geändert werden. Bildlaufleisten erscheinen nur bei Bedarf und der Text ist nicht bearbeitbar.

Bei schwierigen Problemen lässt sich aus dem Protokollfenster ein lokales Diagnosepaket exportieren. Es enthält Zusammenfassungen zu Anwendung, Windows, AutoHotkey, DPI, Ressourcenhandles, Überwachungsphase, Konfigurationswarnungen und aktuellem Protokoll, wird aber nie automatisch hochgeladen.

Persönliche Einstellungen liegen im tatsächlichen Laufzeitordner in `watchdog.ini`, unvollständige Updatesitzungen in `watchdog.maintenance.ini`. Portable und Quellversion nutzen ihren Einstiegsordner; die eigenständige EXE nutzt immer `%LOCALAPPDATA%\ProcessWatchdog\Standalone`. Git ignoriert beide Dateien; Releases liefern oder überschreiben sie nicht.

Portable EXE und Quellversion teilen den Zustand nur im selben Ordner; die eigenständige EXE teilt keine Konfiguration mit Dateien neben dem heruntergeladenen Starter. Eine systemweite Einzelinstanzsperre verhindert parallele Ausführung. Verknüpfungen und geplante Aufgabe zeigen auf die zuletzt integrierte tatsächliche Laufzeitform. Siehe [Konfiguration, Sicherung und Wiederherstellung](en/configuration.md) und [Installation, Aktualisierung und Entfernung](en/installation.md).

Protokolle können Pfade, Argumente oder Umgebungsvariablen enthalten. Prüfen und schwärzen Sie sensible Angaben vor einer Veröffentlichung. Nutzen Sie [strukturierte Issue-Formulare](https://github.com/realSilasYang/process-watchdog/issues/new/choose) für normale Berichte und den privaten Kanal für nicht behobene Schwachstellen. Siehe [Lokale Diagnose](en/diagnostics.md), [Fehlerbehebung](en/troubleshooting.md) und [Support](../.github/SUPPORT.en.md).

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# Entwicklerhandbuch

## 1. Verzeichnisse und Zuständigkeiten

```text
process-watchdog/
├─ .github/                 Issue-Formulare, Workflows und Vorlagen zur Zusammenarbeit
├─ app/                     Anwendungszustand, UI-Anbindung und Fenster
├─ assets/                  Symbole, Spendenbilder und prozessintern geladene Schriften
├─ config/                  aktuelles Beispiel mit Kommentaren an den Einstellungen
├─ docs/                    Benutzer-, Architektur-, Sprach-, Bild- und Governance-Dokumente
├─ src/                     Konfiguration, Kern, Diagnose, Ausführung, Prüfung, Updates, Plattform und UI
├─ runtime/                 Hintergrund-Updatehelfer für EXE und Quellcode
├─ tests/                   Kern-, GUI-, Release- und Repositoryprüfungen
├─ third_party/             festgelegte DLLs, Lizenzen und Abhängigkeitslisten
├─ tools/                   Build, SBOM, Prüfung und Werkzeugvorbereitung
└─ 进程守护小助手.ahk      Kompositionswurzel und Startpunkt
```

Das Stammskript bindet nur Module ein, setzt Abhängigkeiten zusammen und startet die Anwendung. `src` liest keine globalen Stammvariablen `App`, `Main` oder `GuiModules`; `app` verbindet den reinen Kern mit Fenstern, Protokollen und Systemvorgängen. Siehe [Architektur und Korrektheitsgrenzen](en/architecture.md).

## 2. Korrektheitsgrenzen

- Zielidentität, Startpunkt und angepasste Darstellung sind unabhängig; Darstellungseinstellungen dürfen Überwachungsentscheidungen nicht ändern.
- `Running`, `Stopped` und `Unknown` sind Ergebnisse externer Belege; Wiederherstellung beginnt nur nach bestätigtem Stopp.
- Timer, Rückrufe, Beobachter, Arbeitsprozesse, Fenster und native Ressourcen benötigen einen idempotenten Bereinigungspfad.
- Konfigurationsabbild, Einträge und Updateschutz werden in derselben Transaktion bestätigt; Tests dürfen persönliche `watchdog.ini` weder lesen noch überschreiben.
- Der verworfene weiche Bildlauf mit GDI-Bildüberlagerung darf nicht zurückkehren; ListView und Protokoll behalten nativen Bildlauf.
- Aussagen zu DPI, Symbolen, dunklem Modus, Hierarchie und Barrierefreiheit erfordern echte Windows-Prüfungen; Automatisierung ersetzt keine physische Matrix.

## 3. Prüfbefehle

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-windows-integration.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

`verify.ps1` prüft Hashes, AHK-Analyse, Architekturvorgaben, Kerntests, Repositorygrenzen, Lecks in der gesamten Git-Historie, Workflowsyntax und Start. `verify-windows-integration.ps1` prüft vollständige Schriftressourcen, erzeugt echte Windows-Steuerelemente und testet 13 Sprachen, drei Fensterebenen sowie die Freigabe von GDI-/USER-Handles. `reproducible-build.ps1` erstellt die drei Ausgaben und das SBOM zweimal und vergleicht ihre Prüfsummen.

AutoHotkey und Ahk2Exe werden im Repository nicht vorab festgelegt. Jede manuelle Veröffentlichung fragt die neueste stabile AutoHotkey-Version und die neueste veröffentlichte Ahk2Exe-Version ab, friert eine einzige Auflösung ein und nutzt genau diese für Tests, beide Builds, SBOM und Verpackung. Prüfwerkzeuge wie actionlint und Gitleaks bleiben festgelegt. Das Release speichert tatsächliche Versionen, Quellen, Commits und SHA-256. Siehe [Hinweise zu Drittsoftware](project/THIRD_PARTY_NOTICES.en.md).

## 4. Veröffentlichung und Mitarbeit

Jede sichtbare Änderung muss in allen lokalisierten README-Dateien und im Änderungsprotokoll nachgeführt werden. Verwenden Sie für neue Versionen die [Changelog-Vorlage](en/changelog-template.md) und beschreiben Sie beobachtbare Neuerungen, Verbesserungen und Korrekturen statt Commitnachrichten oder interner Klassennamen.

Siehe [Veröffentlichungsablauf](en/release-process.md) und [Checkliste zur Veröffentlichung](en/publication-checklist.md). Ein normaler Pull Request darf weder Versionstags erzeugen noch veröffentlichte Tags ändern. Issues und Pull Requests sollten Reproduktion, Risiko und Prüfnachweise enthalten; nennen Sie bei Fenstern, DPI, Symbolen oder dunklem Modus auch echte Windows-Version und getestete Skalierung. Siehe [Mitwirken](../.github/CONTRIBUTING.en.md) und [Projektverwaltung](project/GOVERNANCE.en.md).

Der Code steht unter der [MIT License](../LICENSE). Eingebettete Komponenten behalten ihre eigenen Lizenzen; das Paket enthält die AutoHotkey-Lizenz und das zugehörige Quellarchiv. PingFang, SF Pro Text und Apple SD Gothic Neo werden mit der kommerziellen Weitergabegenehmigung des Projektinhabers verteilt und fallen nicht unter die MIT License.

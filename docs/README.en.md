<div align="center">
  <img src="../assets/app/watchdog-logo.png" width="112" alt="Process Watchdog Assistant Logo">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <strong>English</strong> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Process Watchdog Assistant</h1>

  <p><strong>Keep essential apps and automations running reliably, day after day</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="Latest version"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="GitHub downloads"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="CI status"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="License"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 and Windows 11 supported">
  </p>

  <p>
    <a href="#interface-overview">Interface</a> ·
    <a href="#user-guide">User guide</a> ·
    <a href="#3-status-and-recovery">Status reference</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">Releases</a> ·
    <a href="./CHANGELOG.en.md">Changelog</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">Report an issue</a> ·
    <a href="#developer-guide">Developer guide</a>
  </p>
</div>

Process Watchdog Assistant is designed for Windows desktop applications, scripts, and shortcuts that need to remain available for long periods. After an unexpected exit, it restores the target automatically and deliberately while distinguishing a confirmed stop from a temporarily unknown state, preventing duplicate or mistaken launches. Every decision, setting, and log remains on the local computer. The project is built with AutoHotkey v2 x64 and supports Windows 10 and Windows 11.

The assistant does not decide that a target is running from its process name alone. It combines the full executable path, process creation identity, resolved shortcut target, and command-line evidence. When evidence is incomplete, it waits for another check instead of treating “temporarily unknown” as stopped and launching duplicate instances.

The project provides light and dark GUIs, automatic recovery, update protection, runtime logs, undo and redo, custom display names and icons, and a Windows x64 release package with an SPDX SBOM, SHA-256 checksums, and build provenance.

# Interface Overview

<p align="center">
  <img src="images/process-watchdog-overview.png" alt="Process Watchdog Assistant main window" width="100%">
</p>

The main window keeps each target's order, application icon, display name, privilege requirement, and current state in one view. The command bar provides add, delete, pause, settings, help, and About actions; Help lets users choose the guide, runtime log, or feedback page, while About brings version, runtime, update, project, and Donate actions together. The footer summarizes running, recovery, update, paused, and failed targets, while the runtime log exposes the evidence behind abnormal states.

## Highlights

- Monitor EXE, AHK, Python, JavaScript, PowerShell, BAT, CMD, and LNK targets.
- Use `Running`, `Stopped`, and `Unknown` probe results; an unknown result never triggers a blind restart.
- Give every target its own controller, generation, and task tokens, so stale callbacks become invalid immediately after pausing, deletion, or path changes.
- After a directly added file or one of its parent folders is renamed, or the file is moved across folders or volumes, narrow candidates by compatible extension and exact size, verify the complete SHA-256 content hash, then ask for confirmation. Recovery also works for moves made while the assistant was closed; names, file IDs, and directory notifications are not identity evidence.
- Enforce an administrator requirement when configured; report a privilege mismatch for an existing process and elevate the next monitored launch.
- Keep update protection off by default. When enabled, combine updater processes, parent-child relationships, installation-directory activity, and file stability before pausing or resuming monitoring.
- Replace configuration atomically. Records that cannot be parsed are moved to `[Recovery]` instead of being silently discarded.
- Use the Everything service exclusively for application search, without a local full-disk fallback or an application-imposed result limit. Large result sets are appended in short batches so icon extraction does not monopolize the UI.
- Support Simplified Chinese, Traditional Chinese (Hong Kong), Traditional Chinese (Taiwan), English, Japanese, Vietnamese, Korean, Spanish, French, Brazilian Portuguese, Russian, German, and Italian. The interface follows the Windows UI language by default, falls back to English for unsupported languages, and can be selected manually under General. Language and content-font changes take effect immediately in the current process without stopping or reinitializing guard tasks.
- In language-default mode, use only Windows-installed fonts: try PingFang, SF Pro Text, Harano Aji Gothic, or Apple SD Gothic Neo first, then the matching Noto family, then a Windows system font. Optional fonts must be installed into Windows first; the assistant never loads fonts privately from its own directory. The content font controls body text, inputs, lists, and About information; buttons, Settings tabs, and the main-window footer always use the current language's Windows UI font in bold.
- Provide light and dark GUIs with independently minimizable child windows, DPI-aware icon rebuilding, rounded buttons, and custom icons.
- Generate diagnostics locally without automatic upload, and make official artifacts independently verifiable.

## Scope

The assistant is intended for ordinary applications, scripts, and shortcuts that should remain running in the current Windows desktop session and recover after an unexpected exit. The following are outside the project scope:

- Windows services, drivers, kernel components, or services spanning user sessions.
- Windows 7, 32-bit Windows, and non-Windows platforms.
- Hard real-time systems, highly available clusters, or security-isolated process orchestration.
- Aggressive recovery policies that force every unknown process state to mean stopped.

A complete GUI automation run is recorded on real Windows 11 at 200% DPI, with rendering calculations covered by regression tests at 100% and 300%. Manual visual checks at every scale, continuous per-monitor DPI changes, and high contrast remain unverified and must not be inferred from code alone. See the [GUI validation record](../tests/gui/VALIDATION-EVIDENCE.en.md) and [Compatibility and known limitations](en/compatibility.md).

---

**[User guide](#user-guide)**<br>
[Install and start](#1-installation-and-first-run) · [Add and manage items](#2-adding-and-managing-items) · [Status and recovery](#3-status-and-recovery) · [Update protection](#4-update-protection) · [Settings](#5-settings) · [Logs and diagnostics](#6-logs-diagnostics-and-privacy)

**[Developer guide](#developer-guide)**<br>
[Directories](#1-directories-and-responsibilities) · [Correctness boundaries](#2-correctness-boundaries) · [Validation](#3-validation-commands) · [Release and contribution](#4-release-and-contribution)

# Donate

If the assistant has saved you time diagnosing failures or recovering applications, you can support the author using either QR code below. Choose how you'd like to help:

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="WeChat Pay donation QR code">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Alipay donation QR code">
</p>

# User guide

## 1. Installation and first run

1. Choose the complete portable ZIP or complete source ZIP from [Releases](https://github.com/realSilasYang/process-watchdog/releases). The optional font package is a separate resource, not a third program edition.
2. The two program editions have different storage and runtime models:

| Download | Best for | Runtime and configuration location |
| --- | --- | --- |
| Complete portable ZIP | Visible, backup-friendly long-term or manual deployment | Run after fully extracting it; resources and `watchdog.ini` remain in the extracted directory, so the inner EXE cannot be copied out alone |
| Complete source ZIP | Review, development, or source execution | Fully extract it and run the root AHK with local AutoHotkey v2 x64; configuration remains in the source directory |

3. Run `进程守护小助手.exe`. The application requests administrator privileges, then shows the main window or starts in the system tray according to its settings.
4. Select Add to choose a target, or drag supported files into the main window.
5. Open Help → Runtime Log to see which identity evidence, state checks, recovery attempts, and update signals the assistant actually used.

To run from source, install AutoHotkey v2 x64 and execute `进程守护小助手.ahk`.
A Git clone also requires Git LFS and `git lfs pull` to materialize the build
resources for the separate font package. Neither the source ZIP nor portable ZIP
contains fonts. The portable ZIP embeds the AutoHotkey runtime that passed the
complete release test suite, so ordinary users do not need a separate installation.

The optional `fonts.zip` supplies preferred and Noto fallback UI fonts. Install the desired fonts into Windows before use; they are not required to run the assistant. Application search separately requires the [latest official Everything release](https://www.voidtools.com/downloads/). The bundled `Everything64.dll` is only an IPC client for its index and background service and cannot replace Everything itself.

### Versions and runtime forms

| Version | Compiled edition (portable ZIP) | Source edition |
| --- | --- | --- |
| Assistant | Read from EXE file metadata; a complete release package replaces it during updates | Read from `VERSION` beside the entry; updated by a safe Git fast-forward or source package |
| AutoHotkey | Embedded and updated with a later assistant release package | Uses the local interpreter; assistant updates do not upgrade AutoHotkey for the user |
| Ahk2Exe | Used only to produce the official EXE and never installed on user computers | Not required |

“The assistant is up to date” and “local AutoHotkey is up to date” are different claims. At the start of every official release, the workflow selects the latest stable AutoHotkey and latest published Ahk2Exe release, freezes them, and runs the complete test suite before embedding the selected AutoHotkey. Main window → About shows the current assistant version, EXE/source form, and actual AutoHotkey version together, with update checking and project access in the same child window. See [Versions, runtime forms, and update responsibility](en/versioning.md).

Closing the main window only hides it to the system tray; monitoring continues. Use Exit from the tray menu to stop the application completely. See [Installation, upgrades, and removal](en/installation.md) for shortcuts, scheduled startup, and upgrade details.

## 2. Adding and managing items

The six main-window buttons have the following roles:

| Button | Purpose |
| --- | --- |
| Add | Select one target, search installed applications, or import a folder; folder import scans subdirectories by default |
| Delete | Remove selected watched targets; multiple selections are supported and deletion can be undone |
| Pause / Resume | Change automatic monitoring only; the currently running target is not closed, and a mixed selection is toggled item by item |
| Settings | Configure General, Monitoring & startup, Stop Policy, and Logs |
| Help | Choose the built-in user guide, this session's runtime log, or the GitHub feedback page |
| About | View version and runtime information, check for updates, open the project, or enter Donate |

An item can define its launch entry, working directory, arguments, environment variables, and administrator requirement. A direct script can also select any runtime and runtime arguments in Process Identification and Launch Settings, including a Python virtual environment, AutoHotkey, PowerShell, Node.js, or Java. The fixed order is runtime arguments, target path, then target arguments; leaving the runtime blank preserves the default launch behavior. An LNK remains the launch entry while the resolved application path is stored separately for process identification. Indirect shortcuts created by installers therefore do not have to be replaced manually with a version-specific internal EXE.

Application search requires a running Everything background instance. The bundled `Everything64.dll` is only an SDK client for that instance and contains no indexer. If the background instance is not running, the assistant searches bounded local installation hints and starts Everything silently when found; if it is not installed, the search window links to the official latest-version download page. See [Common scenarios](en/quick-start.md) for examples.

Right-click an item in the main list to:

- Restart the target, stop it, edit its full path, or open its file location. Restart applies the configured stop policy before launching again; Stop Running also pauses monitoring so the target is not launched again automatically.
- Configure process identification and launch settings before the administrator toggle.
- Toggle the administrator requirement. A running target with insufficient privileges is reported; after monitoring is resumed, the next launch is elevated as configured.
- Configure update protection.
- BAT and CMD entries additionally show View batch output log. Other target
  types do not show this command. The file is created only when the assistant
  actually launches that batch entry and captures its standard output and error.
- Customize the name and icon shown in the main window. Display customization does not change target identity, launch behavior, or update protection.
- Restore the default name and icon. The reset action is disabled when the current display is already the default.

Drag rows to reorder them; the order is persisted. Use `Ctrl+Z`, `Ctrl+Y`, or `Ctrl+Shift+Z` to undo or redo additions, deletions, sorting, and configuration changes. See [Common scenarios](en/quick-start.md) for examples.

The leftmost number always follows the current display order and is regenerated after deletion, reordering, undo, or redo. The application icon remains beside the name; the number is not part of identity, launch behavior, or persistence.

## 3. Status and recovery

A list status describes the evidence currently available and the next action. Do not infer the result from icon color alone.

| Status | Meaning |
| --- | --- |
| Running | A running instance matching the target identity was found |
| Running (privilege mismatch) | The instance exists but does not satisfy the configured administrator requirement |
| Waiting for process status / Possibly stopped | Evidence is incomplete or an exit was just observed; the assistant is rechecking and will not immediately launch a duplicate |
| Starting / Retry countdown | Recovery is confirmed and the next attempt follows the configured retry sequence |
| Updating / Confirming file stability | Update protection paused automatic launch until update activity ends and target files become stable |
| Paused | Automatic checks and recovery are paused without closing the target process |
| Stopped / Launch failed / Wait timed out | Recovery did not succeed or requires confirmation; inspect the log for the exact evidence and failure reason |

The default retry delays are 1, 10, and 60 seconds. After the fast sequence is exhausted, the final delay is reused to prevent a tight launch loop. Deleting, pausing, changing a path, or undoing an operation invalidates old scheduled tasks and asynchronous results.

## 4. Update protection

Update protection is disabled by default and must be enabled per item:

1. Right-click the target and open Update Protection.
2. Select automatic update detection and launch protection.
3. Verify the installation footprint, exit-detection window, file-stability wait, and maximum update wait.
4. Save the settings and let the application perform one real update normally. The assistant combines updater processes, parent-child relationships, installation-directory activity, file notifications, and learned updater signatures to decide whether protection should begin.

Once an update is confirmed, automatic launch is suspended. Normal monitoring resumes only after activity ends and the target files are stable. If detection times out or does not match reality, use End update wait and resume monitoring in the same window. The launch entry is still checked for safety before recovery.

Update protection is not a general installer or Windows-service manager. For portable applications, updaters outside the installation directory, or unusual launchers, inspect the runtime log before adjusting the footprint and rules.

## 5. Settings

Assistant Settings is divided by responsibility:

| Category | Options |
| --- | --- |
| General | Desktop and Start menu shortcuts, scheduled automatic startup, both startup behaviors, interface language, interface content font, and theme |
| Monitoring & startup | Process status interval, automatic restart delay sequence after a crash, and subfolder inclusion during folder import |
| Stop Policy | GUI and CLI shutdown timeouts and whether force termination is allowed after timeout |
| Logs | Startup clearing, runtime-log display limit, batch-log retention days, and save path |

Numeric ranges are validated by the settings window. Comments in `watchdog.ini` sit beside their corresponding sections and settings. Prefer the GUI for edits so encoded fields remain intact. See [Configuration, backup, and recovery](en/configuration.md).

## 6. Logs, diagnostics, and privacy

The Runtime Log allows text selection and copying and can be maximized or resized. Scrollbars appear only when needed, and the log itself is not editable.

The Runtime Log records the assistant's own decisions and actions for every
target. A batch output log is different: it exists only for a BAT or CMD entry
that the assistant actually launched. The launch redirects both standard output
and standard error to that file, which may still be empty when the batch program
prints nothing. EXE, AHK, PowerShell, shortcut, and already-running batch targets
do not automatically receive a separate output file.

For difficult problems, export a local diagnostics bundle from the log window. It includes application, Windows, AutoHotkey, DPI, resource-handle, monitoring phase, configuration-warning, and current-log summaries. Nothing is uploaded automatically.

Personal configuration is stored in `watchdog.ini` under the actual runtime directory; unfinished update sessions use `watchdog.maintenance.ini` there. Portable and source editions use their entry directory. Both files are ignored by Git and never shipped in a release. `config/watchdog.example.ini` only documents current defaults and fields.

A portable EXE and source entry in one directory share personal state; separate directories remain independent. A machine-wide single-instance lock prevents forms from running concurrently. Shortcuts and the scheduled task point to whichever actual runtime form most recently created or switched the integration, so choose one everyday entry per installation. See [Configuration, backup, and recovery](en/configuration.md) and [Installation, upgrades, and removal](en/installation.md).

Logs and diagnostics may contain target paths, launch arguments, or environment variables. Review and redact them before posting publicly. Use the [structured issue forms](https://github.com/realSilasYang/process-watchdog/issues/new/choose) for ordinary reports, and private vulnerability reporting for unresolved security issues. See [Local diagnostics](en/diagnostics.md), [Troubleshooting](en/troubleshooting.md), and [Support](../.github/SUPPORT.en.md).

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# Developer guide

## 1. Directories and responsibilities

```text
process-watchdog/
├─ .github/
│  ├─ ISSUE_TEMPLATE/        bug, feature, and improvement forms
│  ├─ workflows/             CI, long-running GUI tests, and manual releases
│  ├─ CONTRIBUTING / SECURITY community, security, support, and conduct files
│  └─ PULL_REQUEST_TEMPLATE/ Chinese and English pull-request templates
├─ app/
│  ├─ UI/                    main-window rendering, icons, and interaction adapters
│  └─ Windows/               settings, logs, help, and child dialogs
├─ assets/
│  ├─ app/                   application icon
│  ├─ fonts/                 optional font-package resources, authorization, and provenance
│  └─ ui-icons/              SVG icons for buttons, list states, and the statistics bar
├─ config/                   current configuration example with inline comments
├─ docs/                     user, architecture, multilingual overview, image, and governance docs
├─ src/
│  ├─ Config/                codecs, transactions, layout, and persistence
│  ├─ Core/                  monitoring state, scheduling, retries, and target controllers
│  ├─ Diagnostics/           local diagnostics bundles
│  ├─ Execution/             launch, graceful close, and staged termination
│  ├─ Inspection/            process, shortcut, file, and directory evidence
│  ├─ Maintenance/           update-protection state and session recovery
│  ├─ Platform/              Win32 constants and platform boundary
│  ├─ UI/                    list projection, icon resources, and window lifecycle
│  └─ Update/                asynchronous self-update coordination
├─ runtime/                  background update checker and replacement helper shared by EXE and source
├─ tests/
│  ├─ core/                  independently runnable core behavior tests
│  └─ gui/                   real-control stress tests and manual regression matrix
├─ third_party/              pinned runtime DLLs, licenses, and dependency manifests
├─ tools/                    build, SBOM, release verification, and toolchain bootstrap
└─ 进程守护小助手.ahk        composition root and startup entry
```

The root script includes modules, wires dependencies, and starts the application. Modules under `src` do not read the root globals `App`, `Main`, or `GuiModules`; `app` connects core behavior to windows, logs, and system operations. See [Architecture and correctness boundaries](en/architecture.md).

## 2. Correctness boundaries

- Target identity, launch entry, and custom display are independent. Display settings must never change monitoring decisions.
- `Running`, `Stopped`, and `Unknown` are evidence results. Recovery begins only after a confirmed stop.
- Every timer, message callback, file watcher, worker process, window, and native resource needs an idempotent cleanup path.
- Configuration snapshots, watched targets, and update-protection settings are committed in one transaction. Tests must not read or overwrite personal `watchdog.ini` files.
- The abandoned GDI screenshot-overlay smooth-scrolling approach must not return; the ListView and log retain native scrolling.
- DPI, icon, dark-mode, hierarchy, and accessibility claims must be backed by actual Windows and scaling evidence. Automation does not replace a physical display matrix.

## 3. Validation commands

Run in Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-fast.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-windows-integration.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

- `verify-fast.ps1` avoids LFS font downloads and GUI startup while checking dependencies, static boundaries, update/install transactions, repository policy, leak history, and workflows.
- `verify.ps1` adds all 39 AHK core and integration tests to the fast gate.
- `verify-windows-integration.ps1` verifies complete font hashes and creates real Windows controls across 13 languages, three window levels, and GDI/USER handle reclamation.
- `reproducible-build.ps1` builds the portable ZIP, source ZIP, optional font ZIP, and SBOM twice, compares every SHA-256, and verifies all three extracted package directories.

GitHub Actions classifies changed paths first. Documentation-only changes run only the fast gate; runtime changes add Windows/GUI integration; non-documentation pushes to `main` and release-engineering pull requests add reproducible packaging. A formal release still reruns every layer.

AutoHotkey and Ahk2Exe versions are not pre-pinned in the repository. Every manual release queries the latest stable AutoHotkey release and latest published Ahk2Exe release, freezes one resolved snapshot, then uses that exact snapshot for tests, both builds, the SBOM, and packaging. Validation-only tools such as actionlint and Gitleaks remain pinned. The release records the actual versions, sources, commits, and SHA-256 values used. Third-party versions, sources, licenses, and hashes are documented in [Third-party notices](project/THIRD_PARTY_NOTICES.en.md).

## 4. Release and contribution

User-visible changes must update every localized README and the changelog. Use the [changelog template](en/changelog-template.md) for new versions and describe observable additions, changes, and fixes rather than copying commit messages or internal class names.

See the [release process](en/release-process.md) and [formal release checklist](en/publication-checklist.md). An ordinary pull request must not create a version tag or rewrite a published tag.

Issues and pull requests should describe a reproducible problem, its risk, and verification evidence. For windows, DPI, icons, or dark mode, include the actual Windows version and scale tested. See [Contributing](../.github/CONTRIBUTING.en.md) and [Governance](project/GOVERNANCE.en.md).

Project code is available under the [MIT License](../LICENSE). Embedded and bundled components remain under their own licenses; releases include the AutoHotkey license and corresponding source archive. PingFang, SF Pro Text, and Apple SD Gothic Neo are provided under the project owner's commercial redistribution authorization and are not covered by the MIT License.

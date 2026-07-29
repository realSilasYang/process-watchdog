# 📋 Changelog

[简体中文](../CHANGELOG.md) | **English**

This project follows [Semantic Versioning](https://semver.org/) and uses change
categories based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 🚧 [Unreleased]

## 🎉 Version [2.0.3] - 2026-07-29

### 📦 Release Assets

- **`process-watchdog-2.0.3-windows-x64.exe` (standalone executable):** Requires no AutoHotkey installation and runs immediately after download; intended for a quick trial or users who need a single program file.
- **`process-watchdog-2.0.3-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, fonts, and runtime resources; intended for long-term use after full extraction or for manual deployment.
- **`process-watchdog-2.0.3-source.zip` (complete source package):** Includes the AHK source, modules, tests, documentation, and fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.

---

### ✨ Added

- **Renamed and moved target recovery**: A directly added program or script can be recovered after it is renamed, its parent directory is renamed, or it is moved within the same volume while the assistant is running, when the file system permits reopening files by Windows file ID. When that capability is unavailable, only a complete Windows rename event is accepted as fallback evidence; similar names are never guessed.
- **Path confirmation and history**: Detection freezes restart work only for the affected item and presents the previous path, new path, and evidence in a localized confirmation window. Confirmation changes only the monitored path, preserves the name, icon, arguments, environment, runtime, and update-protection settings, and supports undo and redo.

---

### 🚀 Improvements

- **Main-window command buttons**: Add, Pause/Resume, and Delete now use fixed icon slots. Pause and Resume use a common geometric canvas, while character icons are centered from their rendered raster ink. Text and icons no longer shift across state changes, theme switches, or high-DPI redraws.
- **Target-state presentation**: Waiting for path confirmation has a dedicated status icon and exception priority. List sorting, the status bar, and the supervisor now distinguish a missing target, pending confirmation, and normal initialization.
- **Interface overview**: All thirteen README languages continue to share one canonical preview, now updated to the current main-window screenshot.

---

### 🐛 Fixed

- **Resume after a paused target was renamed**: Fixed an item remaining indefinitely in Initializing after its target was renamed while monitoring was paused. A stale directory-activity signal no longer blocks recovery when update protection is disabled.
- **Missing-target detection order**: File identity is checked before restart decisions when the target was renamed but its old process is still alive, process snapshots are temporarily unavailable, or a single-instance notice has just closed. This prevents path changes from being treated as application stops and avoids duplicate launches.
- **Transactional path migration**: Manual path edits and automatic recovery now share target-conflict, shortcut, and runtime-configuration validation. A failed configuration write rolls the whole transition back, preventing disagreement among the list, runtime state, and INI persistence.

## 🎉 Version [2.0.2] - 2026-07-29

### 📦 Release Assets

- **`process-watchdog-2.0.2-windows-x64.exe` (standalone executable):** Requires no AutoHotkey installation and runs immediately after download; intended for a quick trial or users who need a single program file.
- **`process-watchdog-2.0.2-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, fonts, and runtime resources; intended for long-term use after full extraction or for manual deployment.
- **`process-watchdog-2.0.2-source.zip` (complete source package):** Includes the AHK source, modules, tests, documentation, and fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.

---

### ✨ Added

- **Runtime and search discovery**: Added general runtime, interpreter, argument, and environment configuration for script monitoring. When Everything is not running, the assistant can discover and start a local instance silently, or provide the official download entry when it is not installed.
- **GUI accessibility semantics**: Added the Windows button role, localized default action, and keyboard activation to owner-drawn buttons, with symmetric lifecycle cleanup.

---

### 🚀 Improvements

- **Window hierarchy and taskbar behavior**: Minimizing a child no longer minimizes its owner. Restoring it rebuilds ownership, modal state, taskbar grouping, and focus on the direct owner.
- **Release and validation evidence**: Added offline GUI validation records to the portable package; release gates now cover 13 languages, theme hot switching, window resource soaking, and packaged Markdown links.
- **Interface overview**: Updated the single README interface preview to the current main-window screenshot and kept all release documentation on the same canonical resource.

---

### 🐛 Fixed

- **Window-destruction cleanup**: Fixed an isolated GUI test fixture missing the accessibility-service dependency, which caused `#Warn` output and false interaction-registration residue reports.
- **Packaged documentation links**: Fixed the portable package omitting the GUI validation record, which made the README's offline relative link invalid.
- **Initial pointer in Add Item**: Confirmed the pointer remains on the Search button after window activation, preventing complex startup timing from restoring its previous position.

## 🎉 Version [2.0.1] - 2026-07-28

### 📦 Release Assets

- **`process-watchdog-2.0.1-windows-x64.exe` (standalone executable):** Requires no AutoHotkey installation and runs immediately after download; intended for a quick trial or users who need a single program file.
- **`process-watchdog-2.0.1-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, fonts, and runtime resources; intended for long-term use after full extraction or for manual deployment.
- **`process-watchdog-2.0.1-source.zip` (complete source package):** Includes the AHK source, modules, tests, documentation, and fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.

---

### 🚀 Improvements

- Centered Lucide icons, button text, main-list status icons, and footer text by
  their visible glyph bounds rather than asymmetric font line boxes, keeping a
  common visual axis at both 100% and 300% DPI.
- Made first-time Settings page construction, control visibility, and tab-state
  updates complete within one redraw transaction, reducing text and page-content
  flashes during tab switches.
- Standardized all thirteen README languages on the latest main-window screenshot
  as the single interface overview, removing the obsolete light image and dual-image
  theme switcher.
- Standardized changelogs and GitHub Releases on scannable emoji headings and
  explicit asset contents, runtime requirements, and intended uses. Historical
  notes now describe the assets that were actually published.

---

### 🐛 Fixed

- Fixed font hot-switching or a failed status SVG or administrator overlay
  detaching the main ListView image list and hiding some or all application icons.
  An optional enhanced icon can no longer remove the base application icons.
- Fixed status icons failing, shifting, or appearing at the cell's upper-left when
  only a vertical offset was supplied and an empty horizontal coordinate was
  parsed as an invalid integer.

- Standardized UTF-8, JSON, compiler paths, and ZIP bytes across Windows
  PowerShell 5.1 and PowerShell 7. CI now compares its two release builds across
  both hosts instead of treating same-host repetition as cross-host reproducibility.
- Made complete Actions artifacts retain hidden directories, preventing the
  upload step from filtering extracted `.github` community files. The three
  GitHub Release user assets were not affected by that filter.
- Restored the CodeBookmark-aligned emoji headings and changelog categories.
  Release validation now checks each public asset's exact name, edition role,
  included content, runtime requirement, and intended use.

---

## 🎉 Version [2.0.0] - 2026-07-28

### 📦 Release Assets

- **`process-watchdog-2.0.0-windows-x64.exe` (standalone executable):** Requires no AutoHotkey installation and runs immediately after download; intended for a quick trial or users who need a single program file.
- **`process-watchdog-2.0.0-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, fonts, and runtime resources; intended for long-term use after full extraction or for manual deployment.
- **`process-watchdog-2.0.0-source.zip` (complete source package):** Includes the AHK source, modules, tests, documentation, and fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.

---

### ⚠️ Important Notes

- `v1.0.0` cannot update itself. Moving to `v2.0.0` requires one manual download
  and complete package replacement; later EXE and source editions can use the
  built-in updater.
- Application search now requires a running Everything service. There is no
  built-in full-disk fallback or application-side result limit; folder import is
  unaffected.
- A Git source clone requires Git LFS and `git lfs pull`. The source ZIP attached
  to a Release already contains the complete font assets and needs no Git LFS.

---

### ✨ Added

- Added complete self-update flows for EXE, Git source, and ordinary source
  editions, with background startup checks and manual checks. Updates verify the
  version, manifest, SHA-256 inventory, and entry metadata, then wait for the new
  process to initialize configuration, windows, and core monitoring. Failure
  restores both application files and personal configuration.
- Added Simplified Chinese, Traditional Chinese (Hong Kong), Traditional Chinese
  (Taiwan), English, Japanese, Vietnamese, Korean, Spanish, French, Brazilian
  Portuguese, Russian, German, and Italian. The interface follows Windows by
  default and can switch language and font in place without restarting monitoring.
- Added a complete light theme and a Follow system option. Light and dark themes
  now cover the main window, every dialog level, menus, tooltips, inputs, tabs,
  scrollbars, and disabled states.
- Added the Help Information chooser, feedback entry, and donation window. The
  guide and runtime log are now selected from one main-window entry.
- Added an automatically numbered main-list column and semantic colored status
  icons. BAT and CMD items can open a separate standard-output and error log when
  that batch target was actually launched and captured by the assistant.

---

### 🚀 Improvements

- Reworked core scheduling, per-target controllers, task generations, and the
  mutation queue. Pause, resume, deletion, ordering, path changes, undo, and redo
  now share one state-commit path, reducing full-list reloads, stale callbacks,
  and duplicate probes.
- Strengthened identification for executables, scripts, shortcuts, and indirect
  installer entries by combining process snapshots, command lines, working
  directories, parent-child relationships, privileges, and file evidence.
  Unknown probe results never trigger a blind restart.
- Reorganized Settings into General, Monitoring & Launch, Stop Policy, Logs, and
  About, with consistent modern tabs, buttons, inputs, selectors, spacing, and
  DPI layout. Version, runtime, update, and project links now live under About.
- Standardized the main window, context menus, and dialogs on semantic vector
  icons without emoji and rounded interaction states. Improved ListView columns,
  icon scaling, selection and disabled feedback, window ownership, and redraw
  stability after resizing.
- Reworked language-specific content fonts. Installed fonts are preferred, then
  packaged licensed or OFL private fonts, then matching Noto fallbacks. Buttons,
  Settings tabs, and the footer use the language-specific system UI bold font.
- Generated `watchdog.ini` comments now follow all thirteen interface languages.
  Section names, keys, and values remain compatible, and repeated saves or
  language changes do not accumulate stale comments.
- Documented that EXE and source editions in one directory share configuration,
  while separate directories are independent. Shortcuts and scheduled startup
  keep only the last selected daily entry and can switch safely between editions.
- Consolidated governance, contribution, security, support, third-party notices,
  localized documentation, application assets, examples, and build output into
  dedicated directories. The README now provides an overview image and clearer
  installation, usage, diagnostics, and contribution routes.
- Restricted official publication to manual dispatch from `main`. Each release
  resolves the latest stable AutoHotkey and latest Ahk2Exe release, then runs the
  full test suite, two reproducible builds, SBOM and checksum generation,
  provenance, and draft-asset verification before publication. The versioned EXE
  and complete `dist` output remain available as artifacts.
- Ordinary CI now uses a hash-pinned repository toolchain snapshot and Actions
  cache, so unrelated upstream changes cannot destabilize it. A read-only manual
  dry run exercises the same dynamic toolchain and gates as a formal release.
- Release conflict handling, the three-asset allowlist, GitHub digests, and body
  checks now use one tested state machine. It can resume a same-commit draft or
  recover an orphaned same-commit tag, then audits the tag, commit, body, and
  asset hashes again after publication.

---

### 🐛 Fixed

- Fixed short-lived duplicate launchers, privilege mismatches, transient probe
  failures, and application updates being mistaken for a stopped target, which
  could wrongly restart single-instance software or leave recovery in a loop.
- Fixed resumed items retaining a paused status after restart, manual ordering not
  persisting, deletion undo reinitializing every target, and stale asynchronous
  callbacks overwriting newer multi-selection state.
- Fixed child-window minimize or close actions affecting the main window, footer
  and button content not fully repainting after resize, light-theme disabled-state
  timing, lost selection backgrounds, and inconsistent input focus behavior.
- Fixed blurred multi-size icons, black transparency, off-center non-square icons,
  and loading or caching of SVG and common custom image formats.
- Fixed updater handling for Git worktrees, renamed entries, manifest-granularity
  changes, stale check results, partial startup failure, and incomplete
  configuration rollback. The old entry remains intact until the final
  same-volume atomic replacement.
- Fixed release builds against current Ahk2Exe, checksum parsing, draft-resume exit
  codes, English batch-import punctuation, and a small set of untranslated status
  messages.
- Fixed Releases incorrectly attaching a standalone SBOM and checksum list. The
  page now contains only the standalone EXE, portable ZIP, and source ZIP, while
  automatic update prefers the asset SHA-256 supplied by the GitHub Release API.

## 🎉 Version [1.0.0] - 2026-07-23

### 📦 Release Assets

- **`process-watchdog-1.0.0-windows-x64.zip` (complete Windows x64 package):** Contains the compiled application, documentation, licenses, status icons, and runtime dependencies; it runs after full extraction without a separate AutoHotkey installation.
- **`process-watchdog-1.0.0-windows-x64.spdx.json` (SPDX software bill of materials):** Records the application, embedded AutoHotkey runtime, and third-party component versions, licenses, and sources for review and supply-chain verification.
- **`SHA256SUMS.txt` (SHA-256 checksum list):** Records checksums for the Windows ZIP and SPDX file so downloads can be checked for completeness and transfer damage.

---

### ✨ Added

- Monitoring for processes, scripts, and shortcuts.
- Evidence-based three-state probing, shared scheduling, and automatic recovery.
- Update protection, a dark GUI, and custom display names and icons.
- Atomic configuration persistence, undo/redo, logs, and system integration.
- Local diagnostics, Windows CI, resource soak tests, reproducible builds,
  release verification, and an SPDX SBOM.
- Quick start, installation, configuration, diagnostics, troubleshooting,
  compatibility, and contribution documentation.
- Full-history Gitleaks validation, CODEOWNERS, governance, and public-repository privacy checks.

---

### 🚀 Improvements

- Separated personal runtime configuration from the tracked example configuration.
- Moved core monitoring, inspection, execution, configuration, maintenance,
  diagnostics, and GUI lifecycle responsibilities into dedicated modules.
- Moved main-window icons, button interaction, runtime adapters, item commands,
  state logging, and system integration out of the root entry.
- Extended the weekly GUI stability run to 30 minutes with full controls and a
  three-level window hierarchy.
- Tagged releases now run their own GUI gate and two reproducible builds, then
  publish a standalone SPDX SBOM, complete checksums, and GitHub provenance.
- Recorded GitHub Actions and actual compiler executables by hash. Releases include
  the AutoHotkey license, full source for the exact embedded commit, and the resolved
  toolchain snapshot used for that build.
- Updated GitHub Actions to current major versions based on Node.js 24 while
  retaining full commit-SHA pins.

---

### 🐛 Fixed

- The rounded-button renderer retains its GDI+ DLL module reference through
  initialization and can shut down and reinitialize reliably during exit/reload.
- The Export Diagnostics button registers hover and click callbacks in the
  correct order and responds reliably as a real control.
- Background scans use `DirExist` for directory boundaries and bounded retries
  for transient temporary-file locks. Tests report protocol, actual files, and
  cleanup failures separately.

[Unreleased]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.3...HEAD
[2.0.3]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/realSilasYang/process-watchdog/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/realSilasYang/process-watchdog/releases/tag/v1.0.0

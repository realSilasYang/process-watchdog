# 📋 Changelog

[简体中文](../CHANGELOG.md) | **English**

This project follows [Semantic Versioning](https://semver.org/) and uses change
categories based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 🚧 [Unreleased]

## 🎉 Version [2.0.10] - 2026-08-08

### 📦 Release Assets

- **`fonts.zip` (optional font package):** Provides the preferred and fallback fonts for installation into Windows; it is not required to run the application.
- **`process-watchdog-2.0.10-source.zip` (complete source package):** Includes the AHK source, modules, tests, and documentation without fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.
- **`process-watchdog-2.0.10-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, and runtime resources without fonts; no AutoHotkey installation is required, and it is intended for long-term use after full extraction.
- **Everything ([latest official version](https://www.voidtools.com/downloads/)):** Provides the index and background service used by application searches. The bundled `Everything64.dll` is only an IPC client and cannot replace Everything itself.

---

### 🚀 Improved

- **Clearer settings categories:** The former General and Monitoring & Startup pages are reorganized into separate Display, Startup, and Monitoring pages, forming five responsibility-focused tabs together with Stop Policy and Logs. Scheduled-task status is queried only after opening Startup, so the initial Settings window no longer waits for that check.
- **More compact settings forms:** Descriptive fields now place their labels above their values, align each page to a shared left edge, and center the group by its longest control. Startup options are stacked vertically, while path fields and dividers use the space their content needs with less unused spacing.
- **More consistent visual hierarchy:** Display adds semantically colored icons for display, language, font, and theme; text-only Save buttons share a deep-green background; and the main-list pseudo-header centers its labels without changing the alignment of underlying data columns.
- **Updated interface overview:** Every localized README continues to share one main-window preview, now showing the current interface with common watched-target types and distinct runtime states.

---

### 🐛 Fixed

- **Selectable text and stable first paint:** Every editable and read-only text box now supports direct text selection. Decorative backgrounds no longer intercept mouse drags or repaint over inputs later, so text is complete as soon as a window opens instead of appearing only after hover.

---

## 🎉 Version [2.0.9] - 2026-08-05

### 📦 Release Assets

- **`fonts.zip` (optional font package):** Provides the preferred and fallback fonts for installation into Windows; it is not required to run the application.
- **`process-watchdog-2.0.9-source.zip` (complete source package):** Includes the AHK source, modules, tests, and documentation without fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.
- **`process-watchdog-2.0.9-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, and runtime resources without fonts; no AutoHotkey installation is required, and it is intended for long-term use after full extraction.
- **Everything ([latest official version](https://www.voidtools.com/downloads/)):** Provides the index and background service used by application searches. The bundled `Everything64.dll` is only an IPC client and cannot replace Everything itself.

---

### 🐛 Fixed

- **More stable continuous main-window resizing:** Right-side buttons, the list, and the pseudo-header now move and refresh only their affected regions, while the parent window and stable left-side controls avoid whole-window redraw suspension, preventing flicker and stale trails during dragging.

---

### 🚀 Improved

- **Full product name in child-window titles:** Settings plus update confirmation and error windows now begin with the full Process Watchdog Assistant name in every interface language.

---

## 🎉 Version [2.0.8] - 2026-08-03

### 📦 Release Assets

- **`fonts.zip` (optional font package):** Provides the preferred and fallback fonts for installation into Windows; it is not required to run the application.
- **`process-watchdog-2.0.8-source.zip` (complete source package):** Includes the AHK source, modules, tests, and documentation without fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.
- **`process-watchdog-2.0.8-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, and runtime resources without fonts; no AutoHotkey installation is required, and it is intended for long-term use after full extraction.
- **Everything ([latest official version](https://www.voidtools.com/downloads/)):** Provides the index and background service used by application searches. The bundled `Everything64.dll` is only an IPC client and cannot replace Everything itself.

---

### ✨ Added

- **Manual restart for watched targets:** The context menu now includes Restart, which closes the current target under the configured stop policy and launches it again. Paused targets resume monitoring as part of the operation, while upgrade protection or an uncertain process identity prevents unsafe termination.

---

### 🚀 Improvements

- **Context actions follow the operating workflow:** Restart, Stop Running, Edit Full Path, and Open File Location now appear in that order, and Process Identification and Launch Settings appears before the administrator toggle so frequent actions are easier to find.
- **Clearer application-icon rendering:** The main list prefers a real native frame with an appropriate size from ICO, EXE, DLL, and CPL resources, then applies high-quality scaling instead of accepting a system-prescaled image with blurred or distorted edges.
- **Consolidated About and support entry points:** About replaces the former Donate button in the main window and opens a dedicated child window for version, runtime, update checking, Donate, and project access. Help and Donate terminology plus feedback and project hover hints are streamlined consistently.
- **More stable font-list browsing:** The UI content-font list displays a fixed 12 rows and preserves the user's current scroll position after installed fonts are refreshed instead of jumping back to the selected item.
- **More recognizable update icon:** The refresh icon now uses the existing blue-violet update semantic while retaining the ordinary toolbar-button background and text treatment.

## 🎉 Version [2.0.7] - 2026-08-01

### 📦 Release Assets

- **`fonts.zip` (optional font package):** Provides the preferred and fallback fonts for installation into Windows; it is not required to run the application.
- **`process-watchdog-2.0.7-source.zip` (complete source package):** Includes the AHK source, modules, tests, and documentation without fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.
- **`process-watchdog-2.0.7-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, and runtime resources without fonts; no AutoHotkey installation is required, and it is intended for long-term use after full extraction.
- **Everything ([latest official version](https://www.voidtools.com/downloads/)):** Provides the index and background service used by application searches. The bundled `Everything64.dll` is only an IPC client and cannot replace Everything itself.

---

### 🚀 Improvements

- **More explainable process-identification diagnostics:** When startup is delayed because an existing process cannot be verified reliably, the log now records the observation source, reason, and reason code, with throttling for repeated causes so command-line, process-path, snapshot, and probe-configuration uncertainty is easier to separate.
- **More transparent content-relocation flow:** Content-based moved-target recovery now records missing-state stabilization, search roots, scan method, failed or timed-out scans, rejected candidates, duplicate copies, and misses so users are not left with a black-box “no relocation” result.
- **Clearer Everything dependency experience:** Program search distinguishes the bundled `Everything64.dll` from the Everything application itself, tries to locate and start Everything when the background instance is not responding, and shows specific error meanings, discovery details, or the official download entry when recovery fails.
- **More readable main interface:** The status-information column default width increases from 180 to 200, and the README interface overview now uses the current main-window screenshot.
- **Cleaner release-engineering output:** Reproducible builds now default to a controlled temporary directory and clean it up automatically, while CI, dry-run, and formal release workflows explicitly write to `dist` so local preflight runs do not leave build artifacts behind.

---

### 🐛 Fixed

- **Everything failure-message stability:** Fixed Everything-unavailable diagnostic text composition that could trigger an AutoHotkey ternary-expression parse error.
- **About-page information-column layout:** Version and runtime information columns now use the About page divider bounds, preventing the row from crossing the divider or inheriting the settings-form right margin.
- **Open File Location file-manager routing:** Explorer still selects the file when it is the system default file manager; otherwise the default file manager opens the containing directory.

## 🎉 Version [2.0.6] - 2026-07-31

### 📦 Release Assets

- **`fonts.zip` (optional font package):** Provides the preferred and fallback fonts for installation into Windows; it is not required to run the application.
- **`process-watchdog-2.0.6-source.zip` (complete source package):** Includes the AHK source, modules, tests, and documentation without fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.
- **`process-watchdog-2.0.6-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, and runtime resources without fonts; no AutoHotkey installation is required, and it is intended for long-term use after full extraction.
- **Everything ([latest official version](https://www.voidtools.com/downloads/)):** Provides the index and background service used by application searches. The bundled `Everything64.dll` is only an IPC client and cannot replace Everything itself.

---

### ⚠️ Important Notes

- **Release asset change:** Starting with v2.0.6, the standalone EXE is no longer provided. Upgrades must use either the complete portable package or the source package.
- **Font-loading change:** Application packages no longer include or privately load fonts. To retain the prior preferred-font appearance, the optional font package must be downloaded and installed into Windows.

---

### 🚀 Improvements

- **Simplified program editions:** The release pipeline now builds only the complete portable and source editions. The standalone EXE wrapper, installation script, and corresponding tests have been removed so the same application no longer has three delivery paths.
- **System fonts and optional font package:** Runtime selection now considers only fonts installed in Windows while preserving the existing priority order. Preferred and fallback fonts are distributed separately and no longer appear in application packages or the SBOM.
- **Everything acquisition guidance:** Installation, configuration, and release documentation consistently links to the latest official version and explains that Everything itself supplies indexing and the background service while the bundled DLL only provides IPC.
- **Converged release pipeline:** Builds, reproducibility checks, asset inventories, downloaded-release verification, and the GitHub Release workflow now consistently validate the two application editions and optional font package, with obsolete standalone-EXE branches removed.

---

### 🐛 Fixed

- **Main-list focus clearing:** Clicking an empty main-window surface or empty ListView area now clears both ListView focus and its focused item, preventing a selected target from retaining keyboard-operation focus.
- **Main-window title-bar actions:** Focus-clearing routing no longer intercepts non-client mouse messages, restoring native Windows behavior for minimizing, closing, dragging, and resizing the main window.

## 🎉 Version [2.0.5] - 2026-07-31

### 📦 Release Assets

- **`process-watchdog-2.0.5-windows-x64.exe` (standalone executable):** Requires no AutoHotkey installation and runs immediately after download; intended for a quick trial or users who need a single program file.
- **`process-watchdog-2.0.5-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, fonts, and runtime resources; intended for long-term use after full extraction or for manual deployment.
- **`process-watchdog-2.0.5-source.zip` (complete source package):** Includes the AHK source, modules, tests, documentation, and fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.

---

### ✨ Added

- **Content-based moved-target recovery:** Directly added programs and scripts retain an exact-size and SHA-256 content baseline. After the file or a parent folder is renamed, or the file moves across folders or volumes, the monitored path can be updated once unchanged content is confirmed, including moves made while the assistant was closed. File names, file IDs, and directory notifications are not identity evidence.
- **Dark native path editing:** The main list's in-place full-path editor now uses the active input background and text colors consistently from the context menu, double-click, and F2.

---

### 🚀 Improvements

- **Efficient conservative relocation scans:** The nearest surviving directory is scanned first. Broader searches use Everything to narrow candidates by compatible extension and exact size before a separate worker computes complete hashes. Multiple identical copies or an incomplete scan never cause a guessed relocation.
- **Batch path editing:** During multi-selection full-path editing, Enter saves the current item and advances to the next; Escape still cancels only the current edit.
- **True stop-target command:** Stop Running replaces Restart in the context menu. It pauses monitoring before applying the configured stop policy so the target is not immediately launched again.
- **System shortcuts and feedback:** Shortcut creation independently writes and verifies both the desktop entry and the Start menu All apps entry, then notifies Windows Shell. Success hides the action button and shows the complete confirmation text; error dialogs align the icon, message, and buttons consistently.
- **Dark first-frame presentation:** Before the main window first becomes visible, its title bar, list, header, status bar, and command buttons are painted while DWM composition is cloaked, reducing white startup frames in dark mode.
- **Downloaded-release final audit:** After the formal workflow matches the local build against GitHub metadata and publishes the Release, it downloads the hosted standalone EXE, portable ZIP, and source ZIP, checks their digests again, extracts both archives, and reruns the complete package verifier. The dynamic formal-release toolchain snapshot remains distinct from the pinned ordinary-CI snapshot so the audit cannot use the wrong reference.

---

### 🐛 Fixed

- **Guard-state convergence:** Fixed a content-relocation callback argument mismatch that aborted the main monitor before process observation, leaving several running targets in Initializing, and fixed missing targets oscillating between Waiting for process state and Missing.
- **Main-window first display:** Fixed command buttons other than Add occasionally remaining blank until hover or click, and fixed delayed initial status-bar content.
- **Consistent path-edit entry:** Fixed F2 falling through to the ListView default handler and creating a second light editor. Theme changes also refresh an active in-place editor.
- **Reload and shortcut errors:** Reload handoff now targets an explicit window handle and tolerates the old window exiting between operations, preventing Target window not found. Shortcut failures now identify the entry that was not completed.

## 🎉 Version [2.0.4] - 2026-07-30

### 📦 Release Assets

- **`process-watchdog-2.0.4-windows-x64.exe` (standalone executable):** Requires no AutoHotkey installation and runs immediately after download; intended for a quick trial or users who need a single program file.
- **`process-watchdog-2.0.4-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, fonts, and runtime resources; intended for long-term use after full extraction or for manual deployment.
- **`process-watchdog-2.0.4-source.zip` (complete source package):** Includes the AHK source, modules, tests, documentation, and fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.

---

### ✨ Added

- **Main-list keyboard control:** When the main list has focus, Space pauses or resumes monitoring for the selected targets. Multiple selections and mixed states are toggled item by item, while key-repeat messages are suppressed to prevent rapid state reversal.

---

### 🚀 Improvements

- **Watched-target terminology:** The interface, logs, configuration comments, and all thirteen README languages now use terminology that consistently identifies a watched target, instead of switching among application, monitored item, and project in the same context.
- **Branding and interface overview:** Refreshed the high-resolution transparent logo and application icon used by the README, application windows, tray, taskbar, and release packages. The README overview now also shows the current main window.
- **Release-note structure:** Existing and future release notes keep automated validation inventories out of the user-facing change summary, preserving clear sections for version changes and the three downloads while detailed evidence remains in project records and Actions logs.
- **Release-preflight reliability:** Added a single local preflight entry point that prepares a checksum-verified portable PowerShell 7, refreshes the build tools, and runs the complete release gates in sequence. Packaged-font validation now reads OpenType metadata directly instead of depending on localized family names returned by a particular PowerShell, .NET, or Windows display language.

---

### 🐛 Fixed

- **Log-path action alignment:** Aligned the Browse button on the Log settings page with the left edge of its path field so the action remains visually connected to the setting it changes.

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
- **README branding and interface overview**: All thirteen language home pages now use the same centered high-resolution transparent logo, following the CodeBookmark structure, and continue to share the updated current main-window preview.
- **Donation copy**: The Donate button now uses a shorter tooltip, while the donation window and all thirteen README languages guide users directly to the available support methods.

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

[Unreleased]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.10...HEAD
[2.0.10]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.9...v2.0.10
[2.0.9]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.8...v2.0.9
[2.0.8]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.7...v2.0.8
[2.0.7]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.6...v2.0.7
[2.0.6]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.5...v2.0.6
[2.0.5]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.4...v2.0.5
[2.0.4]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.3...v2.0.4
[2.0.3]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/realSilasYang/process-watchdog/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/realSilasYang/process-watchdog/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/realSilasYang/process-watchdog/releases/tag/v1.0.0

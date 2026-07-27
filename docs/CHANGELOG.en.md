# Changelog

[简体中文](../CHANGELOG.md) | **English**

This project follows [Semantic Versioning](https://semver.org/) and uses change
categories based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.0] - 2026-07-27

### Release editions

- `process-watchdog-1.1.0-windows-x64.exe`: Standalone executable. AutoHotkey is not required; download and run it directly.
- `process-watchdog-1.1.0-windows-x64.zip`: Complete portable package with the EXE, documentation, licenses, fonts, and runtime resources for long-term extraction or manual deployment.
- `process-watchdog-1.1.0-source.zip`: Complete source package with AHK source, modules, tests, documentation, and fonts. Source mode requires AutoHotkey v2 x64 on the computer.

### Important notes

- `v1.0.0` cannot update itself. Moving to `v1.1.0` requires one manual download
  and complete package replacement; later EXE and source editions can use the
  built-in updater.
- Application search now requires a running Everything service. There is no
  built-in full-disk fallback or application-side result limit; folder import is
  unaffected.
- A Git source clone requires Git LFS and `git lfs pull`. The source ZIP attached
  to a Release already contains the complete font assets and needs no Git LFS.
- Update protection remains disabled by default. Enable it per target and verify
  its recognition during one real application update.

### Added

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

### Changed

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

### Fixed

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

## [1.0.0] - 2026-07-23

### Added

- Monitoring for processes, scripts, and shortcuts.
- Evidence-based three-state probing, shared scheduling, and automatic recovery.
- Update protection, a dark GUI, and custom display names and icons.
- Atomic configuration persistence, undo/redo, logs, and system integration.
- Local diagnostics, Windows CI, resource soak tests, reproducible builds,
  release verification, and an SPDX SBOM.
- Quick start, installation, configuration, diagnostics, troubleshooting,
  compatibility, and contribution documentation.
- Full-history Gitleaks validation, CODEOWNERS, governance, and public-repository privacy checks.

### Changed

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

### Fixed

- The rounded-button renderer retains its GDI+ DLL module reference through
  initialization and can shut down and reinitialize reliably during exit/reload.
- The Export Diagnostics button registers hover and click callbacks in the
  correct order and responds reliably as a real control.
- Background scans use `DirExist` for directory boundaries and bounded retries
  for transient temporary-file locks. Tests report protocol, actual files, and
  cleanup failures separately.

[Unreleased]: https://github.com/realSilasYang/process-watchdog/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/realSilasYang/process-watchdog/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/realSilasYang/process-watchdog/releases/tag/v1.0.0

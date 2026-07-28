# Installation, upgrades, and removal

[简体中文](../installation.md) | **English**

## Release package

Each Release offers only three downloads: a standalone EXE, a complete portable
ZIP, and a complete source ZIP.

- The standalone EXE embeds the complete portable package. On first run it verifies
  the embedded SHA-256, version, and update manifest, then performs a rollback-safe
  installation under `%LOCALAPPDATA%\ProcessWatchdog\Standalone`. Running the
  launcher from any location starts that stable installation, and an older launcher
  never downgrades an installation that has already updated itself.
- The complete portable ZIP is for users who want explicit control over installation,
  backup, and migration. Fully extract it and keep the EXE, `assets/`, and
  `third_party/` at their relative paths; do not copy only the inner EXE.
- The complete source ZIP is for review, development, and source execution and
  requires local AutoHotkey v2 x64.

Both compiled editions support long-term use. The standalone EXE keeps managed
program files in a stable local-app-data directory, while the portable ZIP keeps
program files and personal configuration in the directory selected by the user.

`v1.0.0` predates self-update and contains no update helper, so it cannot initiate
its own upgrade. Move to `v2.0.0` by downloading and fully replacing the package
manually. Releases after that bootstrap step can use Check for Updates in Settings.

The standalone EXE and portable ZIP include the required AutoHotkey runtime. AutoHotkey v2 x64 is
needed only when running from source. `licenses/sources/` also contains the full
AutoHotkey source archive for the exact embedded runtime. Its version, commit,
and hashes are recorded in `build-metadata/toolchain.resolved.json`. This is the
actual toolchain snapshot resolved and frozen at the start of that release, not
a repository-pinned AutoHotkey or Ahk2Exe version.

A Git source clone also requires Git LFS. Run `git lfs pull` after the initial
clone and after updates. Complete bundled fonts are LFS objects, including a CJK
collection larger than GitHub's ordinary per-object limit. The interface may
fall back to system fonts when only pointer files are present, but builds and
release verification intentionally fail. A Release source ZIP already contains
the complete fonts and does not require Git LFS.

Search for applications requires Everything to be installed and running. The
Everything SDK DLL included in the package only connects to that service; the
assistant does not fall back to a local full-disk scan when it is unavailable.
Monitoring, manual file selection, and batch import of a selected folder do not
depend on Everything.

The assistant, AutoHotkey, and Ahk2Exe have independent version numbers. Updating
the complete EXE package also updates its embedded AutoHotkey runtime. A source
update keeps using the same local interpreter and does not install or upgrade it.
Ahk2Exe exists only during the official release build. See
[Versions, runtime forms, and update responsibility](versioning.md).

## General settings

Open General in Assistant Settings to create Desktop and Start menu
shortcuts or an elevated logon scheduled task, and to configure startup behavior,
language, content font, and theme. About shows the current assistant version,
runtime form, actual AutoHotkey version, and manual update check. Disabling
automatic startup removes only a task created by this application whose ownership
identity still matches.

Both compiled and source runtime forms are supported. An EXE-created shortcut points
to the actual runtime EXE. A source-created shortcut points to the current AutoHotkey interpreter and
passes the main AHK file as an argument. The scheduled task records the current
form in the same way. Desktop, Start menu, and scheduled-task entries use one
product name, so only one form is integrated at a time:

- Creating shortcuts from the other form updates the entries with the same names.
- If General finds a project-owned task for the other form, it shows
  Switch and updates the task to the current form. An unrelated same-name task
  remains a conflict.
- Existing shortcuts and tasks need no rebuild when an automatic update keeps
  the entry path unchanged.

If a portable EXE and source entry temporarily share one directory, they share configuration
but also share release resources and the update manifest. Do not independently
auto-update both forms in that layout. Keep long-lived, independently updated
installations in separate directories, then recreate or switch the shortcuts and
scheduled task under General for the chosen everyday entry.

## Upgrade

Check for assistant updates at startup is enabled by default, and About offers
an immediate check. A new release is announced first;
files are never replaced silently. After confirmation:

- Official compiled edition: downloads the complete Windows x64 ZIP, verifies it
  against the SHA-256 digest supplied by the GitHub Release API, exits the main
  process, replaces managed files in the actual runtime directory, and restarts.
  A standalone installation updates the inner program under
  `%LOCALAPPDATA%\ProcessWatchdog\Standalone`; the originally downloaded launcher
  remains unchanged and continues to start the newer installed version.
- Git source: requires every tracked file to be clean, allows only a fast-forward
  to the official release tag, and restarts through the original AutoHotkey
  interpreter. Local changes or divergent history are never overwritten.
- Non-Git source package: downloads the project-built source ZIP, verifies the
  GitHub-provided SHA-256 digest, replaces source-managed files, and restarts.

If archive replacement fails partway through, the helper restores backed-up
managed files. Other failure paths also attempt to restart the current entry and
record both the error and call location in `ProcessWatchdogUpdateErrors.log`
under the system temp directory. A compiled EXE inside a Git source repository
is not allowed to overwrite that repository; run the update from the source
entry instead.

Manual upgrade remains supported: exit the old instance, back up both state
files, fully extract the new package into a new directory, copy the configuration,
and follow any one-time migration notes in the Release.

A release never includes `watchdog.ini` or `watchdog.maintenance.ini`, so replacing
program files does not overwrite personal configuration or unfinished
update-protection sessions. The current version accepts only the
nine-field monitoring record documented in the README. Unparseable records are
moved to `[Recovery]` instead of being silently deleted.

## Remove

Disable automatic startup from General and exit the application. Delete the selected
directory for portable or source installations. For a standalone installation,
delete both the downloaded launcher and `%LOCALAPPDATA%\ProcessWatchdog\Standalone`.
Desktop and Start menu shortcuts can be deleted normally. The monitoring list is
not stored in the registry.

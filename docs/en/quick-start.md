# Common scenarios

[简体中文](../quick-start.md) | **English**

## Monitor a desktop application

Select Add and choose the main EXE. The assistant prefers the full executable
image path when identifying a process. If a matching target is already running,
its PID identity is adopted instead of launching a duplicate.

## Monitor a shortcut

Add the LNK directly. The shortcut remains the launch entry and retains its
embedded arguments, while the resolved application is used for liveness checks.
For MSI shortcuts or applications whose internal path changes with each version,
the assistant combines installation-directory candidates with current process
evidence to choose the main program conservatively.

## When a target file is renamed or moved

If a directly added EXE or script is renamed while the assistant is running,
moved elsewhere on the same volume, or moved because a parent folder was
renamed, the assistant first resolves the same file by its Windows volume
serial number and file ID. On a file system without usable file IDs, an
explicit rename event is used as a fallback. A different EXE is never guessed
merely because it is the only one left in the old folder.

When a candidate is found, pending restart work for that item is frozen and a
confirmation window shows the previous path, new path, and identity evidence.
Update monitored path preserves the display name, icon, arguments, environment,
runtime, and update-protection settings, and the change can be undone. Ignore
keeps the old path and returns the item to its normal missing-target state.
Rename confirmation is suppressed while update protection is evaluating or
handling an update, so an updater's backup file is not presented as a new
target.

Reliable automatic recovery is not possible if the file was renamed while the
assistant was not running, moved to another volume, or stored on a file system
that supplies neither a stable file ID nor a complete rename event. In those
cases, edit the path manually by double-clicking it in the main list.

## Monitor scripts and command-line tools

AHK, Python, JavaScript, PowerShell, BAT, CMD, Ruby, Perl, PHP, Lua, JAR, and
Shell targets are supported. Script identity requires command-line evidence.
While the background command-line snapshot is pending, the state remains
unknown or waiting; it is not misreported as stopped.

Right-click a direct script and open Process Identification and Launch Settings
to configure a general launch environment:

| Setting | Purpose | Example |
| --- | --- | --- |
| Launcher or runtime | Pins the executable that actually runs the script | A virtual environment's `python.exe`, `AutoHotkey64.exe`, `pwsh.exe`, `node.exe`, or `java.exe` |
| Runtime arguments | Belong to the runtime and precede the target path | PowerShell `-NoProfile -File`, Java `-jar`, or AutoHotkey `/ErrorStdOut` |
| Working directory | Supplies the CWD for relative files, modules, and configuration | The project root or script directory |
| Target arguments | Follow the target path and are passed to the script or task | `--config production.json` |
| Environment variables | Temporarily override the launch environment, one per line | `NODE_ENV=production` or `PATH=C:\Tools;%PATH%` |

The resulting order is `"launcher" runtime-arguments "target-path"
target-arguments`. These fields apply only the next time the assistant launches
the target; they neither restart nor modify a process that is already running.
Leave the launcher blank to retain the target type's default behavior. Runtime
fields are hidden for shortcuts and ordinary EXEs. An LNK must preserve its
installer, working-directory, and embedded-argument semantics, while an EXE runs
directly. For a more elaborate wrapper, add an explicit launch script or
shortcut as the monitored target.

## Search with Everything

The bundled `Everything64.dll` is an Everything SDK IPC client. It submits
queries to an already running Everything background instance; it contains no
indexer and cannot scan disks or replace the full Everything application. When
the search window opens without an available instance, the assistant performs a
bounded lookup in registry entries, standard install directories, `PATH`, and
desktop or Start-menu shortcuts. If `Everything.exe` is found, it is started
silently with the official `-startup` argument before the query is retried.

If Everything is not installed, the search window provides a clickable link to
the official latest-version download page. The assistant never falls back to a
main-thread full-disk scan and applies no application-level result limit. Folder
batch import does not depend on Everything.

## Require administrator privileges

Enable Run as administrator in the item settings. If an already running target
does not have the required privileges, the main window reports a mismatch. A
context-menu restart launches it with elevation according to the saved setting.

## Protect an application that updates itself

Update protection is disabled by default. Enable it manually after confirming
the installation directory. The assistant combines updater processes,
parent-child relationships, command lines that reference the installation root,
and file changes before entering update mode. Monitoring resumes only after the
target file becomes available and stable again.

If the application exposes a clear Check for updates command, you can also begin
and end explicit maintenance from the Update Protection window.

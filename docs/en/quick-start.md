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

If a directly added EXE or script is renamed, one of its parent folders is
renamed, or the file is moved across folders or volumes, the assistant first
narrows candidates by compatible extension and exact size, then verifies the
complete SHA-256 content hash. The content baseline is stored with the
configuration, so recovery also works for moves made while the assistant was
closed. File names, Windows file IDs, and directory notifications are not used
as identity evidence.

When a candidate is found, pending restart work for that item is frozen and a
confirmation window shows the previous path, new path, and identity evidence.
Update monitored path preserves the display name, icon, arguments, environment,
runtime, and update-protection settings, and the change can be undone. Ignore
keeps the old path and returns the item to its normal missing-target state.
Rename confirmation is suppressed while update protection is evaluating or
handling an update, so an updater's backup file is not presented as a new
target. A version-directory update is a restricted exception described under
Protect an application that updates itself below.

Scanning runs in a separate worker process and does not block monitoring or the
interface. If more than one identical copy is found in a completed search scope,
or any search scope cannot be scanned completely, the assistant does not guess;
it keeps the old path and retries later.

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
does not have the required privileges, the main window reports a mismatch. To
restart it under the new setting, use Stop Running and then resume monitoring;
the next monitored launch uses elevation according to the saved setting.

## Protect an application that updates itself

Update protection is disabled by default. Enable it manually after confirming
the installation directory. The assistant combines updater processes,
parent-child relationships, command lines that reference the installation root,
and file changes before entering update mode. Monitoring resumes only after the
target file becomes available and stable again.

If the application exposes a clear Check for updates command, you can also begin
and end explicit maintenance from the Update Protection window.

Updater learning occurs only after a real update changes the target file and
completes successfully. The updater must have a complete path inside the target's
installation footprint, and its signature is stored as a full path scoped to the
installation root. Global `msiexec` or `winget` tools, temporary-directory
programs, name-only candidates, and failed updates do not leave permanent
records. An unfinished session preserves only confirmed transient updaters and
pending signatures so evaluation can continue after restarting the assistant.

For targets under version directories such as `2.0.10` or `v2.0.11`, the
assistant checks sibling version directories after an update and target-file
change have been confirmed. It proposes relocation only for exactly one
same-named entry and continuously verifies that candidate's SHA-256. Multiple
candidates, duplicate copies, or incomplete scans remain unresolved. A process
whose image path is temporarily inaccessible is accepted only when the update
is already confirmed, the same-named candidate is unique, and its creation
identity matches the pre-update process or it started recently.

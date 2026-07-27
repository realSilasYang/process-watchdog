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

## Monitor scripts and command-line tools

AHK, Python, JavaScript, PowerShell, BAT, and CMD targets are supported. Script
identity requires command-line evidence. While the background command-line
snapshot is pending, the state remains unknown or waiting; it is not misreported
as stopped.

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

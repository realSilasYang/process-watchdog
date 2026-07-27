# Troubleshooting

[简体中文](../troubleshooting.md) | **English**

## A running application is reported as possibly stopped

Open Runtime Log and identify whether the target is an EXE, script, or shortcut.
For shortcuts, inspect the resolved target in the log. Scripts may need to wait
for the background command-line snapshot. Do not launch another copy while the
assistant is waiting for evidence.

For a Windows Installer shortcut, the target may live in a versioned directory.
Adding the shortcut again can refresh the resolved identity. If several
candidates remain equally plausible, specify the real main program explicitly
in the target settings.

## Update protection never finishes

Check whether the installation root is too broad, updater rules match unrelated
processes, or the installer still holds the target file. You can end explicit
maintenance in Update Protection. The assistant then repeats file-readiness and
stability checks instead of launching blindly.

## Privilege mismatch

If a running target does not satisfy Run as administrator, the list reports a
privilege mismatch. Restart it from the context menu so the assistant can stop
the current instance and launch it elevated under the saved configuration.

## Reload fails

Reload first starts a separate parser validation. If validation fails, the old
instance continues monitoring. Inspect the logged script location, or run:

```powershell
AutoHotkey64.exe /ErrorStdOut ".\进程守护小助手.ahk" --startup-validation
```

## The GUI stalls or resource use keeps increasing

Close the search, folder-import, and log windows and check whether responsiveness
returns. Then export a diagnostics bundle and record the Windows version, display
scale, monitor count, and the shortest repeatable interaction sequence.

In a development checkout, run:

```powershell
.\tests\run-gui-tests.ps1 -SoakSeconds 300
```

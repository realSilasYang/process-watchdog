# Configuration, backup, and recovery

[简体中文](../configuration.md) | **English**

`watchdog.ini` is the local runtime configuration. It uses UTF-16 LE and is
written by atomic replacement. Git does not track it.
`config/watchdog.example.ini` documents current defaults and fields with inline
comments; use it as a reference, not as a replacement for an existing
configuration.

The application generates configuration comments in the active interface
language: Simplified Chinese, Traditional Chinese (Hong Kong), Traditional
Chinese (Taiwan), English, Japanese, Vietnamese, Korean, Spanish, French,
Brazilian Portuguese, Russian, German, or Italian. Section names, keys, and
values are never translated.
The repository example keeps the default Chinese comments while every language
uses the same stable keys. Saving a language change immediately replaces
generated comments from the previous language instead of stacking duplicates.

`UiLanguage=auto` follows the Windows UI language. The General page
can select a language manually, or the setting can contain one of `zh-CN`,
`zh-HK`, `zh-TW`, `en-US`, `ja-JP`, `vi-VN`, `ko-KR`, `es-ES`, `fr-FR`,
`pt-BR`, `ru-RU`, `de-DE`, and `it-IT`. Auto mode
falls back to English for unsupported system languages. Saving applies the new
language inside the current process. The main-window title, buttons, current
status text, context menu, and tray update immediately; short-lived windows are
closed and recreated in the new language when next opened. New logs, diagnostics,
and update checks use the new language, while existing log entries keep the text
originally recorded. Guard tasks, target controllers, PID identity, scheduled
work, the main window, and the ListView handle are not rebuilt.

`UiFont=auto` resolves the content font for the active language through the table below. A preferred
font must be installed and must produce the requested face through Windows GDI.
Otherwise, the assistant privately loads the matching Noto family from
`assets/fonts`. Private fonts are visible only to the current process and are
never installed into Windows. The final Windows font is used only if the packaged
resource is missing or cannot be loaded.

| Interface language | Preferred family | Packaged Noto fallback | Final Windows fallback |
| --- | --- | --- | --- |
| Simplified Chinese | PingFang SC | Noto Sans CJK SC | Microsoft YaHei UI |
| Traditional Chinese（Hong Kong） | PingFang HK | Noto Sans CJK HK | Microsoft JhengHei UI |
| Traditional Chinese（Taiwan） | PingFang TC | Noto Sans CJK TC | Microsoft JhengHei UI |
| Japanese | Harano Aji Gothic | Noto Sans CJK JP | Yu Gothic UI |
| Korean | AppleSDGothicNeoR00 | Noto Sans CJK KR | Malgun Gothic |
| English, Vietnamese, Spanish, French, Portuguese（Brazil）, Russian, German, and Italian | SF Pro Text | Noto Sans | Segoe UI |

Preferred families were selected from the actual files and internal family names
in the user-specified Apple font directory. That directory contains no Hiragino
Japanese font, so Japanese uses the complete UI-suitable, OFL-licensed
`Harano Aji Gothic` family found there. Its regular face is packaged as a
private resource. The original PingFang collection, SF Pro Text regular and
bold faces, and Apple SD Gothic Neo regular face are packaged under the project
owner's commercial redistribution authorization. Auto mode still prefers an
installed copy and loads these external resources only when the family is absent.
Second-level fallbacks come from the user-selected Google
`NoTofu` collection: the Latin resource retains its variable weight and width
axes, while the original CJK collection retains all 45 faces and regional
families. Fonts ship as external `assets/fonts` resources in the complete
package rather than being embedded in the EXE. The font directory records the
separate OFL and commercial authorization boundaries.

The General page can also select any font installed on the current computer.
Saving applies the font immediately in the same process along with the language.
This setting affects body text, inputs, lists, the About title and metadata, and
other content controls. Buttons, Settings tabs, and the main-window footer ignore
`UiFont`; they always use the Windows UI font in the table's final column at bold
weight and never load a packaged font for that purpose. An invalid or uninstalled
configured font falls back to `auto` instead of being passed through to the
interface.

## EXE and source configuration relationship

The real runtime entry determines the configuration location. The downloaded
standalone EXE is a bootstrapper, not a configuration root:

- The standalone EXE installs the complete application under
  `%LOCALAPPDATA%\ProcessWatchdog\Standalone` and reads both personal-state files
  there. Files beside the downloaded bootstrapper do not participate.
- A portable `进程守护小助手.exe` and `进程守护小助手.ahk` in the same directory share
  `watchdog.ini` and `watchdog.maintenance.ini`.
- In different directories, each form reads and writes its own local files;
  configurations are not synchronized automatically.
- Both forms use exactly the same format. A machine-wide single-instance lock
  prevents them from running concurrently.
- Exit the active instance before switching forms. Copy both state files to the
  new actual runtime directory when settings should follow. For the standalone
  EXE that destination is the `LOCALAPPDATA` path above.
- Same-directory coexistence is recommended only for temporary switching tests.
  EXE and source packages share release directories and one
  `update-manifest.json`, so they are not two independently auto-updatable
  installations. Keep long-lived forms in separate directories and copy both
  state files only after fully exiting the assistant when needed.

`CheckUpdatesOnStartup=1` checks for a new assistant version in a separate
background process after startup. Set it to `0` to disable only the startup
check; the About page can still check manually.

## Monitored items and launch environments

Each `AppN` under `[Apps]` has nine stable fields:

```text
Enabled|RunAsAdmin|Path|WorkDir|Args|EnvVars|ResolvedTarget|ResolvedTargetManual|ShortcutArgs
```

Except for booleans and the target path, text is encoded as `<HEX>`. Do not add
field separators or edit encoded data by hand. `[Maintenance]`, `[Display]`,
`[Launch]`, and `[Identity]` use the matching `AppN` key and are committed atomically with
`[Apps]`.

`[Launch]` exists for an item only when a custom launcher or runtime is set:

```text
AppN=<HEX RuntimePath>|<HEX RuntimeArgs>
```

- `RuntimePath` is the executable path for Python, AutoHotkey, PowerShell,
  Node.js, Java, Ruby, Perl, PHP, Lua, Bash, or another runtime.
- `RuntimeArgs` belongs to that runtime. The fixed command order is
  `"RuntimePath" RuntimeArgs "TargetPath" Args`; use `-jar` here for a JAR.
- Leaving both fields blank preserves the default launcher for the target type
  and does not change existing items.
- A custom runtime applies only to a direct script or document-style target. A
  shortcut continues to launch through its LNK, while an ordinary EXE launches
  directly, so the interface hides irrelevant fields for those target types.
- `EnvVars` uses one `KEY=VALUE` per line. Values may refer to existing variables
  such as `%PATH%`. Overrides exist only around the assistant's one target-launch
  call and never permanently modify Windows or the assistant environment.

`[Identity]` is maintained automatically for direct file targets:

```text
AppN=FileSize|SHA256
```

The exact size narrows candidates and the complete SHA-256 hash confirms their
content. This baseline supports recovery after the file or a parent folder is
renamed, after cross-folder or cross-volume moves, and after moves made while
the assistant was closed. File names, Windows file IDs, and directory
notifications are not identity evidence. Do not edit this section manually.

If `[Launch]` or `[Identity]` cannot be decoded, its source text is moved to `[Recovery]` with
the corresponding monitored item rather than registering an incomplete launch
environment or content identity. Undo, redo, path changes, and row ordering also
preserve these fields as part of the item snapshot.

## Back up

Exit the assistant, then copy:

- `watchdog.ini`: settings, window layout, monitored items, launch environments,
  update protection, and display customization.
- `watchdog.maintenance.ini`: unfinished update-protection sessions only; it is
  normally empty.

When a write fails, the existing configuration remains intact and a low-frequency
backoff retry is scheduled. Monitoring records that cannot be parsed, together
with their related update and display values, are moved to `[Recovery]` for
manual review.

## Restore

While the application is not running, place the backup beside the EXE or main
AHK script. If the backup comes from a release with a different field format,
follow that release's one-time migration instructions. Do not rely on a removed
legacy compatibility branch.

## Privacy boundary

Configuration and runtime logs may contain application paths, arguments, and
environment variables. Remove anything you do not want to publish before filing
an issue. Export Diagnostics is an explicit local action and never uploads data
automatically.

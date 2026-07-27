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

The entry file's directory always determines the configuration location; the
file type does not:

- `进程守护小助手.exe` and `进程守护小助手.ahk` in the same directory share
  `watchdog.ini` and `watchdog.maintenance.ini`.
- In different directories, each form reads and writes its own local files;
  configurations are not synchronized automatically.
- Both forms use exactly the same format. A machine-wide single-instance lock
  prevents them from running concurrently.
- Exit the active instance before switching forms. Copy both state files to the
  new entry directory when settings should follow; no copy is needed when the
  entries already share one directory.
- Same-directory coexistence is recommended only for temporary switching tests.
  EXE and source packages share release directories and one
  `update-manifest.json`, so they are not two independently auto-updatable
  installations. Keep long-lived forms in separate directories and copy both
  state files only after fully exiting the assistant when needed.

`CheckUpdatesOnStartup=1` checks for a new assistant version in a separate
background process after startup. Set it to `0` to disable only the startup
check; the About page can still check manually.

## Back up

Exit the assistant, then copy:

- `watchdog.ini`: settings, window layout, monitored items, update protection,
  and display customization.
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

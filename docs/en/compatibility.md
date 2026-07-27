# Compatibility and known limitations

[简体中文](../compatibility.md) | **English**

## Supported environment

| Area | Current baseline |
| --- | --- |
| Operating system | Windows 10 x64 and Windows 11 x64 |
| Source runtime | AutoHotkey v2 x64; the latest upstream stable release is recommended |
| Release build | Each manual release uses the then-current latest stable AutoHotkey and latest published Ahk2Exe, and records the actual versions in the package |
| Display scaling | Target physical matrix at 100%, 125%, 150%, 175%, and 200% |
| File system | Local NTFS; the program directory must permit configuration and session writes |

CI runs startup, core, real-GUI, and compiled-build validation on Windows Server
2022. Automation cannot replace physical displays. Scaling values, multi-monitor
layouts, per-monitor DPI transitions, and high-contrast combinations not
physically tested for a release must be identified as unverified in the Release
notes rather than inferred to work.

## Known limitations

- Only x64 is supported. There are no Windows 7, 32-bit, or non-Windows builds.
- GIF and ANI custom icons show a static representative frame in the ListView;
  animation is not played.
- WebP requires a system WIC codec or Shell thumbnail provider.
- Custom dark controls depend on the actual Windows 10/11 theme implementation;
  minor differences between Windows builds are possible.
- Only the current nine-field configuration format is accepted. A breaking
  upgrade requires migration steps in the corresponding Release.
- The project retains native ListView scrolling. The rejected GDI
  screenshot-overlay smooth-scrolling implementation is intentionally absent.

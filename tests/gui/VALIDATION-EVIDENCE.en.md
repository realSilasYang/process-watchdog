# Windows GUI Validation Evidence

[简体中文](VALIDATION-EVIDENCE.md) | **English**

This file records reproducible local facts. Code-path coverage and automated
screenshots are not presented as a manual visual sign-off. Any environment not
listed here remains unverified on real hardware.

## Local Record: 2026-07-29

| Item | Recorded result |
| --- | --- |
| Windows | Windows 11, build 26200 |
| Display | 3072 x 1920, Intel Arc 130T (driver 32.0.101.6554) |
| Actual window DPI | 192, or 200%; read from `GetDpiForWindow` on a real AHK GUI, not inferred from a process-DPI probe |
| AutoHotkey | v2.0.26 x64 |
| Theme | System dark at the time; production windows passed in-process dark and light hot-switch coverage |
| High contrast | Not enabled and not validated |

### Passed automation

`tests\verify-windows-integration.ps1 -SoakSeconds 15` passed with:

- Real GUI smoke: `GUI_SMOKE|PASS|dpi=192|sequenceWidth=96`.
- Log window, all 13 UI languages, and production child-window lifecycle/resource cleanup.
- Dark/light hot switching: `DISPLAY_HOT_SWITCH|PASS|languages=13|gdiDelta=1|userDelta=-1`.
- Full UI resource loop in the release gate: `RESOURCE_SOAK|PASS|seconds=15|iterations=205|gdiDelta=0|userDelta=0|maxGdi=40|maxUser=16`.
- Additional five-minute resource soak: `RESOURCE_SOAK|PASS|seconds=300|iterations=3687|gdiDelta=0|userDelta=0|maxGdi=40|maxUser=16`.
- The Windows MSAA name, push-button role, and localized default action of
  owner-drawn rounded buttons are read in-process by
  `tests/core/rounded-button-renderer-tests.ahk`; Enter, Space, and the
  required Tab-focus style have regression assertions.

### Physical acceptance still not covered

- Manual visual checks at actual 100%, 150%, and 300% display scaling.
- Continuous per-monitor DPI movement across multiple displays.
- Windows high-contrast mode and end-to-end screen-reader narration.

These limits are also retained in the [manual regression matrix](MANUAL-REGRESSION.en.md).
Release notes and READMEs must not state that they are complete.

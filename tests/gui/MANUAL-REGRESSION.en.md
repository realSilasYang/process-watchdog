# Manual GUI regression matrix

[简体中文](MANUAL-REGRESSION.md) | **English**

Automation cannot change physical display topology. Before release, cover at
least the matrix below and preserve the version, Windows build, GPU, scale, and
result.

Every CI run performs a short complete-UI soak. The weekly workflow runs the
same scenario for 30 minutes, repeatedly covering rounded buttons, input
registration, the log viewport, icon lists, and three window levels. The table
below records only physical-display and visual evidence that automation cannot
replace.

| Scenario | 100% | 150% | 200% | 300% |
| --- | --- | --- | --- | --- |
| Main-window first display and minimum size | Not tested | Not tested | Not tested | Not tested |
| Main-list icon transparency, sharpness, and centering | Not tested | Not tested | Not tested | Not tested |
| Settings tabs and inputs are not clipped | Not tested | Not tested | Not tested | Not tested |
| Every button hover, press, and release | Not tested | Not tested | Not tested | Not tested |
| Log resize, maximize, and scrollbars | Not tested | Not tested | Not tested | Not tested |
| Support opens the guide or runtime log correctly | Not tested | Not tested | Not tested | Not tested |
| Donation QR codes are sharp, complete, and scannable | Not tested | Not tested | Not tested | Not tested |
| Minimizing a child does not minimize its parent | Not tested | Not tested | Not tested | Not tested |
| Cross-monitor drag and continuous DPI changes | N/A | Not tested | Not tested | Not tested |

Also check:

- Light, dark, and Windows high-contrast modes.
- Keyboard-only add, settings save, log selection, and window close.
- Touchpad, wheel, and scrollbar dragging retain native behavior without white flashing.
- Every pseudo-header field in the main and application-search lists cycles through ascending, descending, and custom/source order; the fourth click returns to ascending.
- Text inputs use an I-beam cursor; logs and scrollbars use the normal cursor.
- A screen reader announces important buttons, setting labels, and status text.

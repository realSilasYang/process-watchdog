# Local diagnostics

[简体中文](../diagnostics.md) | **English**

Open Runtime Log, select Export Diagnostics, and choose a destination directory.
The application collects files in the system temporary directory, compresses
them into a ZIP, and removes the temporary directory. It never uploads the
bundle automatically.

The bundle contains:

- Application, Windows, and AutoHotkey versions; DPI; and GDI/USER handle counts.
- Total, enabled, and paused item counts plus monitoring and update phase summaries.
- Scheduler queue, configuration warnings, recovery records, and log counts.
- Current and recent work-gate owners, hold times, contention counts, and sustained-contention warnings.
- Recent success, categorized failure, retry time, and cumulative counts for background process-snapshot and file-scan workers.
- The current runtime log text.
- Dependency locks and resvg/Everything version records.

The complete `watchdog.ini` is not copied, and the state summary does not list
every target path. The runtime log can still contain paths and arguments, so
review `runtime-log.txt` before sharing a bundle publicly.

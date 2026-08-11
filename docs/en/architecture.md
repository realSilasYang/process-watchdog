# Architecture and correctness boundaries

[简体中文](../architecture.md) | **English**

This document is for maintainers and contributors reviewing monitoring
correctness. For user operations, start with [Common scenarios](quick-start.md)
and [Configuration](configuration.md).

## Design principles

The project distinguishes “the target cannot currently be confirmed as running”
from “the target is confirmed stopped.” Every liveness probe returns `Running`,
`Stopped`, or `Unknown`; recovery begins only from reliable stopped evidence.
Before any asynchronous callback writes state, it revalidates the target path,
controller instance, generation, and task token.

The main thread performs only fast native probes and UI projection. WMI
command-line queries, file scans, and folder imports run in hidden short-lived
workers and deliver an atomic result file. A timeout, incomplete result, identity
mismatch, or application shutdown rejects the entire result.

## Module boundaries

- `进程守护小助手.ahk` is the composition root and only includes modules,
  assembles dependencies, and starts the application.
- `app` composes application services and connects runtime adapters, commands,
  logs, system integration, and concrete windows.
- `src/Config` owns runtime settings, layout, monitored items, display settings,
  update configuration, and historical snapshots.
- `src/Update` coordinates the self-update worker, atomic result, and shutdown
  boundary; network and file replacement live in `runtime/application-update.ps1`.
- `src/Core` owns probe results, per-target controllers, the shared scheduler,
  the work gate, and retry policy.
- `src/Inspection` owns process, command-line, shortcut, file-integrity, and
  directory-change evidence.
- `src/Execution` centralizes external effects such as launch, window close,
  Ctrl+C, and staged termination.
- `src/Maintenance` owns update-protection state, evidence matching, and session recovery.
- `src/UI` owns ListView projection, icon resources, interaction registration,
  and window ownership.
- `src/Diagnostics` creates local diagnostics without automatic upload.

Modules under `src` receive dependencies through constructors or callbacks and
do not read the root globals `App`, `Main`, or `GuiModules`. A class instance owns
each short-lived GUI. Closing must stop timers, unregister messages, terminate
workers still owned by the current session, release native resources, and only
then destroy the window.

## Target identity and liveness

`TargetSpecsService` creates separate `LaunchSpec` and `ProbeSpec` values. A
launch specification says only how to start; a probe specification says only how
to confirm running state. Cache fingerprints include only inputs that affect the
corresponding behavior.

A normal EXE prefers its complete image path and PID creation identity. A script
requires interpreter command-line evidence. An existing LNK remains the launch
entry, while `ShortcutTargetResolver` resolves the application, embedded
arguments, MSI component, and installation-directory candidates for probing. If
the shortcut temporarily disappears, only a previously confirmed target may be
used for recovery. Equally ranked candidates are never resolved by guessing.

A direct script may additionally specify a runtime path and runtime arguments.
`TargetLauncher` builds the command in the order runtime, runtime arguments,
quoted target path, and target arguments. Python virtual environments,
AutoHotkey, PowerShell, Node.js, Java, Ruby, Perl, PHP, Lua, Bash, and other
runtimes therefore share one launch model. Leaving the runtime blank preserves
the target type's default launch behavior. An LNK remains the launch entry and
is never bypassed by a custom runtime. A custom runtime is recorded in the
`LaunchSpec` and also adds its full executable path as a constraint to the
corresponding script `ProbeSpec`. Probing still requires the target path in the
runtime command line, so another script hosted by the same runtime cannot be
mistaken for the target. Environment values expand `%VARIABLE%` references
before launch and temporarily override the assistant's process environment only
around the one `Run` call; the original environment is restored
unconditionally.

`ProcessSnapshotService` indexes each WMI snapshot by path, name, and command
target. An expired snapshot, inconsistent record count, unreadable fields, or a
missing creation identity yields unknown without clearing a known identity. PID
and creation identity are also checked before terminating a worker, preventing a
reused PID from identifying an unrelated process. Publication time and the
worker-start request generation are tracked separately. A short one-shot timer
polls only the result file, never WMI on the UI thread, so a long monitoring
interval cannot delay delivery of an already completed snapshot.

## Controllers, scheduling, and races

Every value in `App.appStates` is a distinct `TargetSupervisor`. It owns the
monitoring phase, PID identity, retry count, generation, snapshot handshake, and
restart/verification tokens. When restart preflight or launch verification lacks
a fresh snapshot, it makes one asynchronous generation-bound request. A result
may resume the task only when it belongs to that request and arrives before the
finite deadline; permanently unreadable evidence is not treated as a transient
wait. Pause, delete, launch- or probe-input changes, undo, maintenance protection,
and shutdown advance the generation and clear the handshake. Re-adding the same
path cannot accept a callback from the previous controller.

All targets share one `WatchdogScheduler`. A due-time min-heap and one resettable
timer replace a permanent timer per item. Heap operations use short critical
sections; business callbacks run in normal thread state. `GuardWorkGate`
serializes main monitoring, updater scanning, directory events, and explicit
maintenance. A busy gate briefly reschedules work without blocking the UI. The
gate records current and recent owners, hold times, contention sources, and
rate-limited sustained-contention warnings for diagnostic export.

After fast retries are exhausted, `RestartPolicy` continues at the final
configured interval; successful probing resets the count. Controller ownership
is rechecked before and after any launch or stop operation that can wait.

## Update protection

Update protection is disabled by default. When enabled it uses the `Normal`,
`Arbitrating`, `Updating`, `Stabilizing`, `Recovering`, and `TimedOut` states. An
updater needs evidence such as a full path, installation root, command line that
references the root, or a target parent-child chain. Actor caches use PID plus
creation identity, so PID reuse cannot extend protection.

After an update that changes the target file, a scoped updater signature can be
learned. Only the full path of a dedicated program inside the installation root
can become permanent evidence; process names, global installer tools, temporary
paths, and paths without a scope root cannot. When a shortcut target moves, the
final installation root is resolved before learned signatures are checked.
Unfinished sessions preserve confirmed transient updater identities and pending
learning candidates atomically in `watchdog.maintenance.ini`, and are used only
while a real unfinished state exists.

Normal content relocation still requires the original exact size and complete
SHA-256. When a direct-file target is under a recognized version directory,
update protection may accept exactly one same-named entry under the same parent
as a restricted candidate after a target-file change. The candidate's own
SHA-256 is recorded and continuously verified, and relocation still requires
user confirmation; ambiguity or an incomplete scan prevents migration. During
update recovery only, an inaccessible process image may be accepted when the
unique same-named process has the pre-update creation identity or recent-start
evidence. Normal probing never enables this fallback.

## Configuration and history

`WatchdogConfigRepository` exclusively owns `watchdog.ini`. Settings, layout,
and monitored-item changes are first applied to a sibling temporary copy. Section
comments are restored and all edits completed before one replacement of the
official file. The transaction remains intact from the ordered runtime snapshot
through replacement. Failure preserves the old file and schedules one
exponential-backoff retry.

Portable EXE and source modes use `A_ScriptDir` as the configuration root. Entries
in one directory share state and separate directories are independent. The global
mutex permits only one running instance. A separate PowerShell process checks
for self-updates, and the main thread only reads one atomic result file every
250 milliseconds. A process handle, rather than a reusable PID, determines worker
completion and timeout. Results must belong to the running version, and each EXE,
plain-source, or Git-source installation requires only its own applicable assets.

After the parent exits, the installer verifies SHA-256, canonical version, package
kind, entry metadata, and the release manifest before replacing managed paths. A
manifest may not include `watchdog.ini` or `watchdog.maintenance.ini`. Old and new
manifests may change directory granularity; backups collapse their union to outermost
paths. The current entry is copied to backup and remains available until one final
same-directory atomic replacement after other paths are in place. The new entry must
first pass `--startup-validation`. Its normal process then
writes an atomic, versioned readiness signal only after configuration loading, window
assembly, and guard-timer startup, followed by a short stability observation. Before
that normal start, the installer takes byte-accurate snapshots of both personal-state
files. Timeout, early exit, a mismatched signal, or failure to start the core guard
terminates the new process, restores old files or the prior Git commit, and restores
the pre-start `watchdog.ini` and `watchdog.maintenance.ini` state, including removing
a file that did not previously exist. Both ordinary clones and Git worktrees require
a clean tracked worktree and a fast-forward to the official tag.

`[Apps]` has exactly one current nine-field format:

```text
Enabled|RunAsAdmin|Path|WorkDir|Args|EnvVars|ResolvedTarget|ResolvedTargetManual|ShortcutArgs
```

Boolean fields accept only `0` or `1`; non-empty text must decode losslessly. A
wrong field count, legacy plain text, or damaged encoding is not registered as a
target. Its original application, display, launch, content-identity, and update
values are moved to `[Recovery]`. The optional `[Launch]` section uses the
matching `AppN` key for two independent `<HEX>` fields: runtime path and runtime
arguments. The optional `[Identity]` section stores a direct file target's
content baseline as `FileSize|SHA256`, allowing unchanged content to be
confirmed after a file name, directory, or volume changes without treating file
IDs or directory notifications as identity evidence. These sections are
rewritten in the same atomic transaction as `[Apps]`, `[Maintenance]`,
`[Display]`, and `[Recovery]`. This keeps the existing nine-field record stable
while ensuring ordering, undo, redo, and recovery never drop launch-environment
or content-identity data.

Undo and redo use ordered configuration snapshots and per-field three-way
merging. Undo reverses only fields changed by the original operation that still
contain its result. It does not overwrite later edits or newly learned evidence.
If applying history fails, the history pointer does not move and can be retried.

## GUI lifecycle and resources

The main ListView uses a hidden full-path column as row identity and maintains a
path-to-row index. Background state updates locate only the target row. Drag
reordering, deletion, path changes, and history restoration rebuild the index;
projection inconsistencies are detected and repaired. The main window and
application search share a pseudo-header component over headerless native
ListViews. Header clicks sort only the current projection and never persist or
replace the main list's custom order. Each field cycles through ascending,
descending, and custom/source order; the third click restores a hidden stable
order column.

`WindowHierarchyManager` uses reference-counted leases for ownership. While a
child is minimized, native ownership is detached, `WS_EX_APPWINDOW` is applied,
and `WS_EX_TOOLWINDOW` is removed. The window is hidden, shown again minimized,
and registered through `ITaskbarList` as a separate window entry under the same
assistant taskbar icon, without minimizing the main window. Before a taskbar
restore, the entry is unregistered, the original extended style and owner are
reinstated, and the direct parent's modal state is rebuilt. The final lease
restores interaction from the owner's original visibility, enabled, and
minimized state. Explicit close, construction failure, and external native
destruction all converge on one idempotent cleanup order.

`UiInteractionRegistry` owns button, text-input, hover, and press state. Destroyed
controls lose every reference, and disabled buttons do not use a hand cursor.
`IconResourceRegistry` owns image lists, window icons, WIC, SVG rendering, and DPI
rebuild requests. A retired list is destroyed after its use count reaches zero;
a stale DPI callback cannot overwrite a newer generation.

Custom icons support ICO, EXE, DLL, CPL, LNK, PNG, JPG, JPEG, JPE, JFIF, BMP,
GIF, TIF, TIFF, WebP, SVG, and ANI. SVG is rasterized in memory by the pinned
resvg version. Bitmap sources are decoded to premultiplied alpha by WIC, scaled
at high quality, and centered. GIF and ANI show a static representative frame.

Visible sibling controls use the `AtomicControlLayout` transaction. Callers provide
logical coordinates; the module performs one DPI conversion, one batched
`DeferWindowPos` commit, moving-child `WM_ERASEBKGND` protection, old-position
background fill, and old/new-union repaint. The parent is never redraw-suspended, so
stable left controls are not dragged into a whole-window refresh. Unchanged layouts
return `Unchanged`, while an unavailable native commit is explicit through
`Mode: "Fallback"` or `Status: "Failed"`. See the [local layout transaction
specification](ui-layout-transactions.md) for invariants, failure semantics, and a
reusable example.

## Display-setting hot switch

`LocalizationService` retains the requested and resolved language plus the
requested and resolved content font. After Settings saves, `ApplyDisplaySettingsHot`
snapshots every target's rendered state inside a critical section, switches the
language and font, then updates the main-window title, existing control fonts,
six command buttons, statistics, ListView status, context menu, and tray in
place. Dynamic status text recovers placeholder values from the old-language
template and renders them through the new template. Operating-system text with
no provable source template remains unchanged. Content controls continue using
the selected content font. Every button obtains the current language's Windows
UI font at bold weight through the shared interaction-registration path, which
also covers Settings tabs; the main-window footer applies the same font on
creation and hot switch. Resolving this system emphasis font uses installed fonts only.

For language-default fonts, the service asks Windows GDI for the installed preferred
face, an installed Noto fallback, then a native Windows UI font. The optional font
package is only installed by the user into Windows; runtime code never resolves font
asset paths, registers process-private fonts, or releases them at shutdown. The font
package records separate OFL and commercial authorization boundaries, and the project
license does not relicense the commercial files.

The transaction does not replace `App`, `GuardRuntime`, the scheduler, target
controllers, the main window, or the ListView, and target generations do not
change. The short-lived window registry is rebuilt after the main projection
succeeds so later windows use the new language and font. Existing log entries
retain their recorded text. Any failure restores the previous language, font,
and state text. The monitor timer is reset only when its interval actually
changes, independently of display settings.

## Shutdown, reload, and fault convergence

The shutdown coordinator stops monitoring and update coordination, closes GUIs,
releases rendering and private-font resources, persists pending configuration, and finally
releases the single-instance mutex. Each step isolates its own error. Reload
first uses a separate process for startup validation. After success, the
replacement waits for the old instance to finish cleanup and release the mutex.
Validation or startup failure leaves the old instance running instead of
half-shutting it down.

Periodic log refresh, countdown, and scan polling stop their timer before logging
the first failure, preventing a high-frequency exception loop. Batched ListView
updates restore redraw in `finally`. Cancellation, close, and failure share a
session generation and cleanup boundary, so a late worker cannot mutate a new
window.

## Validation and release

Core tests cover configuration boundaries, three-state probing, PID reuse,
shortcut ambiguity, 1,000-item indexing and scheduling, controller-replacement
races, update transitions, window leases, icon formats, diagnostics, and failure
cleanup. The runner compares the personal `watchdog.ini` hash after every success
and failure path.

GUI tests create real rounded buttons, inputs, a read-only log, an icon ListView,
and three window levels. They also save Settings through the real UI path and
cycle all 13 languages and fonts while checking long-lived object identity,
dynamic status, menus, control fonts, interaction registrations, and
GDI/USER handles. CI runs a short soak and a weekly job runs a long soak. Physical
monitors, per-monitor DPI, and high contrast remain manual-matrix responsibilities.

Public-release validation requires a non-shallow clone, scans every commit with
the pinned Gitleaks, rejects personal configuration and temporary probes in
history, and rejects local absolute paths in release text. Builds pin AutoHotkey,
Ahk2Exe, runtime DLL, and optional-font-package hashes, compile through an ASCII-only virtual path, and
validate the compiled startup. Two builds must produce byte-identical portable ZIP, source ZIP, font ZIP,
and SPDX SBOM files. The portable package includes its SBOM, AutoHotkey license,
and source archive for the exact embedded runtime. The complete Actions artifact
retains checksums and the separate SBOM, while provenance covers the two program
editions and optional font package.

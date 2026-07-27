# Contributing

[简体中文](CONTRIBUTING.md) | **English**

Thank you for improving Process Watchdog Assistant through an issue, document,
or code contribution.

Use the structured issue forms for ordinary bugs, features, and improvements.
For usage questions, read [Support](SUPPORT.en.md). Unresolved security issues
must be reported privately according to [Security](SECURITY.en.md).

## Development environment

- Windows 10 or Windows 11 x64.
- AutoHotkey v2 x64; local validation defaults to the most recently resolved
  upstream stable release.
- Windows PowerShell 5.1 or PowerShell 7.
- A complete Git clone. Full-history leak validation rejects shallow clones.

After the first checkout, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
```

The verifier resolves AutoHotkey and Ahk2Exe when needed and downloads pinned
actionlint and Gitleaks tools. An official release always refreshes the first two
from upstream. Third-party DLLs do not need to be
added to the system `PATH`. An incomplete history fails explicitly rather than
producing an under-scoped passing result.

Tests must never read, overwrite, or depend on a developer's personal
`watchdog.ini`. Put minimal configuration fixtures in `tests/fixtures/`, run
them in isolated temporary directories, and remove their temporary copies.

## Change rules

- One commit should express one complete intent without unrelated refactoring or formatting.
- The root script is the composition entry; `src` modules must not read the root
  globals `App`, `Main`, or `GuiModules`.
- Target identity, launch entry, and display customization are independent.
  Display settings must not affect monitoring.
- New behavior needs corresponding core, static, or GUI coverage. Complex
  external state requires failure cases and stale-result counterexamples.
- Every timer, message callback, file watcher, worker process, icon, window
  handle, and COM/GDI resource needs an idempotent cleanup boundary.
- Chinese user-visible text uses full-width parentheses, not a space followed by
  a half-width parenthesis. Every user-visible literal also needs an English
  localization entry.
- Do not reintroduce the abandoned GDI screenshot-overlay smooth scrolling.
  Native scrolling is the current compatibility boundary.
- Before adding a dependency, verify its source and redistribution license, then
  update its version, SHA-256, license,
  `docs/project/THIRD_PARTY_NOTICES.en.md`, and SBOM relationship.
- External GitHub Actions must be pinned to a full commit SHA with a major-version
  comment. Modified workflows must pass the pinned actionlint version. Official
  publication is manual from `main` only.
- Never commit personal `watchdog.ini`, maintenance sessions, diagnostics,
  private paths, arguments, credentials, build products, or temporary probes.

## Minimum validation

| Change | Minimum requirement |
| --- | --- |
| State machine, codec, scheduling, or path logic | Related `tests/core` tests and `tests/verify.ps1` |
| Module boundary, cleanup rule, or visible text | Update `tests/static-check.ps1` and run `tests/verify.ps1` |
| Window, button, input, ListView, log, or icon | Run the related GUI test and record manual observations |
| DPI, dark mode, window hierarchy, or accessibility | Record Windows version, scale, and physical-display evidence |
| Build, dependency, SBOM, or release package | Run `tests/reproducible-build.ps1` and release-layout validation |

The full manual GUI scope is in `tests/gui/MANUAL-REGRESSION.md`. Automation
cannot replace real DPI, multi-monitor, high-contrast, touchpad, or screen-reader
testing. State clearly which combinations remain untested.

## Commits and pull requests

A pull request should explain the problem, user-visible result, key design,
compatibility impact, commands actually run, and untested risks. Include a
redacted screenshot or recording for UI work. For configuration work, describe
the impact on `watchdog.ini`, `watchdog.maintenance.ini`, backup, and recovery.

User-visible changes must update both README languages, both relevant user
documents, and the changelog. Organize a release with the
[changelog template](../docs/en/changelog-template.md). An ordinary pull request
must not create a version tag, change an already released version, or upload an
unverified package manually.

See the [release process](../docs/en/release-process.md) and
[project governance](../docs/project/GOVERNANCE.en.md).

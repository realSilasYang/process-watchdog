## Change

<!-- Explain the original problem, the behavior change, and related issue. Do not only list files. -->

## Design and boundaries

<!-- Explain key decisions, alternatives, and handling of failure, cancellation, reload, shutdown, and stale callbacks. -->

## Compatibility and data impact

<!-- Cover watchdog.ini, watchdog.maintenance.ini, monitoring semantics, update protection, system integration, and existing data. Write “None” when appropriate. -->

- [ ] Configuration remains compatible, or migration, backup, and failure recovery are documented
- [ ] Display name and icon do not change target identity, launch entry, or monitoring
- [ ] Tests do not read, overwrite, or depend on personal `watchdog.ini`
- [ ] No timer, message callback, file watcher, worker, window, or native resource is leaked

## Validation

- [ ] Ran `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1`
- [ ] Added automation for new or repaired behavior
- [ ] For real GUI work, ran `tests/run-gui-tests.ps1` and checked GDI/USER handles
- [ ] For release-boundary work, ran `tests/reproducible-build.ps1`
- [ ] Updated both README languages, both changelogs, and matching documents
- [ ] Did not commit personal configuration, sessions, paths, arguments, credentials, build products, or probes

Commands and results:

```text

```

## GUI and manual validation

<!-- Write “Not applicable” when there is no visible UI change. -->

- Windows version and OS build:
- Display scale and monitor topology:
- Windows, interactions, and states checked:
- Physical environments not covered:

## Screenshot or recording

<!-- Add redacted before/after evidence for UI work; remove this section when not applicable. -->

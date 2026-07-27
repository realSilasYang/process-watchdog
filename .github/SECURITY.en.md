# Security policy

[简体中文](SECURITY.md) | **English**

## Supported versions

Security fixes are released only for the latest version. The affected range,
fixed version, and any required user action are documented in the changelog and
GitHub Release after the fix is available. No fixed long-term support period is
promised for older versions.

## Report a vulnerability privately

Do not disclose an unresolved vulnerability or directly exploitable details in
a public issue, discussion, or pull request. Use GitHub
[Private vulnerability reporting](https://github.com/realSilasYang/process-watchdog/security/advisories/new).
If that entry is temporarily unavailable, make a public request to contact the
maintainer [@realSilasYang](https://github.com/realSilasYang) privately, without
including vulnerability details in the request.

A useful report includes:

- Affected version and distribution method.
- Windows environment, privilege prerequisites, and required user interaction.
- Impact and the smallest reproducible steps.
- Redacted logs, example configuration, or validation evidence.
- Known mitigations and a suggested repair direction.

After confirmation, the maintainer assesses impact, prepares a fix, and
coordinates disclosure. The project does not promise a fixed response time. Do
not distribute exploit details before the fix is public.

## Data and privilege notes

The assistant requires administrator privileges for scheduled tasks, some
process inspection, and some termination operations. Personal configuration,
maintenance sessions, logs, and diagnostics remain local and are never uploaded
automatically. They may contain full paths, arguments, or environment variables;
review and redact them before publishing a report.

Ordinary crashes, UI defects, and monitoring misidentification without a
security impact can use the public bug-report form.

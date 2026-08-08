# Versions, runtime forms, and update responsibility

[简体中文](../versioning.md) | **English**

## Three different versions

The assistant involves three versions with different purposes:

| Name | Purpose | Who maintains it |
| --- | --- | --- |
| Assistant version | Identifies features, configuration behavior, and release contents; stored in EXE metadata or read from `VERSION` in source mode | Updated by the assistant or by replacing the release manually |
| AutoHotkey version | The x64 runtime that executes the AHK code | Embedded and managed by the EXE package; source users install and update AutoHotkey v2 x64 themselves |
| Ahk2Exe version | Used only in GitHub Actions to combine the source and AutoHotkey runtime into an EXE | Users do not install it, and it is not shipped to their computers |

“The assistant is up to date” means that the assistant version matches the latest
official Release. It does not claim that a source user's local AutoHotkey is the
latest version. Conversely, updating local AutoHotkey does not change the
assistant version or its changelog.

## The two program editions

| Item | Complete portable ZIP | Complete source ZIP |
| --- | --- | --- |
| Entry | `进程守护小助手.exe` in the fully extracted directory | Local `AutoHotkey64.exe` plus `进程守护小助手.ahk` |
| AutoHotkey source | Embedded in the EXE | The AutoHotkey v2 x64 installation on this computer |
| Separate AutoHotkey installation | Not required | Required |
| Assistant automatic update | Updates the compiled files in the extracted directory | Safely fast-forwards a Git checkout or downloads and verifies the source package, then validates and restarts with the same interpreter |
| AutoHotkey updated with the assistant | Yes | No; the user maintains the local interpreter separately |
| Configuration directory | Directory containing the portable EXE | Directory containing the AHK entry |

Both program editions run the same functional code and configuration format, but
state is shared only when the real runtime directory is shared. A portable EXE and source
entry in one directory share personal state, release resources, and one update
manifest. A global single-instance lock prevents concurrent forms. Keep long-lived
installations under different runtime roots and recreate or switch shortcuts and
the scheduled task from Startup for the form used every day.

Automatic update accepts only canonical `major.minor.patch` stable versions and
requires the target to be newer. It verifies checksums, package form, entry version,
and managed paths before a hidden quick validation. The normal process must then
finish configuration loading, window assembly, and guard-timer startup and return a
readiness signal. Failure in either phase restores old files for an archive install
or the prior Git commit, restores both personal-state files byte for byte if startup
migrated them, and then restarts the old version. A `.git` file in a Git
worktree is recognized just like the `.git`
directory in a normal clone; a shallow clone fetches the history needed to reach
the target tag first.

## Tool selection for an official release

The repository does not permanently pin the AutoHotkey and Ahk2Exe versions for
future releases. A maintainer manually starts the Release workflow from `main`.
The workflow then:

1. Queries the latest stable upstream AutoHotkey release.
2. Queries the latest published upstream Ahk2Exe release. An upstream prerelease
   is eligible, but a draft is not.
3. Downloads binaries, licenses, and the complete corresponding AutoHotkey
   source, computes SHA-256 values, and freezes one `toolchain.resolved.json`.
4. Uses that one snapshot for core validation, real GUI smoke, resource soaking,
   and two reproducible builds.
5. Embeds that AutoHotkey runtime only after every gate passes. The two program
   editions and optional font package go to GitHub Releases, checksums and the SBOM
   remain in the complete Actions artifact, and provenance covers all three assets.

The official EXE therefore contains the latest stable AutoHotkey selected and
validated when that assistant release began. It does not follow later upstream
changes automatically. A newer upstream runtime reaches users only after a later
assistant release resolves it again, passes the tests, and publishes a new package.

## Where users can inspect the versions

- Main window → About shows the current assistant version, EXE/source form, and
  actual AutoHotkey runtime; update checking, the project link, and Donate are on
  the same child window.
- The same summary is written to the runtime log at every startup.
- EXE file properties contain the compiled assistant version; source mode uses
  the `VERSION` file beside the entry script.
- `build-metadata/toolchain.resolved.json` in an official EXE package records the
  exact AutoHotkey and Ahk2Exe releases, sources, commits, and hashes;
  `SBOM.spdx.json` records their dependency relationships.
- `environment.txt` in a local diagnostics bundle records the assistant version,
  AutoHotkey version, compiled status, and process bitness.

Most users should choose the complete Windows x64 ZIP, which needs no separate
AutoHotkey installation. Choose source mode only when reading, modifying, or
directly running the AHK source, and maintain AutoHotkey v2 x64 separately.
The optional font package is not a program edition. After installation into Windows,
it supplies preferred and Noto fallback families for the existing priority rules.
Application search requires the [latest official Everything release](https://www.voidtools.com/downloads/);
`Everything64.dll` is only an IPC client and cannot replace its index and service.

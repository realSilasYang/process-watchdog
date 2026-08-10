# Release process

[简体中文](../release-process.md) | **English**

Before a local release, run `powershell -ExecutionPolicy Bypass -File
tools\invoke-local-release-preflight.ps1`. This single entry point prepares a
portable PowerShell 7 from its official checksums, refreshes the upstream build
tools for the release, and runs the required tests, 300-second Windows/GUI soak,
and cross-host reproducible build described below. Local artifacts are written to
a controlled temporary directory and removed after success or failure, so the
repository does not retain `dist`; only GitHub Actions explicitly uses runner-local
`dist` for upload and release auditing. It stops on the first failure;
after fixing that failure, rerun the same command.

1. Prepare user-facing entries with the [changelog template](changelog-template.md)
   and create `docs/release-notes/v<version>.md`, then update `VERSION`,
   `CHANGELOG.md`, and `docs/CHANGELOG.en.md`. The build
   injects the executable file version from `VERSION`. Keep `📋` in the document
   title and use `## 🎉 Version [X.Y.Z] - YYYY-MM-DD` for release headings.
   `⚠️ Important Notes` is not a required module and is omitted by default. Add it
   only for incompatible data or configuration, data-loss risk, breaking changes
   to minimum environments, privileges, or defaults, or mandatory migration,
   backup, or replacement steps. State the affected users, risk, and required
   action. Unchanged compatibility, direct-upgrade availability, download advice,
   feature summaries, and ordinary usage tips do not belong there. Every formal release keeps
   `📦 Release Assets` and names all three files with their edition role, included
   content, AutoHotkey requirement, and intended use. This is always the final
   Release-notes section so readers can choose a download after reviewing changes.
   Neither changelogs nor Release notes may add a `✅ Validation Scope` section;
   test counts, soak results, build hashes, and incomplete manual matrices belong
   only in validation evidence and Actions logs.
2. Confirm the repository is not shallow and contains every branch and tag. Run
   `tests/verify.ps1`. It scans the complete history with pinned Gitleaks and
   rejects committed personal configuration, probes, credentials, or local paths
   in current release text.
3. Run `tests/verify-windows-integration.ps1 -SoakSeconds 300`. Do not shorten
   the full pre-release core, font, and UI soak.
4. Reconfirm that the commercial authorization for PingFang, SF Pro Text, and
   Apple SD Gothic Neo still covers the exact files in
   `assets/fonts/metadata.json`, Windows, the public repository, and Release
   distribution. Do not start a formal release without this confirmation.
5. Run `tests/reproducible-build.ps1` and preserve the final SHA-256 output.
   Non-documentation `main` CI, release-engineering pull requests, dry runs, and
   formal releases build once with PowerShell 7 and once with
   Windows PowerShell 5.1. Do not release if the portable ZIP, source ZIP, optional
   font ZIP, or separate SBOM differs between the two hosts, or if
   `SHA256SUMS.txt` does not match.
6. Ordinary CI uses the hash-pinned repository snapshot at
   `tools/ci-toolchain.resolved.json` and classifies changed paths first.
   Documentation-only changes run a no-LFS fast gate; runtime changes add real
   Windows/GUI integration; non-documentation `main` pushes and release-engineering
   pull requests add reproducible packaging. Jobs that need complete fonts do not
   consume LFS transfer quota; they restore the latest published `fonts.zip` and
   verify every file against the current SHA-256 metadata. A genuinely changed
   font must first be supplied through working LFS or another audited channel;
   an old release asset is never accepted as new font content. The dry run and formal release instead query
   the latest stable AutoHotkey and latest published Ahk2Exe, then freeze one
   `toolchain.resolved.json`. Confirm that the package contains the AutoHotkey
   license, corresponding source archive, resolved snapshot, and an SBOM
   consistent with the actual archive hashes.
7. Test affected Windows and DPI combinations in the manual GUI matrix. Record
   completed and missing combinations in the GUI validation evidence and manual
   regression matrix; automation does not replace them, and these records do not
   belong in changelogs or Release notes.
8. Verify both README languages and the matching compatibility, installation,
   and troubleshooting documents against actual behavior. Each changelog item
   describes observable behavior, not a commit title or internal class.
9. Commit all source, tests, and documents and push a release branch. Open a
   release-engineering pull request for that branch and wait for every required
   check, including `verify`, to pass. Do not bypass branch protection by pushing
   directly to `main`. After reviewing the PR commits and changed-file scope, merge
   it with a merge commit, then confirm remote `main` contains that exact merge and
   remains reproducible from Git. Do not create or push the version tag at this stage.
10. Manually run Release dry run from the merged `main`. With read-only permissions, it resolves
    the latest upstream toolchain, executes the same full validation, GUI smoke,
    and two reproducible builds as a formal release, and preserves the full `dist`.
    It never creates a tag, draft, or Release. Do not proceed if it fails.
11. After the dry run passes, manually run Release from that same `main` commit.
    Do not push a version tag first. The workflow rejects tags or drafts from other
    commits and every already-published version. It may safely resume a same-commit
    draft or recover an orphaned same-commit tag; duplicates and inconsistent state
    fail explicitly.
12. The formal workflow resolves upstream tools and runs every gate again. It then
    attests and uploads only the complete portable ZIP, complete source ZIP, and
    optional font ZIP to a draft. The SBOM, `SHA256SUMS.txt`, and remaining `dist` stay in
    the complete Actions artifact, with hidden directories explicitly included.
    The draft body, commit, allowlist, sizes, and
    GitHub SHA-256 digests must match the local build before publication. After
    publication, the workflow audits the public Release and remote tag, downloads
    all three hosted editions, checks their digests again, extracts both ZIPs,
    and reruns the complete package verifier against the toolchain snapshot
    embedded by the formal build. The ordinary CI snapshot is never substituted
    for that release-specific record.

The tag must be in `main` history and is created by the manually dispatched
Release workflow only after every gate passes. Code pushes, tag pushes, schedules,
and ordinary CI never publish. Never rewrite a published tag; release a patch
version for corrections.
Release text uses the corresponding `docs/release-notes/v<version>.md` and the
matching changelog entry as its source of truth, explaining each asset, runtime
requirement, and intended use. Test and manual-acceptance evidence remains in
dedicated validation records.
Each Release contains two program editions (the complete portable ZIP and complete
source ZIP) plus the fixed-name optional package `fonts.zip`. The release-assets
section must follow GitHub's fixed filename order: `fonts.zip`, complete source ZIP,
complete portable ZIP, and then Everything. The Everything URL must be an explicit
Markdown link rather than a bare URL inside bold text. The font package supplies
preferred and fallback UI fonts for installation into Windows and is not required to
run the program. Release notes also link the [latest official Everything release](https://www.voidtools.com/downloads/), explain that it supplies the index and
background service for application search, and state that `Everything64.dll` is only
an IPC client and cannot replace Everything itself. The SBOM, `SHA256SUMS.txt`, and extracted
package directories remain available only in the complete Actions build artifact.
If the final post-publication audit fails, do not delete or overwrite the public
version. Preserve the evidence, diagnose the cause, and issue a new patch release.
Release-state resolution and both audits share the contract in
`tools/ReleaseEngineering.psm1`; the workflow YAML does not maintain a second
implementation.

Packages are not code-signed. If signing is added later, perform it after the
deterministic unsigned build and preserve the unsigned hash, signed-artifact
hash, and certificate information separately.

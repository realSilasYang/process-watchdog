# Release process

[简体中文](../release-process.md) | **English**

1. Prepare user-facing entries with the [changelog template](changelog-template.md)
   and create `docs/release-notes/v<version>.md`, then update `VERSION`,
   `CHANGELOG.md`, and `docs/CHANGELOG.en.md`. The build
   injects the executable file version from `VERSION`. Keep `📋` in the document
   title and use `## 🎉 Version [X.Y.Z] - YYYY-MM-DD` for release headings. Put
   migrations, defaults, privilege changes, and required actions under
   `⚠️ Important Notes`, and remove empty categories. Every formal release keeps
   `📦 Release Assets` and names all three files with their edition role, included
   content, AutoHotkey requirement, and intended use. This is always the final
   Release-notes section so readers can choose a download after reviewing changes.
2. Confirm the repository is not shallow and contains every branch and tag. Run
   `tests/verify.ps1`. It scans the complete history with pinned Gitleaks and
   rejects committed personal configuration, probes, credentials, or local paths
   in current release text.
3. Run `tests/run-gui-tests.ps1 -SoakSeconds 300`. Do not shorten the full
   pre-release UI soak.
4. Reconfirm that the commercial authorization for PingFang, SF Pro Text, and
   Apple SD Gothic Neo still covers the exact files in
   `assets/fonts/metadata.json`, Windows, the public repository, and Release
   distribution. Do not start a formal release without this confirmation.
5. Run `tests/reproducible-build.ps1` and preserve the final SHA-256 output. CI,
   dry runs, and formal releases build once with PowerShell 7 and once with
   Windows PowerShell 5.1. Do not release if the standalone EXE, EXE ZIP, source
   ZIP, or standalone SBOM differs between the two hosts, or if
   `SHA256SUMS.txt` does not match.
6. Ordinary CI uses the hash-pinned repository snapshot at
   `tools/ci-toolchain.resolved.json` and a cache, so upstream changes cannot
   destabilize unrelated commits. The dry run and formal release instead query
   the latest stable AutoHotkey and latest published Ahk2Exe, then freeze one
   `toolchain.resolved.json`. Confirm that the package contains the AutoHotkey
   license, corresponding source archive, resolved snapshot, and an SBOM
   consistent with the actual archive hashes.
7. Test affected Windows and DPI combinations in the manual GUI matrix. List
   incomplete physical combinations in the Release notes; automation does not
   replace them.
8. Verify both README languages and the matching compatibility, installation,
   and troubleshooting documents against actual behavior. Each changelog item
   describes observable behavior, not a commit title or internal class.
9. Commit all source, tests, and documents so Git can reconstruct `main`, and wait
   for CI to pass.
10. Manually run Release dry run from `main`. With read-only permissions, it resolves
    the latest upstream toolchain, executes the same full validation, GUI smoke,
    and two reproducible builds as a formal release, and preserves the full `dist`.
    It never creates a tag, draft, or Release. Do not proceed if it fails.
11. After the dry run passes, manually run Release from that same `main` commit.
    Do not push a version tag first. The workflow rejects tags or drafts from other
    commits and every already-published version. It may safely resume a same-commit
    draft or recover an orphaned same-commit tag; duplicates and inconsistent state
    fail explicitly.
12. The formal workflow resolves upstream tools and runs every gate again. It then
    attests and uploads only the standalone EXE, complete portable ZIP, and complete
    source ZIP to a draft. The SBOM, `SHA256SUMS.txt`, and remaining `dist` stay in
    the complete Actions artifact, with hidden directories explicitly included.
    The draft body, commit, allowlist, sizes, and
    GitHub SHA-256 digests must match the local build before publication, followed
    by a second audit of the public Release and remote tag.

The tag must be in `main` history and is created by the manually dispatched
Release workflow only after every gate passes. Code pushes, tag pushes, schedules,
and ordinary CI never publish. Never rewrite a published tag; release a patch
version for corrections.
Release text uses the corresponding `docs/release-notes/v<version>.md` and the
matching changelog entry as its source of truth, explaining each asset,
verification method, and uncompleted physical GUI check.
Each Release contains only three downloads: the standalone EXE, the complete
portable ZIP, and the complete source ZIP. The SBOM, `SHA256SUMS.txt`, and extracted
package directories remain available only in the complete Actions build artifact.
If the final post-publication audit fails, do not delete or overwrite the public
version. Preserve the evidence, diagnose the cause, and issue a new patch release.
Release-state resolution and both audits share the contract in
`tools/ReleaseEngineering.psm1`; the workflow YAML does not maintain a second
implementation.

Packages are not code-signed. If signing is added later, perform it after the
deterministic unsigned build and preserve the unsigned hash, signed-artifact
hash, and certificate information separately.

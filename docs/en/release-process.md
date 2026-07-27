# Release process

[简体中文](../release-process.md) | **English**

1. Prepare user-facing entries with the [changelog template](changelog-template.md)
   and create `docs/release-notes/v<version>.md`, then update `VERSION`,
   `CHANGELOG.md`, and `docs/CHANGELOG.en.md`. The build
   injects the executable file version from `VERSION`. A release heading is
   `## [X.Y.Z] - YYYY-MM-DD`. Put
   migrations, defaults, privilege changes, and required actions under Important
   notes, and remove empty categories.
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
5. Run `tests/reproducible-build.ps1` and preserve the final SHA-256 output. Do
   not release if the standalone EXE, EXE ZIP, source ZIP, or standalone SBOM
   differs between the two builds, or if
   `SHA256SUMS.txt` does not match.
6. Local preflight may reuse an existing resolved toolchain. The official release
   workflow queries the latest stable AutoHotkey release and latest published
   Ahk2Exe release again, then freezes one `toolchain.resolved.json`. Confirm the
   package contains the AutoHotkey license, corresponding complete source archive,
   resolved snapshot, and an SBOM consistent with the actual archive hashes.
7. Test affected Windows and DPI combinations in the manual GUI matrix. List
   incomplete physical combinations in the Release notes; automation does not
   replace them.
8. Verify both README languages and the matching compatibility, installation,
   and troubleshooting documents against actual behavior. Each changelog item
   describes observable behavior, not a commit title or internal class.
9. Commit all source, tests, and documents so Git can reconstruct `main`, and wait
   for CI to pass.
10. Manually run the Release workflow from `main` in GitHub Actions. Do not push a
   version tag first. The workflow validates `VERSION` and accepts manual dispatch
   only. A first run requires no remote tag; an interrupted draft at the same commit
   may be resumed by rerunning the workflow.
11. After dynamically resolving the upstream tools, the workflow reruns full
    verification, a short GUI soak, and two reproducible builds. Only then does it
    attest the standalone EXE, the complete portable ZIP, and the complete source
    ZIP. The SBOM and `SHA256SUMS.txt` remain verification attachments, and the
    complete `dist` tree is preserved as an Actions artifact.
    It uploads every asset to a draft, verifies the exact inventory, and only then
    makes the `v<version>` Release public in one final step.

The tag must be in `main` history and is created by the manually dispatched
Release workflow only after every gate passes. Code pushes, tag pushes, schedules,
and ordinary CI never publish. Never rewrite a published tag; release a patch
version for corrections.
Release text uses the corresponding `docs/release-notes/v<version>.md` and the
matching changelog entry as its source of truth, explaining each asset,
verification method, and uncompleted physical GUI check.
Each Release keeps exactly three user editions: the standalone EXE, the complete
portable ZIP, and the complete source ZIP. The SBOM, `SHA256SUMS.txt`, and extracted
package directories are verification or build attachments, not additional editions.

Packages are not code-signed. If signing is added later, perform it after the
deterministic unsigned build and preserve the unsigned hash, signed-artifact
hash, and certificate information separately.

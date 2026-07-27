# First public-release checklist

[简体中文](../publication-checklist.md) | **English**

This checklist distinguishes “the local repository is ready to be public” from
“the hosting platform is configured correctly.” The latter requires maintainer
actions on GitHub after repository creation and cannot be replaced by local tests.

## Before creating the repository

- `tests/verify.ps1` passes in a complete, non-shallow clone.
- `tests/run-gui-tests.ps1 -SoakSeconds 300` passes with zero GDI and USER growth.
- The release EXE hash matches the EXE used for the long GUI soak; otherwise rerun the soak.
- `tests/reproducible-build.ps1` produces identical standalone EXE, EXE ZIP,
  source ZIP, and SBOM hashes twice.
- `git log --all --name-only` contains no personal configuration, maintenance sessions, or probes.
- `watchdog.ini` and `watchdog.maintenance.ini` remain ignored and unchanged by hash.
- `VERSION` agrees with both changelogs, and the target version tag does not exist.
- The changelog consolidates related commits and clearly states migrations,
  defaults, privilege changes, and required user actions.
- Release notes identify physical Windows, DPI, multi-monitor, or high-contrast
  combinations that remain untested.

## GitHub repository settings

1. Create an empty repository without an auto-generated README, license, or
   `.gitignore`, avoiding an unrelated merge commit.
2. Push `main` and wait for all CI checks. Do not push the version tag manually;
   dispatch the Release workflow from Actions afterward.
3. Enable Issues under Settings → General; disable Discussions and Wiki if unused.
4. Under Settings → Code security, enable Dependabot alerts, Dependabot security
   updates, Secret scanning, Push protection, and Private Vulnerability Reporting.
5. Protect `main`: disallow force-push and deletion; require pull requests,
   resolved conversations, an up-to-date branch, and the CI `verify` check. With
   one maintainer, set approvals to zero; enable CODEOWNERS approval after a
   second maintainer exists.
6. Keep default minimal Actions permissions. The release workflow should request
   only its declared `contents`, `id-token`, and `attestations` permissions.
7. Confirm that Actions permits the third-party actions already pinned to full SHAs.
8. Add a concise description, Windows/AutoHotkey topics, and the actual license to About.

## First Release

- The Release workflow is manually dispatched from `main` only and creates the
  `v<VERSION>` tag after every gate passes.
- The resolved AutoHotkey must be the latest stable release and Ahk2Exe the latest
  published release. Tests, both builds, and the SBOM share one resolved snapshot.
- The release workflow reruns full-history scanning, core tests, real-GUI smoke,
  and two reproducible builds.
- The Release contains only the standalone EXE, Windows x64 ZIP, and source ZIP.
  The standalone SPDX SBOM, `SHA256SUMS.txt`, extracted directories, and other
  build outputs remain available only in the complete Actions artifact.
- The Release remains a draft during upload and becomes public only after its
  three assets match the explicit allowlist. An interrupted run may resume only
  the draft from the same commit and never overwrite a published release.
- After extraction, repeat the layout checks covered by
  `tools/verify-release.ps1` and confirm no personal configuration is present.
- Open the AutoHotkey license, corresponding source archive, resolved toolchain snapshot, and
  third-party licenses from the package.
- Reconfirm that the commercial authorization for PingFang, SF Pro Text, and
  Apple SD Gothic Neo remains valid and covers the exact file versions, Windows,
  the GitHub repository, and Release distribution used for this publication.
- From a clean directory, follow the README through install, add, exit, reload, and removal.

## After publication

- From a signed-out browser, inspect both READMEs, relative links, issue forms,
  private security reporting, and Release downloads.
- Preview all Chinese and English bug, feature, and improvement forms and verify
  fields, labels, support links, and the private-security route.
- Download the GitHub-hosted artifacts and compare their SHA-256 values with the build output.
- Confirm provenance shows the correct repository, workflow, commit, and tag.
- Record post-release findings. Any behavior or format change updates the
  changelog and migration instructions.

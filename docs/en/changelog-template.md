# 📝 English Changelog Template

[简体中文](../changelog-template.md) | **English**

For a release, copy the block below beneath Unreleased in
`docs/CHANGELOG.en.md`, then move released entries into it. Always keep Release
Assets; retain only the other categories that are actually present.

```markdown
## 🎉 Version [X.Y.Z] - YYYY-MM-DD

### 📦 Release Assets

- **`process-watchdog-X.Y.Z-windows-x64.exe` (standalone executable):** Requires no AutoHotkey installation and runs immediately after download; intended for a quick trial or users who need a single program file.
- **`process-watchdog-X.Y.Z-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, fonts, and runtime resources; intended for long-term use after full extraction or for manual deployment.
- **`process-watchdog-X.Y.Z-source.zip` (complete source package):** Includes the AHK source, modules, tests, documentation, and fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.

---

### ⚠️ Important Notes

- **Upgrade notice**: Keep this section only for migration, incompatibility,
  privilege, or required-action changes. Give exact steps and failure recovery.

---

### ✨ Added

- **Feature name**: Explain what was added, where it applies, and what users gain.

---

### 🚀 Improvements

- **Feature name**: Explain how existing behavior changed and what users can observe.

---

### 🐛 Fixed

- **Problem name**: Explain the previous failure and the correct behavior after the fix.

---

### 🔒 Security

- **Problem name**: Keep only after coordinated disclosure. State affected and
  fixed versions and whether immediate action is required, without exploitable details.
```

## 📐 Writing Rules

- Use `📋 Changelog` for the document title and
  `🎉 Version [X.Y.Z] - YYYY-MM-DD` for release headings. The version must match `VERSION`, the Ahk2Exe
  file version, and Git tag; build tooling uses this format for SBOM timestamps.
- Every formal version keeps `📦 Release Assets` and lists all three exact file
  names, edition roles, included content, AutoHotkey requirements, and intended
  use. Release validation rejects a generic “see attachments” entry.
- Standard categories are `✨ Added`, `🚀 Improvements`, and `🐛 Fixed`; remove
  empty categories. `⚠️ Important Notes` comes before them, and `🔒 Security`
  appears only after coordinated disclosure.
- Start each item with a bold feature or problem phrase, then explain the
  user-visible change, scope, and benefit in complete English.
- Combine commits for one feature. Do not list commit subjects, filenames,
  internal classes, variable names, or pure refactoring. Mention internal work
  only when it changes reliability, performance, compatibility, or maintenance boundaries.
- A change to configuration, defaults, privileges, system integration, update
  protection, or minimum environment explains old-data handling, backup needs,
  and failure recovery.
- For GUI, DPI, dark mode, and multi-monitor work, claim only the physically
  verified range. Mark untested combinations in Release notes and the manual matrix.
- After release, update comparison links: `[Unreleased]` points from the latest
  tag to `HEAD`, and the version link points to the GitHub Release.

## Pre-release example

```markdown
## 🚧 [Unreleased]

### 🚀 Improvements

- **Issue intake**: Bug reports now collect Windows, display scale, target type,
  and runtime context, reducing follow-up caused by missing environment details.

## 🎉 Version [1.0.1] - 2026-07-24

### 📦 Release Assets

- **`process-watchdog-1.0.1-windows-x64.exe` (standalone executable):** Requires no AutoHotkey installation and runs immediately after download; intended for a quick trial or users who need a single program file.
- **`process-watchdog-1.0.1-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, fonts, and runtime resources; intended for long-term use after full extraction or for manual deployment.
- **`process-watchdog-1.0.1-source.zip` (complete source package):** Includes the AHK source, modules, tests, documentation, and fonts for review, development, or source execution; requires AutoHotkey v2 x64 on the computer.

---

### 🐛 Fixed

- **Temporary preview state**: Removed UI injection left after icon and status
  acceptance testing, so test names no longer affect real configuration.
```

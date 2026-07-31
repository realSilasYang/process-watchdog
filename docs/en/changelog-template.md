# 📝 English Changelog Template

[简体中文](../changelog-template.md) | **English**

For a release, copy the block below beneath Unreleased in
`docs/CHANGELOG.en.md`, then move released entries into it. Always keep Release
Assets; retain only the other categories that are actually present. The template
does not generate Important Notes by default; add that section manually only for
breaking changes or mandatory upgrade actions.

```markdown
## 🎉 Version [X.Y.Z] - YYYY-MM-DD

### 📦 Release Assets

- **`fonts.zip` (optional font package):** Supplies preferred and fallback UI fonts for installation into Windows; it is not required to run the program.
- **`process-watchdog-X.Y.Z-source.zip` (complete source package):** Includes AHK source, modules, tests, and documentation but no fonts; intended for review, development, or source execution and requires AutoHotkey v2 x64.
- **`process-watchdog-X.Y.Z-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, and runtime resources but no fonts; requires no AutoHotkey installation and is intended for long-term use after full extraction.
- **Everything ([latest official release](https://www.voidtools.com/downloads/)):** Supplies the index and background service for application search. The bundled `Everything64.dll` is only an IPC client and cannot replace Everything itself.

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
  use. List them in GitHub's fixed display order: `fonts.zip`, source ZIP,
  portable ZIP, followed by Everything as an explicit Markdown link. Release
  validation rejects a generic “see attachments” entry.
- `⚠️ Important Notes` is an optional warning section and is omitted by default.
  Add it only when existing data or configuration is incompatible, data may be
  lost, minimum-environment or privilege changes are breaking, changed defaults
  create an upgrade risk, or users must migrate, back up, or replace files.
- Do not classify unchanged compatibility, direct-upgrade availability, portable
  package recommendations, edition selection, feature summaries, ordinary usage
  advice, or validation scope as Important Notes. When the section exists, every
  item states who is affected, the concrete risk, and the required action, and the
  section precedes standard categories. Remove the heading when no item qualifies.
- Standard categories are `✨ Added`, `🚀 Improvements`, and `🐛 Fixed`; remove
  empty categories. `🔒 Security` appears only after coordinated disclosure.
- Neither changelogs nor Release notes may contain a `✅ Validation Scope` section
  or enumerate test counts, soak iterations, build hashes, or incomplete manual
  matrices. Keep that evidence in dedicated validation records, CI/Release
  Actions logs, and complete build artifacts.
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

- **`fonts.zip` (optional font package):** Supplies preferred and fallback UI fonts for installation into Windows; it is not required to run the program.
- **`process-watchdog-1.0.1-source.zip` (complete source package):** Includes AHK source, modules, tests, and documentation but no fonts; intended for review, development, or source execution and requires AutoHotkey v2 x64.
- **`process-watchdog-1.0.1-windows-x64.zip` (complete portable package, recommended):** Includes the EXE, documentation, licenses, and runtime resources but no fonts; requires no AutoHotkey installation and is intended for long-term use after full extraction.
- **Everything ([latest official release](https://www.voidtools.com/downloads/)):** Supplies the index and background service for application search. The bundled `Everything64.dll` is only an IPC client and cannot replace Everything itself.

---

### 🐛 Fixed

- **Temporary preview state**: Removed UI injection left after icon and status
  acceptance testing, so test names no longer affect real configuration.
```

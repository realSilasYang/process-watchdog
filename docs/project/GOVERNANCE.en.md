# Project governance

[简体中文](GOVERNANCE.md) | **English**

## Maintainer

The current maintainer is [@realSilasYang](https://github.com/realSilasYang), who
is responsible for roadmap decisions, issue triage, review, releases, security
response, and enforcement of the code of conduct.

## Decisions

A change affecting visible behavior, configuration, monitoring correctness,
dependencies, or release process should first explain its objective,
alternatives, compatibility, and evidence in an issue or pull request. Ordinary
fixes are merged after maintainer review. Difficult-to-reverse or disputed
changes should retain a public discussion period and record the final reasoning.
Urgent security work may remain private until a fix is released, followed by a
publicly safe explanation.

## Merge standard

A change should at least satisfy:

- A clear problem and expected result without unrelated refactoring.
- Automated tests for new behavior and manual evidence for GUI or DPI behavior.
- A passing `tests/verify.ps1` without touching personal runtime configuration.
- Traceable, pinned dependencies with hashes, licenses, and SBOM relationships.
- Idempotent cleanup for timers, windows, message callbacks, workers, and native resources.
- Synchronized user documentation, localization, changelogs, and compatibility notes.

The maintainer may request that an oversized pull request be split, or reject a
proposal that cannot be validated, greatly increases maintenance cost, violates
data boundaries, or does not fit project scope.

## Versions and support

The project uses Semantic Versioning and maintains only the latest release.
Backporting a security fix is decided from impact and feasibility and is not a
long-term support promise. A release requires full-history leak scanning,
automated validation, GUI smoke, reproducible builds, package verification, and
an organized changelog in both languages.

## Maintainer changes

A new maintainer needs a sustained record of reliable contribution and current
maintainer approval. If the maintainer can no longer continue, release access,
unfinished work, and security reports should be handed to a trusted contributor
and recorded here. Without a qualified successor, the project may enter
read-only maintenance; release credentials must not be given to an unverified party.

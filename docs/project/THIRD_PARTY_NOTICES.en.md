# Third-party notices

[简体中文](THIRD_PARTY_NOTICES.md) | **English**

The release includes or references the components below. Exact runtime DLL
versions, sources, and SHA-256 values are recorded in
`third_party/dependencies.lock.json` and each `VERSION.txt`. Build tools and the
embedded runtime are resolved from upstream for each official release and recorded
in `build-metadata/toolchain.resolved.json`. Full applicable
license texts are included in the repository and release package.

| Component | Purpose | License |
| --- | --- | --- |
| AutoHotkey | Embedded x64 runtime and PCRE | GPL-2.0-only and BSD-3-Clause |
| resvg | In-memory SVG rasterization | MIT or Apache License 2.0 |
| Everything SDK DLL | Application-search interface | MIT |
| PingFang | Process-private preferred Simplified, Hong Kong, and Taiwan Chinese UI font | Commercial redistribution authorization |
| SF Pro Text | Process-private preferred Latin, Vietnamese, and Cyrillic UI font | Commercial redistribution authorization |
| Apple SD Gothic Neo | Process-private preferred Korean UI font | Commercial redistribution authorization |
| Harano Aji Gothic | Process-private preferred Japanese UI font | SIL Open Font License 1.1 |
| Noto Sans and Noto Sans CJK | Process-private UI fallback fonts | SIL Open Font License 1.1 |
| Lucide Icons 1.27.0 | SVG icons for buttons, main-list states, and the statistics bar | ISC; selected Feather-derived icons use MIT |

The selected Lucide version, provenance, and complete license text are stored
under `assets/ui-icons/lucide/`. The administrator badge is supplied by the
Windows Shell at runtime; the project does not copy or distribute that system
resource. The package contains the complete runtime license at
`licenses/AutoHotkey-LICENSE.txt` and a full source archive for the exact
embedded AutoHotkey commit under `licenses/sources/`. That archive also contains
the corresponding PCRE source and build files.
`build-metadata/toolchain.resolved.json` records binary and source URLs, commits,
archives, and executable hashes.

Ahk2Exe is a build tool and is not shipped; each manual release selects its latest
published release, which uses WTFPL.
actionlint and Gitleaks are validation-only tools and are not shipped; both use
the MIT license.

[`assets/fonts/metadata.json`](../../assets/fonts/metadata.json) records the
families, versions, sources, and SHA-256 values of packaged fonts. The complete
OFL text is in [`assets/fonts/OFL-1.1.txt`](../../assets/fonts/OFL-1.1.txt).
PingFang, SF Pro Text, and Apple SD Gothic Neo are packaged under the commercial
redistribution authorization confirmed by the project owner. The public boundary
is documented in the [commercial font license notice](../../assets/fonts/COMMERCIAL-LICENSE-NOTICE.en.md),
and the project open-source license does not cover those files. Harano Aji Gothic
and Noto remain under OFL 1.1.

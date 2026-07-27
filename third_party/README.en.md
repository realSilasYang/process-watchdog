# Third-party runtime libraries

[简体中文](README.md) | **English**

This directory contains only pinned binaries required at runtime, together with
their licenses, sources, and verification records. Runtime loading uses absolute
paths relative to `A_ScriptDir` and does not depend on the current directory or
system `PATH`.

- `resvg/`: in-memory SVG rasterization. A missing library, wrong architecture,
  missing export, or rendering failure falls back to the Windows Shell SVG
  thumbnail provider.
- `everything/`: the exclusive application-search interface. Everything64.dll
  connects to the user's running Everything service; there is no local full-disk
  scan fallback.

To upgrade a dependency, download it again from the official URL recorded in its
`VERSION.txt`, verify upstream version and SHA-256, update license and hash
records, and run the complete test suite. Never replace a DLL by name without
updating the version manifest.

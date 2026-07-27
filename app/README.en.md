# Application adapter layer

[简体中文](README.md) | **English**

`app` contains composition and GUI adapters specific to this application.
Window classes here may call application commands and presentation helpers from
the composition root. Reusable configuration, monitoring, platform, and UI
infrastructure that must not depend on root globals remains under `src`.

`app/UI` contains native rendering and interaction adapters for the main window.
`app/Windows` contains short-lived windows. Both may connect to the composition
root, but neither may create a second copy of application state.

This boundary deliberately separates:

- `src`: receives dependencies through constructors or callbacks and does not
  read `App`, `Main`, or `GuiModules`.
- `app`: connects concrete windows and commands to the composition root and may
  access application state, while lifecycle remains governed by `ManagedWindow`
  and `GuiModuleRegistry`.

Windows retain only their own layout, domain validation, and control references.
Infrastructure with the same purpose must use the shared entry points:

- `InitializeApplicationWindow` applies the title bar, application icon, client
  colors, and default font as one operation.
- Modern file and folder pickers share the theme, initial-path, cancellation,
  and Shell-resource boundary in `SelectPathWithModernDialog`.
- Registered buttons use `SetRegisteredButtonEnabled` to synchronize native
  enabled state, interaction state, and repainting.
- Configuration windows use `GuardMutationQueue.EnqueueExclusive` to reject a
  duplicate queued operation for the same owner.
- Main-list and Everything-search ImageList leases and deferred destruction are
  both counted by `IconResourceRegistry`.

Window-specific form capture, save transactions, search batches, log measurement,
and close cleanup are not merged merely because their code has a similar shape.
Code enters the shared layer only when purpose, ownership, and failure contracts
are all the same.

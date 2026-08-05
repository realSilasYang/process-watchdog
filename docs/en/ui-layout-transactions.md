# Reusable local layout transactions

This specification applies when several sibling child windows must move together
during interactive Win32/AHK v2 resizing. The implementation is
[`src/UI/AtomicControlLayout.ahk`](https://github.com/realSilasYang/process-watchdog/blob/main/src/UI/AtomicControlLayout.ahk); the main
command buttons and pseudo-header must use it for visible-window layout.

## Public API

```ahk
result := AtomicControlLayout.Apply(parentGui, [
    {Control: buttonA, X: 600, Y: 15, Width: 80, Height: 30},
    {Control: buttonB, X: 690, Y: 15, Width: 80, Height: 30}
], {
    ParentColor: "1E1E1E",
    ClearMargin: 2
})
```

Coordinates and dimensions are always 96-DPI logical units. `Apply` reads the
parent DPI once at the Win32 boundary and converts to physical pixels, preventing
repeated scaling within one layout pass. `ParentColor` is the solid client-area
background. `ClearMargin` is a logical safety margin for rounded anti-aliased edges.

`Status` has four values:

- `Unchanged`: every actual rectangle already equals its target; no move or paint is issued.
- `Applied`: layout completed. `Mode` is `Deferred` (atomic Win32 commit), `Direct`
  (hidden-parent initialization), or `Fallback` (protected ordinary move after an
  unavailable atomic commit).
- `Unavailable`: the parent or a child HWND is no longer valid; wait for the window
  to be rebuilt before laying it out.
- `Failed`: validation, movement, and fallback all failed. Do not assume the geometry
  is complete; retain the next retry opportunity.

## Invariants and ordering

1. **Separate geometry from painting.** Capture old rectangles, commit all geometry,
   then reconcile the surface. Never redraw between individual `.Move()` calls.
2. **Logical units at the boundary only.** `GuiControl.Move` accepts logical units;
   `DeferWindowPos`, `GetWindowRect`, `RedrawWindow`, and DC rectangles use physical pixels.
3. **Batch siblings.** Use one `BeginDeferWindowPos`, one `DeferWindowPos` per child,
   and one `EndDeferWindowPos`, with `SWP_NOREDRAW | SWP_NOCOPYBITS` and related
   non-activation flags to suppress intermediate surfaces.
4. **Never suspend the parent.** The parent must continue processing paint messages
   during interactive resize, so stable controls do not flash. Only the final affected
   region is synchronously refreshed.
5. **Guard only moving leaves.** `AtomicControlLayoutEraseGuard` intercepts
   `WM_ERASEBKGND` only for transaction children, with active counts for nested
   transactions. The parent and stable controls remain untouched.
6. **`RDW_NOERASE` is not cleanup.** It suppresses a pre-paint erase; it cannot remove
   pixels left in an old child position.
7. **Fill old positions explicitly.** After movement, fill the old bounds through
   `GetDCEx(..., DCX_CLIPCHILDREN)` so the fill cannot cover a new child surface.
8. **Refresh only the old/new union.** Invalidate and synchronously update the union with
   `RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN | RDW_NOERASE`; never refresh the
   entire client area for a local move.
9. **Release state and resources in pairs.** Subclass guards, HDCs, brushes, and buffers
   must be released in `finally` or an equivalent completion path, including exceptions.
10. **Reuse high-frequency callbacks.** Keep one callback pointer and attached-HWND map;
    do not create and destroy callbacks on every drag tick.
11. **Keep the unchanged fast path.** `Unchanged` must install no subclass, allocate no
    HDWP, and send no paint message.
12. **Make fallback explicit.** If HDWP creation or commit fails, move logically inside
    the same guard and return `Mode: "Fallback"`; never silently restore the old per-item
    redraw implementation.
13. **Use one rounded-edge margin.** Old-position fill and union invalidation use the same
    `ClearMargin`, otherwise square corners or one-pixel trails remain.
14. **Keep callers thin.** Callers compute business positions and colors, then provide
    complete `{Control, X, Y, Width, Height}` entries. They must not duplicate DPI,
    HDWP, subclass, or GDI code.
15. **Verify committed geometry.** Before returning `Applied`, reread every child
    HWND's physical rectangle and compare it with the target; a successful Win32
    return value does not prove that the window reached the target.
16. **Do not broaden the repair.** Do not use parent-wide `WM_SETREDRAW`,
    `WS_EX_COMPOSITED`, or whole-window `RedrawWindow` as a resize fix; those flash stable
    content.

## Verification checklist

- Alternate the window width at least 24 times and assert that the parent never receives
  a `WM_SETREDRAW` suspension.
- Assert that stable left controls receive no new `WM_PAINT`/`WM_ERASEBKGND`, moving-child
  erase messages are blocked, and active guard counts return to zero after every cycle.
- Read a pixel in the old button center and verify the parent background; read the restored
  pseudo-header edge and verify the toolbar color.
- Exercise `Unchanged`, `Applied/Deferred`, hidden-window `Applied/Direct`, and fallback results.
- At 96, 125, 150, and 200% DPI, compare logical targets to physical bounds with at most
  one rounding pixel of error.
- Track GDI/USER handles and callback count; a long drag must not grow either resource set.
- In addition to automation, continuously drag the real window on the desktop: no full-window
  flash, no stale trail, and no rounded-edge residue. DWM, drivers, and multi-monitor
  combinations require manual observation and cannot be replaced by one screenshot.

## Scope

The module handles sibling HWND geometry and local surface reconciliation. It does not
calculate list-column business widths, refresh fonts or themes, persist window size, or own
control lifetimes. Hidden initialization may use `Mode: "Direct"`; an invisible window should
not install a subclass or force synchronous painting merely to be "flicker free".

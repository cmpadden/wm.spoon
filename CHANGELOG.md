# Changelog

All notable changes to this project are documented here.

## Unreleased

- Performance and behavior improvements
  - Constrain window selection during `set_layout()` using `hs.window.filter` for current Space, with optional filters for current screen and visibility.
  - Add configuration flags: `current_space_only` (default true), `current_screen_only` (default false), `visible_only` (default true).
  - Add `log_level` configuration (error, warn, info, debug) and gate verbose logs behind it.
  - Cache per-app `AXEnhancedUserInterface` disablement to avoid repeated toggling.
  - Force zero-duration moves with `moveToUnit(..., 0)` to reduce stutter.
  - Minor refactors to reduce `pcall` usage on hot paths.
  - Add bulk apply mode: temporarily disable `hs.window.setFrameCorrectness` during layout apply (config `bulk_apply_disable_frame_correctness`, default true) to reduce per-window workaround “wiggle” during batch moves.
- Minor bug fixes, and improved guarding
    - Fix PIP geometries by computing right-edge X as `1 - padding - pip_width`.
    - Add guards when cycling focused window (nil, window type, empty layout).
    - Skip non-standard/non-maximizable windows and apply AX UI workaround in `set_layout()`.
    - Handle invalid or missing state in `load_state()` without clobbering state.
    - Bind layouts deterministically with `ipairs` and guard screen move hotkeys.

## 0.2.1

- Changelog inception.

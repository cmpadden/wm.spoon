# Changelog

All notable changes to this project are documented here.

## [0.2.3](https://github.com/cmpadden/wm.spoon/releases/tag/v0.2.3)

- Verified move behavior (replaces blind repeats)
  - Add ensured-move helper that verifies final frame and retries only when needed using `hs.timer.doAfter`.
  - Use ensured moves in focused-window cycling, bulk layout apply, and `windowCreated` subscription.
  - Maintain zero-duration moves for responsiveness; avoids layout “wiggle” while ensuring stubborn apps settle.
- Configuration
  - `ensure_move_verify` (default true): enable verification & conditional retry.
  - `ensure_move_retries` (default 2): max retries when window hasn’t reached target.
  - `ensure_move_delay_s` (default 0.05): delay between verification attempts.
  - `ensure_move_tolerance_px` (default 2): pixel tolerance when comparing frames.
- Bug fixes
  - Fix Lua scoping error by forward-declaring `disable_ax_enhanced_ui` so watchers can call ensured moves safely.
 - Packaging & structure
   - Rename and restructure to canonical Spoon bundle: `wm.spoon/` with implementation consolidated into `init.lua`.
   - Remove legacy `wm/` source layout and `spoon.lua`; entrypoint is now `wm.spoon/init.lua`.
   - Update release workflow to zip `wm.spoon/` so the artifact unpacks to a proper `.spoon` bundle.
 - Documentation
   - Update README usage to the concise pattern: `hs.loadSpoon("wm"); spoon.wm.config.layouts = {...}; spoon.wm:init()`.
 - Breaking changes
   - Direct `require` of the old module path is no longer supported; consumers should use `hs.loadSpoon("wm")` and access the object via `spoon.wm`.

## [0.2.2](https://github.com/cmpadden/wm.spoon/releases/tag/v0.2.2)

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

## [0.2.1](https://github.com/cmpadden/wm.spoon/releases/tag/v0.2.1)

- Changelog inception.

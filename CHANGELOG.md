# Changelog

All notable changes to this project are documented here.

## 0.2.2

- Minor bug fixes, and improved guarding
    - Fix PIP geometries by computing right-edge X as `1 - padding - pip_width`.
    - Add guards when cycling focused window (nil, window type, empty layout).
    - Skip non-standard/non-maximizable windows and apply AX UI workaround in `set_layout()`.
    - Handle invalid or missing state in `load_state()` without clobbering state.
    - Bind layouts deterministically with `ipairs` and guard screen move hotkeys.

## 0.2.1

- Changelog inception.

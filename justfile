set shell := ["bash", "-cu"]

_default:
    @just --list

# Check Lua formatting with Stylua (no writes)
lint:
    stylua --check --color always --config-path .stylua.toml wm.spoon tests

# Format Lua files with Stylua (writes changes)
format:
    stylua --color always --config-path .stylua.toml wm.spoon tests

# Requires a running Hammerspoon with its CLI and hs.ipc enabled.
test:
    hs -c 'assert(loadfile("{{justfile_directory()}}/tests/state.lua"))("{{justfile_directory()}}")'

set shell := ["bash", "-cu"]

_default:
    @just --list

# Check Lua formatting with Stylua (no writes)
lint:
    stylua --check --color always --config-path .stylua.toml wm

# Format Lua files with Stylua (writes changes)
format:
    stylua --color always --config-path .stylua.toml wm

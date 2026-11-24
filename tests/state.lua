-- Use Hammerspoon's JSON implementation, but fake all window and hotkey effects.
local root = ...
local hammerspoon = hs
local path = os.tmpname()

local function start(persist)
    local context = { applied = 0, alerts = 0, shutdowns = 0 }
    local previous_shutdown = function()
        context.shutdowns = context.shutdowns + 1
    end
    local fake_hs = {
        fs = hammerspoon.fs,
        json = hammerspoon.json,
        geometry = function(rect)
            return rect
        end,
        alert = function()
            context.alerts = context.alerts + 1
        end,
        hotkey = { bind = function() end },
        shutdownCallback = previous_shutdown,
        window = {
            allWindows = function()
                context.applied = context.applied + 1
                return {}
            end,
            filter = {
                new = function()
                    return { subscribe = function() end }
                end,
            },
        },
    }
    local env = setmetatable({ hs = fake_hs }, { __index = _G })
    local wm = assert(loadfile(root .. "/wm.spoon/init.lua", "t", env))()
    wm.config.layouts =
        { { wm.builtins.full }, { wm.builtins.padded_center }, { wm.builtins.skinny } }
    wm.config.state_file_path = path
    wm.config.auto_persist_state = persist
    wm.config.log_level = "error"
    wm:init()
    if not persist then
        assert(fake_hs.shutdownCallback == previous_shutdown, "opt-out must not install a callback")
    end
    return wm, fake_hs, context
end

local ok, err = pcall(function()
    assert(hs.json.write({ { Example_1 = 2 } }, path, true, true))
    local first, runtime, calls = start(true)
    assert(
        first.layout == 2 and calls.applied == 0,
        "legacy files use the default without moving windows"
    )
    assert(first.state[1].Example_1 == 2, "legacy cached slots are retained")
    local callback = runtime.shutdownCallback
    first:init()
    assert(runtime.shutdownCallback == callback, "init must not nest the shutdown hook")
    first:set_layout(3)
    first.state[5] = { Example_2 = 4 }
    runtime.shutdownCallback()
    assert(
        calls.shutdowns == 1 and calls.alerts == 0,
        "quiet save must preserve the existing callback"
    )

    local restored, _, startup = start(true)
    assert(restored.layout == 3 and startup.applied == 1, "startup must apply the saved layout")
    assert(restored.state[5].Example_2 == 4, "sparse layout keys must round-trip")
    local disabled, _, opted_out = start(false)
    assert(disabled.layout == 2 and opted_out.applied == 0, "opt-out uses the configured default")
    assert(
        disabled:load_state() and disabled.layout == 3 and opted_out.alerts == 1,
        "manual restore still works"
    )

    assert(hs.json.write({ active_layout = 99, ["1"] = { Example_1 = "2" } }, path, true, true))
    local missing, _, fallback = start(true)
    assert(
        missing.layout == 2 and fallback.applied == 0,
        "a removed layout must not replace the default"
    )
    assert(missing.state[1].Example_1 == 2, "object keys and slot values are normalized")
end)
os.remove(path)
assert(ok, err)
print("PASS: layout persistence, legacy compatibility, opt-out, and shutdown chaining")

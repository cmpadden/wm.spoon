--- Window Management
--
-- Tracking:
-- - [ ] Multi-monitor support
-- - [x] Differing geometries for multiple windows in the same application
-- - [x] Parameterize animation disable

local obj = {
    name = "wm.spoon",
    config = {
        default_layout = 2,
        state_file_path = os.getenv("HOME") .. "/.hammerspoon/_wm.spoon.state.json",
        animation_duration = 0,
        -- Selection constraints
        current_space_only = true,
        current_screen_only = false,
        visible_only = true,
        -- Logging level: "error", "warn", "info", "debug"
        log_level = "info",
        -- Bulk apply: temporarily disable frame correctness during layout apply
        bulk_apply_disable_frame_correctness = true,
        -- Verify-and-retry move (only when needed)
        ensure_move_verify = true,
        ensure_move_retries = 2,
        ensure_move_delay_s = 0.05,
        ensure_move_tolerance_px = 2,
        layouts = {},
        application_ignore_list = {},
        bindings = {
            prefix = { "cmd", "shift" },
            cycle_left = "h",
            cycle_right = "l",
            state_save = "-",
            state_restore = "=",
            state_alert = "/",
        },
    },
    -- Store the most layout index for each window in each layout
    state = {
        -- [1] = { "window_id_1" = 1, "window_id_2" = 1 }
        -- [2] = { "window_id_1" = 1, "window_id_2" = 3 }
    },
    -- Cache apps for which AXEnhancedUserInterface has been disabled
    ax_ui_disabled_apps = {},
}

local split_padding = 0.08
local padding = 0.02
local window_width_centered = 0.65
local window_width_skinny = 0.35
local pip_height = 0.35
local pip_width = 0.142

--- Predefined geometries
obj.builtins = {
    full = hs.geometry({
        h = 1,
        w = 1,
        x = 0,
        y = 0,
    }),

    padded_center = hs.geometry({
        h = (1 - (2 * padding)),
        w = window_width_centered,
        x = ((1 - window_width_centered) / 2),
        y = padding,
    }),

    padded_left = hs.geometry({
        h = (1 - (2 * padding)),
        w = (0.5 - (split_padding + 0.005)),
        x = split_padding,
        y = padding,
    }),

    padded_right = hs.geometry({
        h = (1 - (2 * padding)),
        w = (0.5 - split_padding - 0.005),
        x = (0.5 + 0.005),
        y = padding,
    }),

    full_left = hs.geometry({
        h = 1,
        w = 0.5,
        x = 0,
        y = 0,
    }),

    full_right = hs.geometry({
        h = 1,
        w = 0.5,
        x = 0.5,
        y = 0,
    }),

    skinny = hs.geometry({
        h = (1 - (2 * padding)),
        w = window_width_skinny,
        x = ((1 - window_width_skinny) / 2),
        y = padding,
    }),

    pip_bottom_right = hs.geometry({
        h = pip_height,
        w = pip_width,
        x = (1 - padding - pip_width),
        y = ((1 - pip_height) - padding),
    }),

    pip_top_right = hs.geometry({
        h = pip_height,
        w = pip_width,
        x = (1 - padding - pip_width),
        y = padding,
    }),
}

--- Retrieves configuration value with support for nested parameters.
local function get_config(...)
    local args = { ... }
    local value = nil
    for _, param in ipairs(args) do
        if value == nil then
            value = obj.config[param]
        else
            value = value[param]
        end
        if value == nil then
            error(string.format("Invalid parameter: %s", param))
        end
    end
    return value
end

local function ensure_layout_state(layout)
    if obj.state[layout] == nil then
        obj.state[layout] = {}
    end
    return obj.state[layout]
end

-- Simple logger with levels
local LOG_LEVELS = { error = 0, warn = 1, info = 2, debug = 3 }
local function log(level, fmt, ...)
    local cfg_level = LOG_LEVELS[(obj.config and obj.config.log_level) or "info"] or 2
    local msg_level = LOG_LEVELS[level] or 2
    if msg_level <= cfg_level then
        print(string.format(fmt, ...))
    end
end

local function get_window_geometry_index(layout, window_id)
    local layout_state = ensure_layout_state(layout)
    return layout_state[window_id] or 1
end

local function set_window_geometry_index(layout, window_id, index)
    local layout_state = ensure_layout_state(layout)
    layout_state[window_id] = index
end

-- Convert a unit rect to a screen-absolute rect for a given window's screen
local function unit_rect_to_rect_for_window(unit_rect, window)
    local screen = window and window:screen() or hs.screen.mainScreen()
    local screen_frame = screen:frame()
    return hs.geometry.rect(
        screen_frame.x + (unit_rect.x * screen_frame.w),
        screen_frame.y + (unit_rect.y * screen_frame.h),
        unit_rect.w * screen_frame.w,
        unit_rect.h * screen_frame.h
    )
end

-- Forward declare to allow use before definition
local disable_ax_enhanced_ui

-- Per-window in-progress guard to avoid overlapping ensure cycles
obj._ensure_in_progress = {}

-- Move a window to a unit rect, then verify and retry only if needed.
-- Retries are scheduled with a small delay and capped by config.
local function move_window_to_unit_ensured(window, unit_rect)
    if not window or not unit_rect then
        return
    end
    disable_ax_enhanced_ui(window)
    -- Initial attempt, zero-duration for speed
    pcall(function()
        window:moveToUnit(unit_rect, 0)
    end)

    if not obj.config.ensure_move_verify then
        return
    end

    local ok_id, wid = pcall(function()
        return window:id()
    end)
    local key = ok_id and tostring(wid) or tostring(window)
    if obj._ensure_in_progress[key] then
        return
    end
    obj._ensure_in_progress[key] = true

    local retries = obj.config.ensure_move_retries or 2
    local delay = obj.config.ensure_move_delay_s or 0.05
    local tol = obj.config.ensure_move_tolerance_px or 2

    local function close_enough(a, b)
        return math.abs(a - b) <= tol
    end

    local function verify_and_retry()
        -- Calculate desired rect against the window's current screen
        local desired = unit_rect_to_rect_for_window(unit_rect, window):floor()
        local current = window:frame():floor()

        if
            close_enough(current.x, desired.x)
            and close_enough(current.y, desired.y)
            and close_enough(current.w, desired.w)
            and close_enough(current.h, desired.h)
        then
            obj._ensure_in_progress[key] = nil
            return
        end

        if retries > 0 then
            retries = retries - 1
            pcall(function()
                window:moveToUnit(unit_rect, 0)
            end)
            hs.timer.doAfter(delay, verify_and_retry)
        else
            log(
                "debug",
                "Move verification exhausted for %s (current=%s desired=%s)",
                tostring(key),
                tostring(current),
                tostring(desired)
            )
            obj._ensure_in_progress[key] = nil
        end
    end

    hs.timer.doAfter(delay, verify_and_retry)
end

local function get_window_id(window)
    local app_name = "unknown"
    local window_id = 0

    local ok_app, app = pcall(function()
        return window:application()
    end)
    if ok_app and app then
        local ok_name, nm = pcall(function()
            return app:name()
        end)
        if ok_name and nm then
            app_name = nm
        end
    end

    local ok_id, wid = pcall(function()
        return window:id()
    end)
    if ok_id and wid then
        window_id = wid
    end

    return string.format("%s_%d", app_name, window_id)
end

--- Check if a window's application should be ignored by the window manager
-- @param window hs.window The window to check
-- @return boolean true if the window should be ignored, false otherwise
local function should_ignore_window(window)
    local ignore_list = obj.config.application_ignore_list or {}

    -- Empty ignore list means nothing is ignored
    if #ignore_list == 0 then
        return false
    end

    local success, app_name = pcall(function()
        return window:application():name()
    end)

    if not success or not app_name then
        return false
    end

    -- Exact name matching (case-sensitive)
    for _, ignored_app in ipairs(ignore_list) do
        if app_name == ignored_app then
            return true
        end
    end

    return false
end

local function cleanup_stale_window_state()
    local all_windows = hs.window.allWindows()
    local active_window_ids = {}

    for _, window in ipairs(all_windows) do
        if window:isStandard() and window:isMaximizable() then
            active_window_ids[get_window_id(window)] = true
        end
    end

    for _, layout_state in pairs(obj.state) do
        for window_id, _ in pairs(layout_state) do
            if not active_window_ids[window_id] then
                layout_state[window_id] = nil
            end
        end
    end
end

disable_ax_enhanced_ui = function(window)
    -- Disabling `AXEnhancedUserInterface` fixes the issue where some apps require retries to resize.
    -- Cache the action per app to avoid repeating it on every move.
    -- See: https://github.com/Hammerspoon/hammerspoon/issues/3224#issuecomment-2155567633
    -- See: https://github.com/Hammerspoon/hammerspoon/issues/3624
    local app
    local ok_app, res_app = pcall(function()
        return window and window:application()
    end)
    if ok_app then
        app = res_app
    end
    if not app then
        return
    end

    local bundleID
    local ok_bid, bid = pcall(function()
        return app:bundleID()
    end)
    if ok_bid and bid then
        bundleID = bid
    else
        local ok_name, nm = pcall(function()
            return app:name()
        end)
        bundleID = ok_name and nm or "unknown"
    end

    if obj.ax_ui_disabled_apps[bundleID] then
        return
    end

    local ok_ax, axApp = pcall(function()
        return hs.axuielement.applicationElement(app)
    end)
    if ok_ax and axApp and axApp.AXEnhancedUserInterface then
        axApp.AXEnhancedUserInterface = false
        obj.ax_ui_disabled_apps[bundleID] = true
        log("debug", "AXEnhancedUserInterface disabled for app %s", tostring(bundleID))
    else
        -- Even if property absent or failure, avoid retrying aggressively
        obj.ax_ui_disabled_apps[bundleID] = true
    end
end

--- Traverse `table` by `step` wrapping around to the beginning and end of the table.
--
-- If Lua arrays had a 0-based index, then this would be simple using the modulus operator,
-- however, instead we have to do this hacky workaround. See another user with the same
-- bewilderment: https://devforum.roblox.com/t/wrapping-index-in-an-array/1476197/2
--
-- @param table table table to traverse
-- @param index integer current index of table
-- @param step integer positive or negative value to iterate over table
--
local function next_index_circular(table, index, step)
    if #table == 1 then
        return 1
    end
    if step > 0 and index + step > #table then
        return index + step - #table
    elseif step < 0 and index + step <= 0 then
        return #table + index + step
    else
        return index + step
    end
end

function obj:move_focused_window_next_geometry(direction)
    local focused_window = hs.window.focusedWindow()
    if not focused_window then
        return
    end
    -- Skip if application is in ignore list (silent behavior)
    if should_ignore_window(focused_window) then
        return
    end
    -- Only manage standard, maximizable windows
    if not (focused_window:isStandard() and focused_window:isMaximizable()) then
        return
    end

    local focused_window_id = get_window_id(focused_window)

    local _active_layout = self.layouts[self.layout]
    if not _active_layout or #_active_layout == 0 then
        return
    end

    local current_index = get_window_geometry_index(self.layout, focused_window_id)
    local next_index = next_index_circular(_active_layout, current_index, direction)
    set_window_geometry_index(self.layout, focused_window_id, next_index)

    local target_geometry = _active_layout[next_index]
    -- Verified move (retries only when needed)
    move_window_to_unit_ensured(focused_window, target_geometry)
end

-- Select candidate windows according to configured constraints
local function get_candidate_windows()
    local cfg = obj.config or {}
    local windows = nil

    if cfg.current_space_only then
        -- Prefer defaultCurrentSpace if available
        local ok, wf = pcall(function()
            return hs.window.filter.defaultCurrentSpace
        end)
        if ok and wf then
            windows = wf:getWindows()
        end
    end

    if windows == nil then
        -- Fallback to all windows
        windows = hs.window.allWindows()
    end

    -- Optionally constrain to current screen
    if cfg.current_screen_only then
        local target_screen = nil
        local fw = hs.window.focusedWindow()
        if fw then
            target_screen = fw:screen()
        end
        if not target_screen then
            target_screen = hs.screen.mainScreen()
        end
        local filtered = {}
        for _, w in ipairs(windows) do
            local ok_scr, scr = pcall(function()
                return w:screen()
            end)
            if ok_scr and scr == target_screen then
                table.insert(filtered, w)
            end
        end
        windows = filtered
    end

    -- Optionally filter for visibility/unminimized
    if cfg.visible_only then
        local filtered = {}
        for _, w in ipairs(windows) do
            local is_min = false
            local ok_min, res_min = pcall(function()
                return w:isMinimized()
            end)
            if ok_min then
                is_min = res_min
            end
            local is_vis = true
            local ok_vis, res_vis = pcall(function()
                return w:isVisible()
            end)
            if ok_vis then
                is_vis = res_vis
            end
            if not is_min and is_vis then
                table.insert(filtered, w)
            end
        end
        windows = filtered
    end

    return windows or {}
end

function obj:set_layout(layout)
    log("info", "=== Setting Layout %d ===", layout)
    self.layout = layout
    local active_layout = self.layouts[layout]

    if not active_layout then
        log("error", "Layout %d not found in layouts table", layout)
        return
    end

    log("debug", "Layout %d has %d geometry positions", layout, #active_layout)

    -- Constrain the window set per configured filters
    local all_windows = get_candidate_windows()

    log("info", "Found %d candidate windows to move", #all_windows)

    -- Bulk apply: optionally disable frame correctness to avoid extra wiggle steps during batch
    local original_correctness = hs.window.setFrameCorrectness
    if self.config.bulk_apply_disable_frame_correctness then
        hs.window.setFrameCorrectness = false
        log("debug", "Temporarily disabled setFrameCorrectness for bulk apply")
    end

    local ok, moved_count = pcall(function()
        local moved = 0
        for i, window in ipairs(all_windows) do
            if window and type(window) == "userdata" then
                -- Try to get app name for logging, but don't filter based on it
                local app_success, app_name = pcall(function()
                    return window:application():name()
                end)
                local display_name = app_success and app_name or "unknown"

                -- Check if window should be ignored or is not manageable
                if should_ignore_window(window) then
                    log("debug", "  ⊘ Ignoring %s (in ignore list)", display_name)
                elseif not (window:isStandard() and window:isMaximizable()) then
                    log(
                        "debug",
                        "  ⊘ Skipping %s (non-standard or non-maximizable)",
                        display_name
                    )
                else
                    log("debug", "Window %d: %s - attempting to move", i, display_name)

                    -- Try to move the window regardless of validation
                    local window_id = get_window_id(window)
                    local ix = get_window_geometry_index(layout, window_id)

                    if ix > #active_layout then
                        ix = 1
                        set_window_geometry_index(layout, window_id, ix)
                    end

                    local target_geometry = active_layout[ix]
                    if target_geometry then
                        move_window_to_unit_ensured(window, target_geometry)
                        moved = moved + 1
                    end
                end
            end
        end
        return moved
    end)

    -- Restore frame correctness regardless of loop outcome
    if self.config.bulk_apply_disable_frame_correctness then
        hs.window.setFrameCorrectness = original_correctness
        log("debug", "Restored setFrameCorrectness after bulk apply")
    end

    if ok then
        log("info", "=== Layout Setting Complete - Moved %d windows ===", moved_count)
    else
        log("warn", "Layout apply encountered an error: %s", tostring(moved_count))
    end
end

function obj:save_state()
    cleanup_stale_window_state()
    local path = get_config("state_file_path")
    hs.json.write(self.state, path, true, true)
    hs.alert(string.format("wm.spoon state written to file: %s", path))
end

function obj:load_state()
    local path = get_config("state_file_path")
    local s = hs.json.read(path)
    if type(s) == "table" then
        obj.state = s
        hs.alert(string.format("wm.spoon state loaded from file: %s", path))
    else
        hs.alert(string.format("wm.spoon no valid state to load at: %s", path))
    end
end

function obj:debug_window_filter()
    print("=== Window Filter Debug ===")
    print(string.format("Filter object: %s", tostring(self.window_filter_all)))

    local filter_windows = self.window_filter_all:getWindows()
    local all_windows = hs.window.allWindows()

    print(string.format("Filter returned: %d windows", filter_windows and #filter_windows or 0))
    print(string.format("hs.window.allWindows returned: %d windows", #all_windows))

    print("All windows from hs.window.allWindows():")
    for i, window in ipairs(all_windows) do
        if window and type(window) == "userdata" then
            local success, is_valid = pcall(function()
                return window:isValid()
            end)
            if success and is_valid then
                local app_success, app_name = pcall(function()
                    return window:application():name()
                end)
                local is_standard_success, is_standard = pcall(function()
                    return window:isStandard()
                end)
                local is_max_success, is_maximizable = pcall(function()
                    return window:isMaximizable()
                end)

                print(
                    string.format(
                        "  %d: %s - standard:%s, maximizable:%s",
                        i,
                        app_success and app_name or "unknown",
                        is_standard_success and tostring(is_standard) or "error",
                        is_max_success and tostring(is_maximizable) or "error"
                    )
                )
            else
                print(string.format("  %d: INVALID WINDOW", i))
            end
        else
            print(string.format("  %d: NIL or non-userdata", i))
        end
    end
    print("=== Debug Complete ===")
end

function obj:init()
    hs.window.animationDuration = get_config("animation_duration")
    hs.window.setFrameCorrectness = true

    self.layout = get_config("default_layout")
    self.layouts = get_config("layouts")

    -- Automatic layout application to new/focused windows.
    self.window_filter_all = hs.window.filter.new()
    log("debug", "Window filter initialized: %s", tostring(self.window_filter_all))

    -- Consider usage of `windowCreated` and `windowFocused` for ideal resizing trigger
    -- TODO refactor this so that movement and getting layout is shared
    self.window_filter_all:subscribe(hs.window.filter.windowCreated, function(window, app_name)
        -- Skip if application is in ignore list
        if should_ignore_window(window) then
            print(string.format("⊘ Ignoring new window from %s (in ignore list)", app_name))
            return
        end
        -- Prevent resizing of floating windows
        --
        -- http://www.hammerspoon.org/docs/hs.window.html#isStandard
        --
        --  > "Standard window" means that this is not an unusual popup window, a modal dialog, a floating window, etc.
        --
        if window:isStandard() and window:isMaximizable() then
            hs.alert("Initializing " .. app_name)
            local window_id = get_window_id(window)
            local ix = get_window_geometry_index(self.layout, window_id)
            local target_geometry = self.layouts[self.layout][ix]
            move_window_to_unit_ensured(window, target_geometry)
        end
    end)

    -- Clean up state when windows are closed
    self.window_filter_all:subscribe(hs.window.filter.windowDestroyed, function(window, app_name)
        local window_id = get_window_id(window)
        for _, layout_state in pairs(obj.state) do
            layout_state[window_id] = nil
        end
    end)

    -- bind layouts to corresponding 1, 2, ..., n in order
    for i, _ in ipairs(self.layouts) do
        hs.hotkey.bind({ "cmd", "ctrl" }, tostring(i), function()
            obj:set_layout(i)
        end)
    end

    --- Display cached state window geometries for active layout
    local function hs_alert_window_state()
        if obj.state[self.layout] == nil then
            hs.alert(string.format("No state for layout: %s", self.layout))
            return
        end
        local lines = {}
        lines[#lines + 1] = string.format("Active Layout: %s", self.layout)
        lines[#lines + 1] = string.rep("-", 80)
        for window_id, geometry_index in pairs(obj.state[self.layout]) do
            lines[#lines + 1] = string.format("%-40s %40s", window_id, geometry_index)
        end
        hs.alert(table.concat(lines, "\n"))
    end

    local _prefix = get_config("bindings", "prefix")

    hs.hotkey.bind(_prefix, get_config("bindings", "cycle_right"), function()
        self:move_focused_window_next_geometry(1)
    end)
    hs.hotkey.bind(_prefix, get_config("bindings", "cycle_left"), function()
        self:move_focused_window_next_geometry(-1)
    end)
    hs.hotkey.bind(_prefix, get_config("bindings", "state_alert"), function()
        hs_alert_window_state()
    end)
    hs.hotkey.bind(_prefix, get_config("bindings", "state_save"), function()
        self:save_state()
    end)
    hs.hotkey.bind(_prefix, get_config("bindings", "state_restore"), function()
        self:load_state()
    end)

    local function moveToScreen(index)
        local win = hs.window.focusedWindow()
        if not win then
            return
        end
        local screens = hs.screen.allScreens()
        if not screens or not screens[index] then
            return
        end
        win:moveToScreen(screens[index])
    end

    -- todo - move to next / previous screen
    hs.hotkey.bind({ "cmd", "ctrl" }, "h", function()
        moveToScreen(1)
    end)

    hs.hotkey.bind({ "cmd", "ctrl" }, "l", function()
        moveToScreen(2)
    end)
end

return obj

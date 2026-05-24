PaperWM = hs.loadSpoon("PaperWM")

PaperWM.external_bar = {top = 37}
PaperWM.window_gap  =  { top = 4, bottom = 4, left = 8, right = 8 }

PaperWM.allow_non_maximizable_window = function(window)
	local app = window:application()
	return app and app:bundleID() == "net.imput.helium"
end

PaperWM:bindHotkeys({
	-- Move Focus (Alt + h/j/k/l)
	focus_left = { { "alt" }, "h" },
	focus_down = { { "alt" }, "j" },
	focus_up = { { "alt" }, "k" },
	focus_right = { { "alt" }, "l" },

	-- Move Windows (Alt + Shift + h/j/k/l)
	swap_left = { { "alt", "shift" }, "h" },
	swap_down = { { "alt", "shift" }, "j" },
	swap_up = { { "alt", "shift" }, "k" },
	swap_right = { { "alt", "shift" }, "l" },

	-- Slurp & Barf (Alt + Shift + t/g)
	slurp_in = { { "alt", "shift" }, "t" },
	barf_out = { { "alt", "shift" }, "g" },

	-- Layout Controls
	toggle_floating = { { "alt", "ctrl" }, "f" },
	full_width = { { "alt" }, "f" },
	-- center_window = { { "alt" }, "c" },

	-- Workspaces handled manually below with fast-workspace-switch

	-- Move Window to Workspace (Alt + Shift + 1-6)
	move_window_1 = { { "alt", "shift" }, "1" },
	move_window_2 = { { "alt", "shift" }, "2" },
	move_window_3 = { { "alt", "shift" }, "3" },
	move_window_4 = { { "alt", "shift" }, "4" },
	move_window_5 = { { "alt", "shift" }, "5" },
	move_window_6 = { { "alt", "shift" }, "6" },
})

local function launch(app)
	return function()
		hs.application.launchOrFocus(app)
	end
end

hs.hotkey.bind({ "alt" }, "w", launch("Helium"))
hs.hotkey.bind({ "alt" }, "o", launch("Obsidian"))
hs.hotkey.bind({ "alt" }, "g", launch("Ghostty"))
hs.hotkey.bind({ "alt" }, "y", launch("Finder"))
hs.hotkey.bind({ "alt" }, "c", launch("FreeCAD"))
hs.hotkey.bind({ "alt" }, "z", launch("Zed"))

-- ============================================
-- WINDOW RESIZING
-- ============================================

local function windowResize(offsetWidth, offsetHeight)
	local window = hs.window.focusedWindow()
	if not window then
		return
	end

	local window_frame = window:frame()
	local screen_frame = window:screen():frame()

	window_frame.w = window_frame.w + offsetWidth
	window_frame.w = math.max(100, math.min(window_frame.w, screen_frame.w - window_frame.x))

	window_frame.h = window_frame.h + offsetHeight
	window_frame.h = math.max(100, math.min(window_frame.h, screen_frame.h - window_frame.y))

	window:setFrame(window_frame)
end

hs.hotkey.bind({ "alt", "shift" }, "-", function()
	windowResize(-50, 0)
end)
hs.hotkey.bind({ "alt", "shift" }, "=", function()
	windowResize(50, 0)
end)

-- ============================================
-- FAST WORKSPACE SWITCHING
-- ============================================

local fastWorkspaceSwitchPath = os.getenv("HOME") .. "/.config/paperwm/fast-workspace-switch"

local function changeSpaceBy(offset)
	local direction = offset > 0 and "right" or "left"
	local count = math.abs(offset)
	os.execute(fastWorkspaceSwitchPath .. " " .. direction .. " " .. count)
end

local function currentSpaceIndex()
	local current_space = hs.spaces.activeSpaceOnScreen()
	local spaces = hs.spaces.allSpaces()[hs.screen.mainScreen():getUUID()]

	local current_index = nil
	for space_index, space in ipairs(spaces) do
		if space == current_space then
			current_index = space_index
			break
		end
	end

	return current_index
end

local function gotoSpace(index)
	local current_index = currentSpaceIndex()
	if not current_index then
		return
	end
	local change_by = index - current_index
	if change_by ~= 0 then
		changeSpaceBy(change_by)
	end
end

-- ============================================
-- SPACE SWITCHING HOTKEYS (using fast-workspace-switch)
-- ============================================

for index = 1, 9 do
	hs.hotkey.bind({ "alt" }, tostring(index), function()
		gotoSpace(index)
	end)
end

-- ============================================
-- 3-FINGER SWIPE
-- ============================================

-- local current_id, threshold
-- Swipe = hs.loadSpoon("Swipe")
-- Swipe:start(4, function(direction, distance, id)
-- 	if id == current_id then
-- 		if distance > threshold then
-- 			threshold = math.huge -- only trigger once per swipe
--
-- 			-- use "natural" scrolling
-- 			if direction == "right" then
-- 				hs.window.focusedWindow():focusWindowEast()
-- 			elseif direction == "left" then
-- 				hs.window.focusedWindow():focusWindowWest()
-- 			elseif direction == "down" then
-- 				hs.window.focusedWindow():focusWindowSouth()
-- 			elseif direction == "up" then
-- 				hs.window.focusedWindow():focusWindowNorth()
-- 			end
-- 		end
-- 	else
-- 		current_id = id
-- 		threshold = 0.2 -- swipe distance > 20% of trackpad
-- 	end
-- end)

-- ============================================
-- NO ANIMATIONS
-- ============================================

hs.window.animationDuration = 0

PaperWM.window_filter = PaperWM.window_filter:rejectApp("Antinote")

do
	local addWindow = PaperWM.windows.addWindow
	PaperWM.windows.addWindow = function(window)
		local spaces = hs.spaces.windowSpaces(window)
		if not spaces or not spaces[1] then
			local app = window:application()
			local app_name = app and app:name() or "unknown app"
			PaperWM.logger.w(string.format("ignoring window without Space: %s - %s", app_name, window:title()))
			return
		end
		return addWindow(window)
	end
end

PaperWM:start()

-- ============================================
-- OPTIMIZED SKETCHYBAR INTEGRATION
-- ============================================

local Spaces = hs.spaces
local sketchybar_bin = "/opt/homebrew/bin/sketchybar"
local MAX_ITEMS = 12

-- Colors
local FOCUSED_COLOR = "0xffffffff"
local UNFOCUSED_COLOR = "0x60ffffff"

-- State tracking
local icon_cache = {}
local previous_state = {
	windows = {},
	focused = nil,
	space = nil,
}

-- Build icon cache by reading icon_map.sh once
local function build_icon_cache()
	local icon_map_path = os.getenv("HOME") .. "/.config/sketchybar/plugins/icon_map.sh"
	local file = io.open(icon_map_path, "r")
	if not file then
		return
	end

	for line in file:lines() do
		-- Match pattern: "App Name") or "App Name" | "Other Name")
		local apps = line:match('^%s*"([^"]+)"[^)]*%)')
		if apps then
			local icon = line:match('icon_result="([^"]+)"')
			if icon then
				-- Handle multiple app names on same line
				for app in apps:gmatch('([^"|]+)') do
					app = app:gsub("^%s*", ""):gsub("%s*$", "")
					if app ~= "" then
						icon_cache[app] = icon
					end
				end
			end
		end
	end
	file:close()
end

build_icon_cache()

-- Get icon for app (cached lookup)
local function get_icon(app_name)
	if not app_name then
		return ":default:"
	end

	-- Direct cache hit
	if icon_cache[app_name] then
		return icon_cache[app_name]
	end

	-- Try fallback to icon_map.sh for unknown apps
	local handle = io.popen(
		'"' .. os.getenv("HOME") .. '/.config/sketchybar/plugins/icon_map.sh" "' .. app_name .. '" 2>/dev/null'
	)
	if handle then
		local icon = handle:read("*l")
		handle:close()
		if icon and icon ~= ":default:" then
			icon_cache[app_name] = icon
			return icon
		end
	end

	return ":default:"
end

-- Escape string for shell
local function shell_escape(str)
	return (str or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("'", "\\'")
end

-- Get current window state from PaperWM
local function get_window_state()
	local currentSpace = Spaces.activeSpaceOnScreen()
	if not currentSpace then
		return nil
	end

	local windowList = PaperWM.state.windowList(currentSpace)
	if not windowList then
		return { windows = {}, focused = nil, space = currentSpace }
	end

	local xPositions = PaperWM.state.xPositions(currentSpace)
	local windows = {}

	-- Get focused window info
	local focusedWin = hs.window.focusedWindow()
	local focusedId = focusedWin and focusedWin:id()
	local focusedApp = focusedWin and focusedWin:application() and focusedWin:application():name() or ""

	-- Collect all windows with their positions
	local col_idx = 1
	for _, column in ipairs(windowList) do
		for _, window in ipairs(column) do
			local app = window:application()
			local appName = app and app:name() or "Unknown"
			local windowId = window:id()
			local x = xPositions[windowId] or (col_idx * 1000)
			local icon = get_icon(appName)
			local isFocused = (windowId == focusedId)

			table.insert(windows, {
				id = windowId,
				name = appName,
				x = x,
				icon = icon,
				focused = isFocused,
			})
		end
		col_idx = col_idx + 1
	end

	-- Sort by x position (left to right)
	table.sort(windows, function(a, b)
		return a.x < b.x
	end)

	return {
		windows = windows,
		focused = focusedApp,
		space = currentSpace,
	}
end

-- Build sketchybar command based on state diff
local function build_update_command(current)
	local cmds = {}
	local prev_windows = previous_state.windows
	local curr_windows = current.windows

	-- Build ID signature for order detection
	local function build_signature(windows)
		local ids = {}
		for i, win in ipairs(windows) do
			ids[i] = win.id
		end
		return table.concat(ids, ",")
	end

	local prev_signature = build_signature(prev_windows)
	local curr_signature = build_signature(curr_windows)
	local order_changed = prev_signature ~= curr_signature
	local focus_changed = previous_state.focused ~= current.focused

	-- Update visible windows
	for i = 1, math.min(#curr_windows, MAX_ITEMS) do
		local win = curr_windows[i]
		local prev = prev_windows[i]
		local item_name = "paperwm_" .. (i - 1)

		-- Determine what changed
		local slot_changed = not prev or prev.id ~= win.id
		local icon_changed = not prev or prev.icon ~= win.icon
		local win_focus_changed = not prev or prev.focused ~= win.focused

		-- Update icon/text if window or icon changed
		if slot_changed or icon_changed then
			if win.icon == ":default:" then
				-- Use text label for unknown apps
				local capitals = win.name:gsub("[^A-Z]", "")
				local label
				if #capitals == 2 then
					label = capitals
				else
					label = win.name:sub(1, 2)
				end
				table.insert(
					cmds,
					string.format(
						'--set %s icon.drawing=off label.drawing=on label="%s" label.font="Lilex:Bold:14.0"',
						item_name,
						shell_escape(label)
					)
				)
			else
				-- Use icon
				table.insert(
					cmds,
					string.format('--set %s label.drawing=off icon.drawing=on icon="%s"', item_name, win.icon)
				)
			end
		end

		-- Update color if focus or slot changed
		if win_focus_changed or slot_changed or focus_changed then
			local color = win.focused and FOCUSED_COLOR or UNFOCUSED_COLOR
			if win.icon == ":default:" then
				table.insert(cmds, string.format("--set %s label.color=%s", item_name, color))
			else
				table.insert(cmds, string.format("--set %s icon.color=%s", item_name, color))
			end
		end

		-- Ensure item is visible
		if slot_changed or order_changed then
			table.insert(cmds, string.format("--set %s drawing=on", item_name))
		end
	end

	-- Hide unused items
	for i = #curr_windows + 1, MAX_ITEMS do
		local prev = prev_windows[i]
		if prev and prev.id then
			table.insert(cmds, string.format("--set paperwm_%d drawing=off", i - 1))
		end
	end

	return table.concat(cmds, " ")
end

-- Execute sketchybar update
local function update_sketchybar()
	local current = get_window_state()
	if not current then
		return
	end

	-- Build command
	local cmd = build_update_command(current)

	-- Execute if there are changes
	if cmd ~= "" then
		hs.execute(sketchybar_bin .. " " .. cmd)
	end

	-- Update previous state
	previous_state = current
end

-- ============================================
-- EVENT HANDLING (Hook into PaperWM)
-- ============================================

-- Debounce timer for expensive updates
local update_timer = nil
local FOCUS_DEBOUNCE_MS = 0 -- Immediate for focus
local LAYOUT_DEBOUNCE_MS = 50 -- 50ms for layout changes (PaperWM tiling time)

local function debounced_update(delay_ms)
	if update_timer then
		update_timer:stop()
	end

	delay_ms = delay_ms or LAYOUT_DEBOUNCE_MS

	if delay_ms == 0 then
		update_sketchybar()
	else
		update_timer = hs.timer.doAfter(delay_ms / 1000, update_sketchybar)
	end
end

-- Hook into PaperWM's internal event handler
local originalHandler = PaperWM.events.windowEventHandler
PaperWM.events.windowEventHandler = function(window, event, self)
	-- Call original handler first
	originalHandler(window, event, self)

	-- Handle different event types with appropriate debouncing
	if event == "windowFocused" then
		debounced_update(FOCUS_DEBOUNCE_MS)
	elseif event == "windowVisible" or event == "windowNotVisible" then
		-- Window added/removed: debounced
		debounced_update(LAYOUT_DEBOUNCE_MS)
	elseif event == "AXWindowMoved" or event == "AXWindowResized" then
		-- Window moved/resized: debounced (PaperWM tiling triggers these)
		debounced_update(LAYOUT_DEBOUNCE_MS)
	elseif event == "windowFullscreened" or event == "windowUnfullscreened" then
		-- Fullscreen changes: debounced
		debounced_update(LAYOUT_DEBOUNCE_MS)
	end
end

-- Space/workspace changes
local space_timer = nil
hs.spaces.watcher
	.new(function()
		-- Reset state on space change to force full refresh
		previous_state = { windows = {}, focused = nil, space = nil }

		if space_timer then
			space_timer:stop()
		end
		space_timer = hs.timer.doAfter(0.1, update_sketchybar)
	end)
	:start()

-- Wrap space switch hotkeys for immediate update
local originalSwitchSpace = PaperWM.switch_space
if originalSwitchSpace then
	PaperWM.switch_space = function(self, space)
		originalSwitchSpace(self, space)
		-- Reset state and update immediately
		previous_state = { windows = {}, focused = nil, space = nil }
		debounced_update(50)
	end
end

-- Wrap tileSpace to catch all layout changes (swaps, slurp, barf, etc)
-- tileSpace is called after any window arrangement operation
local originalTileSpace = PaperWM.tileSpace
if originalTileSpace then
	PaperWM.tileSpace = function(self, space)
		originalTileSpace(self, space)
		-- Update sketchybar after tiling completes
		debounced_update(100)
	end
end

-- Application activation (for apps that don't trigger window events)
local app_timer = nil
hs.application.watcher
	.new(function(appName, eventType, appObject)
		if eventType == hs.application.watcher.activated then
			if app_timer then
				app_timer:stop()
			end
			app_timer = hs.timer.doAfter(0.1, function()
				debounced_update(FOCUS_DEBOUNCE_MS)
			end)
		end
	end)
	:start()

-- Initial update after startup
hs.timer.doAfter(1, function()
	previous_state = { windows = {}, focused = nil, space = nil }
	update_sketchybar()
end)

-- Manual reload for testing
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "S", function()
	previous_state = { windows = {}, focused = nil, space = nil }
	update_sketchybar()
end)

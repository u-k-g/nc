local sketchybar = "@sketchybar@"
local max_items = 12
local focused_color = "0xff@base05@"
local unfocused_color = "0x80@base05@"

paneru.setup {
  jump_picker = {
    enabled = true,
  },

  options = {
    focus_follows_mouse = false,
    mouse_follows_focus = true,
    animation_speed = 37.0,
    auto_center = true,
    sliver_width = 1,
    window_hidden_ratio = 0.0,
  },

  decorations = {
    workspace_menu_status = false,
  },

  padding = {
    top = 4,
    bottom = 4,
    left = 8,
    right = 8,
  },

  swipe = {
    sensitivity = 0.88,
    snap_to_window = true,
    gesture = {
      fingers_count = 3,
      direction = "Reversed",
      vertical = true,
    },
    scroll = {
      modifier = "ctrl + shift + cmd",
    },
  },

  windows = {
    default = {
      title = ".*",
      horizontal_padding = 4,
      vertical_padding = 4,
    },
    antinote = {
      title = ".*",
      bundle_id = "com.chabomakers.Antinote",
      floating = true,
    },
  },

  bindings = {
    ["window virtualnum 1"] = "alt - 1",
    ["window virtualnum 2"] = "alt - 2",
    ["window virtualnum 3"] = "alt - 3",
    ["window virtualnum 4"] = "alt - 4",
    ["window virtualnum 5"] = "alt - 5",
    ["window virtualnum 6"] = "alt - 6",
    ["window virtualnum 7"] = "alt - 7",
    ["window virtualnum 8"] = "alt - 8",
    ["window virtualnum 9"] = "alt - 9",

    ["window virtualmovenum 1"] = "alt + shift - 1",
    ["window virtualmovenum 2"] = "alt + shift - 2",
    ["window virtualmovenum 3"] = "alt + shift - 3",
    ["window virtualmovenum 4"] = "alt + shift - 4",
    ["window virtualmovenum 5"] = "alt + shift - 5",
    ["window virtualmovenum 6"] = "alt + shift - 6",
    ["window virtualmovenum 7"] = "alt + shift - 7",
    ["window virtualmovenum 8"] = "alt + shift - 8",
    ["window virtualmovenum 9"] = "alt + shift - 9",

    ["window focus west"] = "alt - h",
    ["window focus south"] = "alt + cmd - j",
    ["window focus north"] = "alt + cmd - k",
    ["window focus east"] = "alt - l",

    ["window swap west"] = "alt + shift - h",
    ["window swap east"] = "alt + shift - l",

    ["window virtual south"] = "alt - j",
    ["window virtual north"] = "alt - k",
    ["window virtualmove south"] = "alt + shift - j",
    ["window virtualmove north"] = "alt + shift - k",

    ["window stack"] = "alt + shift - t",
    ["window unstack"] = "alt + shift - g",
    ["window manage"] = "alt + ctrl - f",
    ["window fullwidth"] = "alt - f",
    ["window snap"] = "alt - s",
    ["window shrink"] = "alt + shift - minus",
    ["window grow"] = "alt + shift - equal",
  },
}

local function trim(value)
  return value:match("^%s*(.-)%s*$")
end

local function load_icon_map(filename)
  local entries = {}
  local patterns = {}

  for line in io.lines(filename) do
    local current = trim(line)

    if current:sub(-1) == ")"
      and not current:match("^case ")
      and not current:match("^for ")
    then
      patterns = {}
      for pattern, star in current:gmatch('"([^"]+)"(%*?)') do
        patterns[#patterns + 1] = {
          pattern = pattern,
          star = star == "*",
        }
      end
    end

    local icon = current:match('^icon_result="([^"]+)"')
    if icon then
      for _, pattern in ipairs(patterns) do
        pattern.icon = icon
        entries[#entries + 1] = pattern
      end
      patterns = {}
    end
  end

  return entries
end

local icon_map = load_icon_map("@icon_map@")

local function icon_for_app(name)
  for _, entry in ipairs(icon_map) do
    local matches = name == entry.pattern
      or (entry.star and name:sub(1, #entry.pattern) == entry.pattern)
    if matches then
      return entry.icon
    end
  end

  return ":default:"
end

local function first_characters(value, count)
  local result = {}
  for character in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    result[#result + 1] = character
    if #result == count then
      break
    end
  end
  return table.concat(result)
end

local function app_label(name)
  if name == "" then
    return "?"
  end

  local capitals = name:gsub("[^A-Z]", "")
  if #capitals == 2 then
    return capitals
  end

  return first_characters(name, 2)
end

local function run_sketchybar(arguments)
  local result = paneru.exec(sketchybar, arguments)
  if result.code ~= 0 then
    paneru.log("sketchybar update failed: " .. (result.stderr or "unknown error"))
    return false
  end
  return true
end

local function active_windows(state)
  local active = state.active or {}
  local active_native = active.native_workspace_id
  local active_virtual = active.virtual_workspace_number
  local workspace = nil

  for _, candidate in ipairs(state.virtual_workspaces or {}) do
    if candidate.native_workspace_id == active_native
      and candidate.number == active_virtual
    then
      workspace = candidate
      break
    end
  end

  if not workspace then
    return {}
  end

  local result = {}
  for _, window in ipairs(workspace.windows or {}) do
    if #result == max_items then
      break
    end

    local name = trim(window.app_name or "")
    if name == "" then
      name = "Unknown"
    end

    result[#result + 1] = {
      id = window.window_id,
      name = name,
      icon = icon_for_app(name),
      focused = window.focused == true or window.window_id == active.focused_window_id,
    }
  end

  return result
end

local function render_windows(windows)
  local arguments = {}

  for index = 0, max_items - 1 do
    local item = "paperwm_" .. index
    local window = windows[index + 1]

    arguments[#arguments + 1] = "--set"
    arguments[#arguments + 1] = item

    if not window then
      arguments[#arguments + 1] = "drawing=off"
    else
      local color = window.focused and focused_color or unfocused_color
      arguments[#arguments + 1] = "drawing=on"

      if window.icon == ":default:" then
        arguments[#arguments + 1] = "icon.drawing=off"
        arguments[#arguments + 1] = "label.drawing=on"
        arguments[#arguments + 1] = "label=" .. app_label(window.name)
        arguments[#arguments + 1] = "label.font=DepartureMono Nerd Font Mono:Regular:14.0"
      else
        arguments[#arguments + 1] = "label.drawing=off"
        arguments[#arguments + 1] = "icon.drawing=on"
        arguments[#arguments + 1] = "icon=" .. window.icon
      end

      arguments[#arguments + 1] = "icon.color=" .. color
      arguments[#arguments + 1] = "label.color=" .. color
    end
  end

  return run_sketchybar(arguments)
end

local windows = {}
local focused_window_id = nil
local update_running = false
local refresh_pending = false
local focus_pending = nil

local function refresh_windows()
  local state = paneru.query_state()
  local updated = active_windows(state)
  if render_windows(updated) then
    windows = updated
    focused_window_id = state.active and state.active.focused_window_id or nil
  end
end

local function update_focus(window_id)
  local arguments = {}
  local found = false

  for index, window in ipairs(windows) do
    if window.id == focused_window_id or window.id == window_id then
      local color = window.id == window_id and focused_color or unfocused_color
      arguments[#arguments + 1] = "--set"
      arguments[#arguments + 1] = "paperwm_" .. (index - 1)
      arguments[#arguments + 1] = "icon.color=" .. color
      arguments[#arguments + 1] = "label.color=" .. color
    end
    if window.id == window_id then
      found = true
    end
  end

  if not found then
    refresh_windows()
    return
  end

  if #arguments > 0 and run_sketchybar(arguments) then
    for _, window in ipairs(windows) do
      window.focused = window.id == window_id
    end
    focused_window_id = window_id
  end
end

local function drain_updates()
  if update_running then
    return
  end

  update_running = true
  while refresh_pending or focus_pending do
    if refresh_pending then
      refresh_pending = false
      focus_pending = nil
      refresh_windows()
    else
      local window_id = focus_pending
      focus_pending = nil
      update_focus(window_id)
    end
  end
  update_running = false
end

local function request_refresh()
  refresh_pending = true
  focus_pending = nil
  drain_updates()
end

local function request_focus(event)
  if not refresh_pending then
    focus_pending = event.window_id
  end
  drain_updates()
end

paneru.on("window_focused", request_focus)

for _, event in ipairs {
  "processes_loaded",
  "window_spawned",
  "window_destroyed",
  "window_moved",
  "window_resized",
  "window_minimized",
  "window_deminimized",
  "window_title_changed",
  "application_visible",
  "application_hidden",
  "space_created",
  "space_destroyed",
  "space_changed",
  "display_added",
  "display_removed",
  "display_moved",
  "display_resized",
  "display_configured",
  "display_changed",
  "system_woke",
} do
  paneru.on(event, request_refresh)
end

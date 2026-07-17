local wezterm = require("wezterm")

local config = wezterm.config_builder()

local default_theme = "nord"
local config_home = os.getenv("XDG_CONFIG_HOME") or (wezterm.home_dir .. "/.config")
local state_home = os.getenv("XDG_STATE_HOME") or (wezterm.home_dir .. "/.local/state")
local catalog_file = config_home .. "/nvim/theme-switcher/themes"
local state_file = state_home .. "/theme-switcher/current"

local function trim(value)
	return (value or ""):match("^%s*(.-)%s*$")
end

local function theme_executable()
	local user = os.getenv("USER") or wezterm.home_dir:match("[^/]+$")
	local candidates = {
		wezterm.home_dir .. "/.nix-profile/bin/theme",
		wezterm.home_dir .. "/.local/state/nix/profiles/profile/bin/theme",
		"/etc/profiles/per-user/" .. user .. "/bin/theme",
	}

	for _, candidate in ipairs(candidates) do
		local file = io.open(candidate, "r")
		if file then
			file:close()
			return candidate
		end
	end

	return "theme"
end

local function current_theme_id()
	local file = io.open(state_file, "r")
	if not file then
		return default_theme
	end

	local id = file:read("*l")
	file:close()
	return id or default_theme
end

local function current_color_scheme()
	local selected = current_theme_id()
	local file = io.open(catalog_file, "r")
	if not file then
		return "Nord (Gogh)"
	end

	for line in file:lines() do
		if line ~= "" and line:sub(1, 1) ~= "#" then
			local id, _, scheme =
				line:match("^([^|]+)|([^|]+)|([^|]+)|[^|]+|[^|]+|[^|]+|[^|]+|[^|]+$")
			if id == selected then
				file:close()
				return scheme
			end
		end
	end
	file:close()
	return "Nord (Gogh)"
end

wezterm.add_to_config_reload_watch_list(catalog_file)
wezterm.add_to_config_reload_watch_list(state_file)

config.color_scheme = current_color_scheme()
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 12.0
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.keys = {
	{
		key = "t",
		mods = "SUPER|SHIFT",
		action = wezterm.action_callback(function(window)
			local success, stdout, stderr = wezterm.run_child_process({ theme_executable(), "next" })
			if not success then
				window:toast_notification("Theme switch failed", trim(stderr), nil, 4000)
				return
			end

			window:toast_notification("Theme", trim(stdout), nil, 2000)
			wezterm.reload_configuration()
		end),
	},
	{
		key = "o",
		mods = "SUPER|SHIFT",
		action = wezterm.action_callback(function(window)
			local overrides = window:get_config_overrides() or {}

			if overrides.window_background_opacity then
				overrides.window_background_opacity = nil
				overrides.macos_window_background_blur = nil
			else
				overrides.window_background_opacity = 0.8
				overrides.macos_window_background_blur = 50
			end

			window:set_config_overrides(overrides)
		end),
	},
	{
		-- Recover terminal modes if an SSH connection dies before a remote TUI
		-- can disable mouse reporting. This resets and clears the active pane.
		key = "r",
		mods = "SUPER|SHIFT",
		action = wezterm.action.ResetTerminal,
	},
}

return config

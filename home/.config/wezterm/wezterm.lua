local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "Nord (Gogh)"
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 12.0
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

return config

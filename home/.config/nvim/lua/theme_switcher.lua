local M = {}

local default_theme = "nord"
local state_home = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local state_dir = state_home .. "/theme-switcher"
local state_file = state_dir .. "/current"
local catalog_file = vim.fn.stdpath("config") .. "/theme-switcher/themes"

local themes = {}
local themes_by_id = {}

local function load_catalog()
	local file, error_message = io.open(catalog_file, "r")
	if not file then
		error(("cannot read theme catalog %s: %s"):format(catalog_file, error_message))
	end

	for line in file:lines() do
		if line ~= "" and line:sub(1, 1) ~= "#" then
			local id, label, wezterm, neovim =
				line:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)|[^|]+|[^|]+|[^|]+|[^|]+$")
			if not id then
				file:close()
				error(("invalid theme catalog entry: %s"):format(line))
			end

			local theme = { id = id, label = label, wezterm = wezterm, neovim = neovim }
			table.insert(themes, theme)
			themes_by_id[id] = theme
		end
	end
	file:close()

	if not themes_by_id[default_theme] then
		error(("theme catalog is missing default theme %q"):format(default_theme))
	end
end

local function ensure_state_file()
	vim.fn.mkdir(state_dir, "p")
	if vim.uv.fs_stat(state_file) then
		return
	end

	local file, error_message = io.open(state_file, "w")
	if not file then
		error(("cannot create theme state %s: %s"):format(state_file, error_message))
	end
	file:write(default_theme, "\n")
	file:close()
end

local function read_current_id()
	local file = io.open(state_file, "r")
	if not file then
		return default_theme
	end

	local id = file:read("*l")
	file:close()
	return themes_by_id[id] and id or default_theme
end

local function run_theme_command(...)
	local arguments = { "theme", ... }
	vim.system(arguments, { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local stderr = result.stderr or ""
				local stdout = result.stdout or ""
				local message = vim.trim(stderr ~= "" and stderr or stdout)
				vim.notify(
					message ~= "" and message or "Theme command failed",
					vim.log.levels.ERROR,
					{ title = "Theme" }
				)
				return
			end

			M.apply()
			vim.notify(vim.trim(result.stdout or ""), vim.log.levels.INFO, { title = "Theme" })
		end)
	end)
end

function M.apply()
	local theme = themes_by_id[read_current_id()]
	if vim.g.colors_name == theme.neovim then
		return
	end

	local ok, error_message = pcall(vim.cmd.colorscheme, theme.neovim)
	if not ok then
		vim.notify(
			("Could not apply %s: %s"):format(theme.label, error_message),
			vim.log.levels.ERROR,
			{ title = "Theme" }
		)
	end
end

local function watch_state_file()
	local watcher = vim.uv.new_fs_event()
	local ok, error_message = watcher:start(state_file, {}, function()
		vim.schedule(M.apply)
	end)
	if not ok then
		watcher:close()
		error(("cannot watch theme state %s: %s"):format(state_file, error_message))
	end

	M._watcher = watcher
	vim.api.nvim_create_autocmd("VimLeavePre", {
		once = true,
		callback = function()
			if M._watcher and not M._watcher:is_closing() then
				M._watcher:stop()
				M._watcher:close()
			end
		end,
	})
end

function M.setup()
	load_catalog()
	ensure_state_file()
	M.apply()
	watch_state_file()

	vim.api.nvim_create_user_command("Theme", function(options)
		run_theme_command("set", options.args)
	end, {
		nargs = 1,
		complete = function()
			return vim.tbl_map(function(theme)
				return theme.id
			end, themes)
		end,
		desc = "Set the shared WezTerm and Neovim theme",
	})
	vim.api.nvim_create_user_command("ThemeNext", function()
		run_theme_command("next")
	end, { desc = "Select the next shared theme" })
	vim.api.nvim_create_user_command("ThemePrev", function()
		run_theme_command("prev")
	end, { desc = "Select the previous shared theme" })
	vim.api.nvim_create_user_command("ThemeList", function()
		local current = read_current_id()
		local lines = vim.tbl_map(function(theme)
			return ("%s %s - %s"):format(theme.id == current and "*" or " ", theme.id, theme.label)
		end, themes)
		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Themes" })
	end, { desc = "List shared themes" })

	vim.keymap.set("n", "<leader>tn", "<cmd>ThemeNext<cr>", { desc = "Next Theme" })
	vim.keymap.set("n", "<leader>tp", "<cmd>ThemePrev<cr>", { desc = "Previous Theme" })
end

return M

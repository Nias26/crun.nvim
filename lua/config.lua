---@alias WinPosition "bottom" | "top" | "left" | "right" | "float"
---@alias CompMode "history" | "path" | "both"

---@class CrunWinOpts
---@field position WinPosition        window position
---@field height   integer            window height
---@field width    integer            window width
---@field name     string             window name

---@class CrunOpts
---@field completion  CompMode        what completion to show
---@field timestamps  boolean         print start/finish banners like Emacs compile mode
---@field color       boolean         force color output from the child process
---@field window      CrunWinOpts     window options
---@field echo        boolean         echo the command inside the buffer

local M = {}

---@type CrunOpts
M.defaults = {
	completion = "path",
	timestamps = true,
	color = true,
	window = {
		position = "bottom",
		height = 15,
		width = 80,
		name = "[Crun]",
	},
	echo = false,
}

---@type CrunOpts
M.current = vim.deepcopy(M.defaults)

---@param user_opts CrunOpts
function M.set(user_opts)
	M.current = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M

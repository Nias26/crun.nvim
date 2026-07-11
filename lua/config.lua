---@alias WinPosition "bottom" | "top" | "left" | "right" | "float"
---@alias CompMode "history" | "path" | "both"

---@class CrunWinOpts
---@field position WinPosition
---@field height   integer
---@field width    integer
---@field name     string

---@class CrunQuickfixOpts
---@field enabled boolean  parse output into the quickfix list on exit
---@field open    boolean  auto-open the quickfix window when errors are found

---@class CrunOpts
---@field completion  CompMode
---@field timestamps  boolean         print start/finish banners like Emacs compile mode
---@field color       boolean         force color output from the child process
---@field errorformat string|nil      errorformat used to parse output; nil = current &errorformat
---@field quickfix    CrunQuickfixOpts
---@field window      CrunWinOpts
---@field echo        boolean         echo the command inside the buffer

local M = {}

---@type CrunOpts
M.defaults = {
	completion = "path",
	timestamps = true,
	color = true,
	errorformat = nil,
	quickfix = {
		enabled = true,
		open = false,
	},
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

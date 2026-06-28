---@alias WinPosition "bottom" | "top" | "left" | "right" | "float"
---@alias CompMode "history" | "path" | "both"

---@class CrunWinOpts
---@field position WinPosition
---@field height   integer
---@field width    integer
---@field name     string

---@class CrunOpts
---@field completion CompMode
---@field window     CrunWinOpts

local M = {}

---@type CrunOpts
M.defaults = {
	completion = "path",
	window = {
		position = "bottom",
		height = 15,
		width = 80,
		name = "[Crun]",
	},
}

---@type CrunOpts
M.current = vim.deepcopy(M.defaults)

---@param user_opts CrunOpts
function M.set(user_opts)
	M.current = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M

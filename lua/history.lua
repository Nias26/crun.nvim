local M = {}

local MAX = 20

local function saved()
	if not _G.crun_saved then
		_G.crun_saved = { last_args = nil, oldargs = {} }
	end
	return _G.crun_saved
end

---@param args string
function M.push(args)
	local s = saved()
	if not vim.tbl_contains(s.oldargs, args) then
		if #s.oldargs >= MAX then
			table.remove(s.oldargs, 1)
		end
		s.oldargs[#s.oldargs + 1] = args
	end
	s.last_args = args
end

---@return string|nil
function M.last()
	return saved().last_args
end

return M

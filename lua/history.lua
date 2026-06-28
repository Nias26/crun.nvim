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

---@param arglead     string
---@param mode        "history"|"path"|"both"
---@return string[]
function M.complete(arglead, mode)
	local completions = {}
	local seen = {}

	if mode == "path" or mode == "both" then
		for _, v in ipairs(vim.fn.getcompletion(arglead, "file")) do
			if not seen[v] then
				seen[v] = true
				completions[#completions + 1] = v
			end
		end
	end

	if mode == "history" or mode == "both" then
		local s = saved()
		for _, old in ipairs(vim.iter(s.oldargs):rev():totable()) do
			if old:sub(1, #arglead) == arglead and not seen[old] then
				seen[old] = true
				completions[#completions + 1] = old
			end
		end
	end

	return completions
end

return M

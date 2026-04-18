---@class Crun
---@field public setup function Constructor
---@field public Crun function Execute a new program
---@field public Ckill function Kill current running program
---@field private split_lines function
---@field private parse_line function
---@field private to_qf function
---@field private qftf function
---@field private make_stream_handler function
local M = {}

local fn = vim.fn
local schedule = vim.schedule
local tbl_contains = vim.tbl_contains

---@type function
---@param buf string
---@param leftover string
---@return table, string
local function split_lines(buf, leftover)
	if leftover ~= "" then
		buf = leftover .. buf
	end
	local lines, n = {}, 0
	local i, len = 1, #buf
	while i <= len do
		local nl = string.find(buf, "\n", i, true)
		if nl then
			n = n + 1
			lines[n] = string.sub(buf, i, nl - 1)
			i = nl + 1
		else
			return lines, string.sub(buf, i)
		end
	end
	return lines, ""
end

---@type function
---@param text string
---@return table
local function parse_line(text)
	-- rg --vimgrep: file:line:col:text
	local file, lnum, col, msg = text:match("^([^:]+):(%d+):(%d+):(.*)")
	if file then
		return { filename = file, lnum = tonumber(lnum), col = tonumber(col), text = msg }
	end
	-- grep -rn: file:line:text
	file, lnum, msg = text:match("^([^:]+):(%d+):(.*)")
	if file then
		return { filename = file, lnum = tonumber(lnum), text = msg }
	end
	-- plain output
	return { text = text }
end

---@type function
---@param lines table
---@param n number
---@return table
local function to_qf(lines, n)
	local items = {}
	for i = 1, n do
		items[i] = parse_line(lines[i])
	end
	return items
end

---@type function
---@param args string
---@param has_output_ref table
---@return function, function
local function make_stream_handler(args, has_output_ref)
	local leftover = ""
	return function(_, data)
		if not data then
			return
		end
		schedule(function()
			local lines, tail = split_lines(data, leftover)
			leftover = tail
			local n = #lines
			if n == 0 then
				return
			end
			local items = to_qf(lines, n)
			if not has_output_ref[1] then
				has_output_ref[1] = true
				fn.setqflist({}, "r", { title = "Output: " .. args, items = items })
			else
				fn.setqflist({}, "a", { items = items })
			end
		end)
	end, function()
		return leftover
	end
end

---@type function
---@param info table
---@return table
function M.qftf(info)
	local qf = vim.fn.getqflist({ id = info.id, title = 1, items = 1 })

	-- Only apply to Crun quickfix lists
	if not qf.title or not qf.title:match("^Output:") then
		-- Replicate default Neovim formatting for other lists
		local result = {}
		for i = info.start_idx, info.end_idx do
			local item = qf.items[i]
			local fname = item.bufnr > 0 and vim.fn.bufname(item.bufnr) or ""
			if fname ~= "" then
				result[#result + 1] = string.format("%s|%d|%s", fname, item.lnum, item.text)
			else
				result[#result + 1] = "|| " .. item.text
			end
		end
		return result
	end

	local result = {}
	for i = info.start_idx, info.end_idx do
		local item = qf.items[i]
		local fname = item.bufnr > 0 and vim.fn.bufname(item.bufnr) or ""
		if fname ~= "" then
			-- grep/rg results: show location normally
			result[#result + 1] = string.format("%s|%d|%s", fname, item.lnum, item.text)
		else
			-- plain output: just the text, no ||
			result[#result + 1] = item.text
		end
	end
	return result
end

---@type function
---@return nil
function M.kill()
	local saved = _G.crun_saved
	if not saved.process then
		vim.notify("Crun: no process is running", vim.log.levels.WARN)
		return
	end
	---@diagnostic disable-next-line: undefined-field
	saved.process:kill(15)
end

---@type function
---@param opts table
---@return nil
function M.crun(opts)
	local saved = _G.crun_saved
	if saved.process then
		---@diagnostic disable-next-line: undefined-field
		saved.process:kill(15)
		saved.process = nil
	end

	if opts.args ~= "" then
		local old = saved.oldargs
		if not tbl_contains(old, opts.args) then
			if #old >= 20 then
				table.remove(old, 1)
			end
			old[#old + 1] = opts.args
		end
		saved.last_args = opts.args
	else
		opts.args = saved.last_args
	end

	if not opts.args or opts.args == "" then
		print("No command to execute")
		return
	end

	---@type string
	local args = opts.args
	local cmd = vim.split(args, " ", { plain = true })

	fn.setqflist({}, "r", { title = "Output: " .. args, items = { { text = "Running..." } } })
	vim.cmd("copen")

	local has_output = { false }
	local stdout_handler, flush_stdout = make_stream_handler(args, has_output)
	local stderr_handler, flush_stderr = make_stream_handler(args, has_output)

	saved.process = vim.system(cmd, { text = true, stdout = stdout_handler, stderr = stderr_handler }, function(obj)
		schedule(function()
			saved.process = nil

			local tails = {}
			local so, se = flush_stdout(), flush_stderr()
			if so ~= "" then
				tails[#tails + 1] = { text = so }
			end
			if se ~= "" then
				tails[#tails + 1] = { text = se }
			end

			local exit_note
			if obj.signal ~= 0 then
				exit_note = ("-- killed (signal %d) --"):format(obj.signal)
			elseif obj.code ~= 0 then
				exit_note = ("-- exited with code %d --"):format(obj.code)
			end
			if exit_note then
				tails[#tails + 1] = { text = exit_note }
			end

			if #tails > 0 then
				if not has_output[1] then
					fn.setqflist({}, "r", { title = "Output: " .. args, items = tails })
				else
					fn.setqflist({}, "a", { items = tails })
				end
				has_output[1] = true
			end

			if not has_output[1] then
				vim.cmd("cclose")
			end
		end)
	end)
end

---@alias CompMode "history" | "path" | "both"
---@class CrunOpts
---@field completion CompMode
local defaults = {
	completion = "path",
}

---@param opts CrunOpts
---@return nil
function M.setup(opts)
	opts = opts or defaults

	local completion_mode = opts.completion or "both"

	if not _G.crun_saved then
		_G.crun_saved = { last_args = nil, oldargs = {}, process = nil }
	end

	vim.api.nvim_create_user_command("Cc", M.crun, {
		nargs = "*",
		complete = function(arglead, _, _)
			local saved = _G.crun_saved
			local completions = {}
			local seen = {}

			if completion_mode == "path" or completion_mode == "both" then
				for _, v in ipairs(vim.fn.getcompletion(arglead, "file")) do
					if not seen[v] then
						seen[v] = true
						completions[#completions + 1] = v
					end
				end
			end

			if completion_mode == "history" or completion_mode == "both" then
				if saved then
					for _, old in ipairs(vim.iter(saved.oldargs):rev():totable()) do
						if old:sub(1, #arglead) == arglead and not seen[old] then
							seen[old] = true
							completions[#completions + 1] = old
						end
					end
				end
			end

			return completions
		end,
	})

	vim.api.nvim_create_user_command("Ckill", M.kill, {})

	vim.o.quickfixtextfunc = "{info -> v:lua.require('crun').qftf(info)}"
end

return M

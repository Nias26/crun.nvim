local M = {}
local fn = vim.fn
local schedule = vim.schedule
local tbl_contains = vim.tbl_contains

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

local function to_qf(lines, n)
	local items = {}
	for i = 1, n do
		items[i] = { text = lines[i] }
	end
	return items
end

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

local function setup_qf_kill_map()
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = vim.api.nvim_create_augroup("CrunQfKill", { clear = true }),
		callback = function()
			if vim.bo.filetype == "qf" then
				vim.keymap.set(
					"n",
					"K",
					"<cmd>Ckill<cr>",
					{ buffer = true, silent = true, desc = "Kill running Crun process" }
				)
			end
		end,
	})
end

function M.setup(_opts)
	_opts = _opts or {}

	if not _G._crun_saved then
		_G._crun_saved = { last_args = nil, oldargs = {}, process = nil }
	end
	local saved = _G._crun_saved

	setup_qf_kill_map()

	vim.api.nvim_create_user_command("Crun", function(opts)
		-- Kill any previously running process before starting a new one.
		if saved.process then
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
	end, {
		nargs = "*",
		complete = function()
			if not _G._crun_saved then
				return {}
			end
			return vim.iter(_G._crun_saved.oldargs):rev():totable()
		end,
	})

	vim.api.nvim_create_user_command("Ckill", function()
		if not saved.process then
			vim.notify("Crun: no process is running", vim.log.levels.WARN)
			return
		end
		---@diagnostic disable-next-line: undefined-field
		saved.process:kill(15)
		vim.notify("Crun: sent SIGTERM to " .. (saved.last_args or "?"))
	end, {})
end

return M

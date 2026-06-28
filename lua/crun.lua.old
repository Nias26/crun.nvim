-- TODO: 2026-06-27 16:48 - Nias: Use normal buffer instead of qf
-- TODO: 2026-06-27 16:48 - Nias: use errorformat
-- TODO: 2026-06-27 16:48 - Nias: Support colors
-- TODO: 2026-06-27 16:48 - Nias: Change text on start, end, and buffer name
-- TODO: 2026-06-27 16:49 - Nias: Make use of plenary.nvim for async tasks
---@class Crun
local M = {}

local fn = vim.fn
local schedule = vim.schedule

---@return nil
function M.kill()
	local saved = _G.crun_saved
	if not saved or not saved.process then
		vim.notify("Crun: no process is running", vim.log.levels.WARN)
		return
	end
	---@diagnostic disable-next-line: undefined-field
	saved.process:kill(15)
end

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
		if not vim.tbl_contains(old, opts.args) then
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
		vim.notify("Crun: no command to execute", vim.log.levels.WARN)
		return
	end

	local args = opts.args
	local cmd = fn.split(args)

	local efm = vim.o.errorformat

	local tmp = fn.tempname()
	local tmpfile = io.open(tmp, "w")
	if not tmpfile then
		vim.notify("Crun: could not create temp file", vim.log.levels.ERROR)
		return
	end

	fn.setqflist({}, "r", { title = args, items = { { text = "Running: " .. args } } })
	vim.cmd("copen")

	for _, win in ipairs(fn.getwininfo()) do
		if win.quickfix == 1 then
			vim.wo[win.winid].colorcolumn = "0"
			break
		end
	end

	saved.process = vim.system(cmd, {
		text = true,
		stdout = function(_, data)
			if data then
				tmpfile:write(data)
			end
		end,
		stderr = function(_, data)
			if data then
				tmpfile:write(data)
			end
		end,
	}, function(obj)
		tmpfile:close()

		schedule(function()
			saved.process = nil

			local save_efm = vim.o.errorformat
			vim.o.errorformat = efm
			vim.cmd("cgetfile " .. fn.fnameescape(tmp))
			vim.o.errorformat = save_efm
			os.remove(tmp)

			fn.setqflist({}, "a", { title = args })

			local status
			if obj.signal ~= 0 then
				status = ("-- killed (signal %d) --"):format(obj.signal)
			elseif obj.code ~= 0 then
				status = ("-- exited with code %d --"):format(obj.code)
			else
				status = "-- done --"
			end
			fn.setqflist({}, "a", {
				items = {
					{ text = "" },
					{ text = status },
				},
			})

			local qf = fn.getqflist()
			if #qf == 1 and qf[1].text == status then
				vim.cmd("cclose")
				vim.notify("Crun: " .. status, vim.log.levels.INFO)
			end

			---@diagnostic disable-next-line: undefined-field, need-check-nil
			vim.o.makeprg = args:gsub(" ", "\\ ")

			vim.api.nvim_exec_autocmds("User", {
				pattern = "CrunPost",
				data = args,
			})
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
	opts = vim.tbl_deep_extend("force", defaults, opts or {})

	local completion_mode = opts.completion

	if not _G.crun_saved then
		_G.crun_saved = {
			last_args = nil,
			oldargs = {},
			process = nil,
		}
	end

	vim.api.nvim_create_user_command("Cc", M.crun, {
		nargs = "*",
		complete = function(arglead, _, _)
			local saved = _G.crun_saved
			local completions = {}
			local seen = {}

			if completion_mode == "path" or completion_mode == "both" then
				for _, v in ipairs(fn.getcompletion(arglead, "file")) do
					if not seen[v] then
						seen[v] = true
						completions[#completions + 1] = v
					end
				end
			end

			if completion_mode == "history" or completion_mode == "both" then
				for _, old in ipairs(vim.iter(saved.oldargs):rev():totable()) do
					if old:sub(1, #arglead) == arglead and not seen[old] then
						seen[old] = true
						completions[#completions + 1] = old
					end
				end
			end

			return completions
		end,
	})

	vim.api.nvim_create_user_command("Ckill", M.kill, {})

	vim.api.nvim_create_autocmd("OptionSet", {
		pattern = "makeprg",
		callback = function()
			local saved = _G.crun_saved
			if not saved then
				return
			end
			local mp = vim.o.makeprg
			mp = mp:gsub("\\ ", " ")
			if mp ~= "" and mp ~= "make" then
				saved.last_args = mp
			end
		end,
	})
end

return M

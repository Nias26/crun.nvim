local buf = require("buf")
local win = require("win")
local config = require("config")
local api = vim.api
local fn = vim.fn

local M = {}

local job_id = -1

---@return string | osdate
local function clock()
	return os.date("%a %b %d %H:%M:%S")
end

---@param seconds number
---@return string
local function fmt_elapsed(seconds)
	if seconds < 60 then
		return ("%.1fs"):format(seconds)
	end
	local m = math.floor(seconds / 60)
	local s = seconds - (m * 60)
	return ("%dm %.1fs"):format(m, s)
end

---@param args_str string  command that was run, used as the quickfix title
local function populate_quickfix(args_str)
	local qcfg = config.current.quickfix
	if not qcfg or not qcfg.enabled then
		return
	end

	local bufid = buf.get()
	if bufid == -1 or not api.nvim_buf_is_valid(bufid) then
		return
	end

	local lines = api.nvim_buf_get_lines(bufid, 0, -1, false)
	local efm = config.current.errorformat or vim.o.errorformat

	fn.setqflist({}, " ", {
		title = args_str,
		lines = lines,
		efm = efm,
	})

	local count = #fn.getqflist()
	if count > 0 then
		vim.notify(("Crun: %d error(s) found"):format(count), vim.log.levels.WARN)
		if qcfg.open then
			vim.cmd("copen")
			-- keep focus on the crun window/buffer rather than the quickfix list
			local wid = win.find()
			if wid ~= -1 then
				api.nvim_set_current_win(wid)
			end
		end
	end
end

function M.kill()
	if job_id > 0 then
		fn.jobstop(job_id)
		vim.notify("Crun: killed", vim.log.levels.WARN)
	else
		vim.notify("Crun: no process is running", vim.log.levels.WARN)
	end
end

---@return boolean
function M.is_running()
	return job_id > 0
end

---@param args_str string  full command string
function M.run(args_str)
	if job_id > 0 then
		fn.jobstop(job_id)
		job_id = -1
	end

	local argv = fn.split(args_str)
	local command = argv[1]
	if not command or fn.executable(command) == 0 then
		vim.notify("Crun: command not found: " .. (command or ""), vim.log.levels.ERROR)
		return
	end

	buf.prepare()

	win.open()

	local chanid = buf.open_term(function(data)
		if job_id > 0 then
			fn.chansend(job_id, data)
		end
	end)

	buf.send("~> " .. args_str .. "\r\n")

	local hr_start = vim.loop.hrtime()

	if config.current.timestamps then
		buf.send(("-- Crun started at %s --\r\n\r\n"):format(clock()))
	end

	local env
	if config.current.color then
		env = {
			FORCE_COLOR = "1",
			CLICOLOR_FORCE = "1",
			TERM = vim.env.TERM or "xterm-256color",
		}
	end

	job_id = fn.jobstart(argv, {
		pty = true,
		width = win.width(),
		env = env,
		on_stdout = function(_, data, _)
			local chunk = table.concat(data, "\n")
			if chunk ~= "" then
				api.nvim_chan_send(chanid, chunk)
			end
		end,
		on_exit = function(_, code, _)
			job_id = -1

			local elapsed = (vim.loop.hrtime() - hr_start) / 1e9

			if config.current.timestamps then
				local status = code == 0 and "finished" or ("exited with code %d"):format(code)
				local banner = ("\r\n-- Crun %s at %s (elapsed %s) --\r\n"):format(
					status,
					clock(),
					fmt_elapsed(elapsed)
				)
				api.nvim_chan_send(chanid, banner)
			else
				local status = code == 0 and "-- done --" or ("-- exited with code %d --"):format(code)
				api.nvim_chan_send(chanid, "\r\n" .. status .. "\r\n")
			end

			-- defer so the terminal buffer has flushed the lines above before we read them
			vim.schedule(function()
				populate_quickfix(args_str)
			end)

			api.nvim_exec_autocmds("User", { pattern = "CrunPost", data = args_str })
		end,
	})

	if job_id <= 0 then
		win.close()
		vim.notify("Crun: failed to start: " .. args_str, vim.log.levels.ERROR)
		return
	end

	buf.on_close(function()
		if job_id > 0 then
			fn.jobstop(job_id)
			job_id = -1
		end
	end)
end

return M

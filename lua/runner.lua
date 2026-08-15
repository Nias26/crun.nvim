local buf = require("buf")
local win = require("win")
local config = require("config")
local api = vim.api
local fn = vim.fn

local M = {}

local job_id = -1
local queue = {}

local ANSI_GREEN = "\27[38;2;80;200;120m"
local ANSI_RED = "\27[38;2;220;60;60m"
local ANSI_RESET = "\27[0m"

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

function M.kill()
	queue = {}
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
		table.insert(queue, args_str)
		vim.notify("Crun: queued: " .. args_str, vim.log.levels.INFO)
		return
	end

	M.exec(args_str)
end

---@param args_str string  full command string
function M.exec(args_str)
	local argv = fn.split(args_str)
	local command = argv[1]
	if not command or fn.executable(command) == 0 then
		vim.notify("Crun: command not found: " .. (command or ""), vim.log.levels.ERROR)
		return
	end

	-- Reuses the existing terminal buffer/window when one is already
	-- open; only creates/opens them when they don't exist yet.
	buf.prepare()

	if not win.is_open() then
		win.open()
	end

	local chanid = buf.chan()
	if not chanid or not buf.is_open() or not buf.is_valid() then
    print("[*] Opening a new terminal")
		chanid = buf.open_term(function(data)
			if job_id > 0 then
				fn.chansend(job_id, data)
			end
		end)
	end

	if config.current.echo then
		buf.send("Running: " .. args_str .. "\r\n")
	end

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

	job_id = fn.jobstart(args_str, {
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
				local color
				if code == 0 then
					color = vim.o.termguicolors and ANSI_GREEN or "\27[32m"
				else
					color = vim.o.termguicolors and ANSI_RED or "\27[31m"
				end
				local banner = ("\n\r\n-- Crun %s%s%s at %s (elapsed %s) --\r\n"):format(
					color,
					status,
					ANSI_RESET,
					clock(),
					fmt_elapsed(elapsed)
				)
				api.nvim_chan_send(chanid, banner)
			else
				local green = vim.o.termguicolors and ANSI_GREEN or "\27[32m"
				local red = vim.o.termguicolors and ANSI_RED or "\27[31m"
				local status = code == 0 and "-- " .. green .. "done" .. ANSI_RESET .. " --"
					or ("-- " .. red .. "exited with code %d" .. ANSI_RESET .. " --"):format(code)
				api.nvim_chan_send(chanid, "\r\n" .. status .. "\r\n")
			end

			api.nvim_exec_autocmds("User", { pattern = "CrunPost", data = args_str })

			local next_cmd = table.remove(queue, 1)
			if next_cmd then
				vim.schedule(function()
					M.exec(next_cmd)
				end)
			end
		end,
	})

	if job_id <= 0 then
		win.close()
		vim.notify("Crun: failed to start: " .. args_str, vim.log.levels.ERROR)
		return
	end

	buf.on_close(function()
		queue = {}
		if job_id > 0 then
			fn.jobstop(job_id)
			job_id = -1
		end
	end)
end

return M

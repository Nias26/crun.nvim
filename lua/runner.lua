local buf = require("buf")
local win = require("win")
local api = vim.api
local fn = vim.fn

local M = {}

local job_id = -1

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

	job_id = fn.jobstart(argv, {
		pty = true,
		width = win.width(),
		on_stdout = function(_, data, _)
			local chunk = table.concat(data, "\n")
			if chunk ~= "" then
				api.nvim_chan_send(chanid, chunk)
			end
		end,
		on_exit = function(_, code, _)
			job_id = -1
			local status = code == 0 and "-- done --" or ("-- exited with code %d --"):format(code)
			api.nvim_chan_send(chanid, "\r\n" .. status .. "\r\n")
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

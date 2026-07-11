---@class Crun
local M = {}

local config = require("config")
local history = require("history")
local runner = require("runner")
local win = require("win")

---@param opts table  vim user-command opts ({args = "..."})
function M.run(opts)
	local args = opts.args ~= "" and opts.args or history.last()

	if not args or args == "" then
		vim.notify("Crun: no command to execute", vim.log.levels.WARN)
		return
	end

	history.push(args)
	runner.run(args)
end

function M.kill()
	runner.kill()
end

function M.toggle()
	win.toggle()
end

---@param direction "next"|"prev"
local function goto_error(direction)
	local ok, err = pcall(vim.cmd, direction == "next" and "cnext" or "cprevious")
	if not ok then
		vim.notify("Crun: " .. err:gsub("^.-:%d+: ", ""), vim.log.levels.WARN)
	end
end

function M.next_error()
	goto_error("next")
end

function M.prev_error()
	goto_error("prev")
end

function M.qf()
	vim.cmd("copen")
end

---@param user_opts CrunOpts
function M.setup(user_opts)
	config.set(user_opts)

	local mode = config.current.completion

	vim.api.nvim_create_user_command("Cc", M.run, {
		nargs = "*",
		complete = function(arglead)
			return history.complete(arglead, mode)
		end,
	})

	vim.api.nvim_create_user_command("Ckill", M.kill, {})
	vim.api.nvim_create_user_command("Ctoggle", M.toggle, {})
	vim.api.nvim_create_user_command("Cnext", M.next_error, {})
	vim.api.nvim_create_user_command("Cprev", M.prev_error, {})
	vim.api.nvim_create_user_command("Cqf", M.qf, {})
end

return M

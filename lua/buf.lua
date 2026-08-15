local config = require("config")
local api = vim.api

local M = {}

local bufid = -1
local chanid = -1
local close_registered = false

function M.is_valid()
	return bufid ~= -1 and api.nvim_buf_is_valid(bufid)
end

---@return integer
function M.get()
	return bufid
end

---@return integer
function M.chan()
	return chanid
end

---@return integer bufid
function M.prepare()
	if M.is_valid() then
		return bufid
	end

	bufid = api.nvim_create_buf(false, true)
	api.nvim_buf_set_name(bufid, config.current.window.name)
	vim.bo[bufid].swapfile = false
	vim.bo[bufid].buflisted = false
	vim.bo[bufid].filetype = "crun"
	chanid = -1
	close_registered = false

	return bufid
end

---@param on_input fun(data: string)
---@return integer chanid
function M.open_term(on_input)
	chanid = api.nvim_open_term(bufid, {
		on_input = function(_, _, _, data)
			on_input(data)
		end,
	})
	return chanid
end

---@param data string
function M.send(data)
	if chanid > 0 then
		api.nvim_chan_send(chanid, data)
	end
end

function M.clear()
	if chanid > 0 then
		api.nvim_chan_send(chanid, "\27[3J\27[2J\27[H")
	end
end

function M.scroll_to_bottom()
	if not M.is_valid() then
		return
	end
	local lc = api.nvim_buf_line_count(bufid)
	for _, wid in ipairs(api.nvim_list_wins()) do
		if api.nvim_win_get_buf(wid) == bufid then
			pcall(api.nvim_win_set_cursor, wid, { lc, 0 })
		end
	end
end

---@param on_close fun()
function M.on_close(on_close)
	if not M.is_valid() or close_registered then
		return
	end
	close_registered = true
	api.nvim_create_autocmd("BufWipeout", {
		buffer = bufid,
		once = true,
		callback = function()
			close_registered = false
			on_close()
		end,
	})
end

---@return boolean
function M.is_open()
	return chanid ~= -1
end

return M

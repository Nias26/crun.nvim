local config = require("config")
local buf = require("buf")
local api = vim.api

local M = {}

---@return integer
function M.find()
	local bid = buf.get()
	if bid == -1 then
		return -1
	end
	for _, wid in ipairs(api.nvim_list_wins()) do
		if api.nvim_win_get_buf(wid) == bid then
			return wid
		end
	end
	return -1
end

function M.is_open()
	return M.find() ~= -1
end

---@return integer
function M.width()
	local wid = M.find()
	if wid ~= -1 then
		return api.nvim_win_get_width(wid)
	end
	return config.current.window.width
end

---@param wid integer
local function apply_win_opts(wid)
	local wo = vim.wo[wid]
	wo.number = false
	wo.relativenumber = false
	wo.signcolumn = "no"
	wo.colorcolumn = "0"
	wo.wrap = false
	wo.winfixheight = true
end

---@return integer winid
function M.open()
	local existing = M.find()
	if existing ~= -1 then
		return existing
	end

	local bid = buf.get()
	if bid == -1 then
		return -1
	end

	local pos = config.current.window.position
	local h = config.current.window.height
	local w = config.current.window.width
	local wid

	if pos == "float" then
		local ui = api.nvim_list_uis()[1]
		local row = math.floor((ui.height - h) / 2)
		local col = math.floor((ui.width - w) / 2)
		wid = api.nvim_open_win(bid, false, {
			relative = "editor",
			row = row,
			col = col,
			width = w,
			height = h,
			style = "minimal",
			border = "rounded",
			title = " " .. config.current.window.name .. " ",
			title_pos = "center",
		})
	else
		local split_dir = ({
			bottom = "below",
			top = "above",
			left = "left",
			right = "right",
		})[pos] or "below"

		wid = api.nvim_open_win(bid, false, { split = split_dir, win = 0 })

		if pos == "bottom" or pos == "top" then
			api.nvim_win_set_height(wid, h)
		else
			api.nvim_win_set_width(wid, w)
		end
	end

	apply_win_opts(wid)
	return wid
end

function M.close()
	local wid = M.find()
	if wid ~= -1 then
		api.nvim_win_close(wid, true)
	end
end

function M.toggle()
	if M.is_open() then
		M.close()
	else
		M.open()
	end
end

return M

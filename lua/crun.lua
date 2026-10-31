---@class Crun
local M = {}

local config = require("config")
local history = require("history")
local runner = require("runner")
local win = require("win")

---@param opts table
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

---@param user_opts CrunOpts
function M.setup(user_opts)
  config.set(user_opts)

  local function on_cc()
    return vim.fn.getcmdtype() == ":" and vim.fn.getcmdline():match("^%s*Cc%s") ~= nil
  end

  vim.keymap.set("c", "<C-p>", function()
    if vim.fn.wildmenumode() == 1  or not on_cc() then
      return "<C-p>"
    end
    return "<Up>"
  end, { expr = true, desc = "Previous command" })
  vim.keymap.set("c", "<C-n>", function()
    if vim.fn.wildmenumode() == 1 or not on_cc() then
      return "<C-n>"
    end
    return "<Down>"
  end, { expr = true, desc = "Next command" })


  vim.api.nvim_create_user_command("Cc", M.run, {
    nargs = "*",
    bar = true,
    complete = "file",
  })

  vim.api.nvim_create_user_command("Ckill", M.kill, { bar = true })
  vim.api.nvim_create_user_command("Ctoggle", M.toggle, { bar = true })
end

return M

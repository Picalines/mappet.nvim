local new_set = MiniTest.new_set
local expect = MiniTest.expect

local keymap = require 'mappet'

local T = new_set()

T['buffer()'] = new_set()

T['buffer()']['fails on invalid buffer'] = function()
  expect.error(function()
    keymap.buffer('invalid-buffer', -1)
  end, 'buffer number not valid')
end

T['buffer()']['fails on unloaded buffer'] = function()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.cmd('silent! bunload ' .. buf)

  expect.error(function()
    keymap.buffer('unloaded-buffer', buf)
  end, 'buffer is not loaded')
end

return T

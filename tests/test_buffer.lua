local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local H = dofile(vim.fn.getcwd() .. '/tests/helpers.lua')
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

T['buffer()']['creates buffer-local mappings'] = function()
  local name = H.unique_name 'buffer-local'
  local lhs = '<Plug>(mappet-buffer-local)'
  local target_buf = vim.api.nvim_get_current_buf()
  local other_buf = vim.api.nvim_create_buf(true, false)

  keymap.buffer(name, target_buf) { 'n', silent = true } {
    keymap.map(lhs, 'buffer only') '<Nop>',
  }

  local target_map = H.get_buffer_map(target_buf, 'n', lhs)
  local other_map = H.get_buffer_map(other_buf, 'n', lhs)
  local global_map = H.get_global_map('n', lhs)

  eq(H.truthy(target_map), true)
  eq(H.truthy(other_map), false)
  eq(H.truthy(global_map), false)
  eq(target_map.desc, 'buffer only')
  eq(target_map.silent, 1)
end

return T

local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local H = dofile(vim.fn.getcwd() .. '/tests/helpers.lua')
local keymap = require 'mappet'

local T = new_set()

T['group()'] = new_set()

T['group()']['replaces existing mappings for the same group name'] = function()
  local name = H.unique_name 'group-replace'
  local lhs = '<Plug>(mappet-group-replace)'

  keymap.group(name) { 'n' } {
    keymap.map(lhs, 'first') '<Cmd>echo "first"<CR>',
  }

  eq(H.truthy(H.get_global_map('n', lhs)), true)

  keymap.group(name) { 'n' } {
    keymap.map(lhs, 'second') '<Cmd>echo "second"<CR>',
  }

  local mapped = H.get_global_map('n', lhs)
  eq(H.truthy(mapped), true)
  eq(mapped.desc, 'second')
  eq(H.count_global_maps('n', lhs), 1)
end

T['group()']['group opts are passed to vim.keymap.set'] = function()
  local name = H.unique_name 'sub-group-opts'
  local lhs = '<Plug>(mappet-sub-group-opts)'

  keymap.group(name) { 'n', remap = true, nowait = true, silent = true } {
    keymap.map(lhs, 'leaf') '<Nop>',
  }

  local mapped = H.get_global_map('n', lhs)

  eq(H.truthy(mapped), true)
  eq(mapped.silent, 1)
  eq(mapped.nowait, 1)
  eq(mapped.noremap, 0)
end

T['group()']['respects when=false and skips mapping declaration'] = function()
  local name = H.unique_name 'group-when'
  local lhs = '<Plug>(mappet-group-when)'

  keymap.group(name) { 'n', when = false } {
    keymap.map(lhs, 'skipped') '<Cmd>echo "skipped"<CR>',
  }

  eq(H.truthy(H.get_global_map('n', lhs)), false)
end

return T

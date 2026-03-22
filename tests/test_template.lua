local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local H = dofile(vim.fn.getcwd() .. '/tests/helpers.lua')
local keymap = require 'mappet'

local T = new_set()

T['template()'] = new_set()

T['template()']['applies compiled maps into a scope'] = function()
  local template = keymap.template()
  local lhs = '<Plug>(mappet-template-apply)'
  local bufnr = vim.api.nvim_get_current_buf()

  template { 'n', silent = true } {
    keymap.map(lhs, 'templated') '<Cmd>echo "templated"<CR>',
  }

  template:apply(keymap.buffer(H.unique_name 'template-buffer', bufnr))

  local map = H.get_buffer_map(bufnr, 'n', lhs)
  local global_map = H.get_global_map('n', lhs)

  eq(H.truthy(map), true)
  eq(H.truthy(global_map), false)
  eq(map.desc, 'templated')
  eq(map.silent, 1)
end

return T

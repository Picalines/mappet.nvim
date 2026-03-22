local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local H = dofile(vim.fn.getcwd() .. '/tests/helpers.lua')
local keymap = require 'mappet'

local T = new_set()

T['map() extracts rhs and opts from table action'] = function()
  local node = keymap.map('<Plug>(mappet-map)', 'map desc') {
    '<Cmd>echo "ok"<CR>',
    silent = true,
    expr = true,
  }

  eq(node.kind, 'map')
  eq(node.lhs, '<Plug>(mappet-map)')
  eq(node.rhs, '<Cmd>echo "ok"<CR>')
  eq(node.opts.desc, 'map desc')
  eq(node.opts.silent, true)
  eq(node.opts.expr, true)
  eq(node.opts[1], nil)
end

T['map() keeps explicit opts desc over desc argument'] = function()
  local node = keymap.map('<Plug>(mappet-map-desc)', 'from-arg') {
    '<Nop>',
    desc = 'from-opts',
    remap = true,
  }

  eq(node.opts.desc, 'from-opts')
  eq(node.opts.remap, true)
end

T['map() keeps parent description when map has no desc'] = function()
  local name = H.unique_name 'sub-desc-fallback'
  local lhs = '<Plug>(mappet-sub-desc-fallback)'

  keymap.group(name)('Parent %s', { 'n' }) {
    keymap.map(lhs) '<Nop>',
  }

  local mapped = H.get_global_map('n', lhs)

  eq(H.truthy(mapped), true)
  eq(mapped.desc, 'Parent %s')
end

T['map() supports syntax: map(lhs) rhs'] = function()
  local node = keymap.map '<Plug>(mappet-map-1)' '<Nop>'

  eq(node.rhs, '<Nop>')
end

T['map() supports syntax: map(lhs, desc) rhs'] = function()
  local node = keymap.map('<Plug>(mappet-map-2)', 'with-desc') '<Nop>'

  eq(node.opts.desc, 'with-desc')
end

T['map() supports syntax: map(lhs) { rhs, opts }'] = function()
  local node = keymap.map '<Plug>(mappet-map-3)' { '<Nop>', silent = true }

  eq(node.opts.silent, true)
end

T['map() supports function rhs'] = function()
  local rhs = function() end
  local node = keymap.map('<Plug>(mappet-map-fn)', 'with-fn') {
    rhs,
    silent = true,
  }

  eq(type(node.rhs), 'function')
  eq(node.rhs, rhs)
  eq(node.opts.desc, 'with-fn')
  eq(node.opts.silent, true)
end

return T

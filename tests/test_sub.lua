local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local H = dofile(vim.fn.getcwd() .. '/tests/helpers.lua')
local keymap = require 'mappet'

local T = new_set()

T['sub()'] = new_set()

T['sub()']['merges parent and nested modes'] = function()
  local name = H.unique_name 'sub-modes'
  local lhs = '<Plug>(mappet-sub-modes)'

  keymap.group(name) { 'n' } {
    keymap.sub { 'x' } {
      keymap.map(lhs, 'leaf') '<Nop>',
    },
  }

  local n_map = H.get_global_map('n', lhs)
  local x_map = H.get_global_map('x', lhs)

  eq(H.truthy(n_map), true)
  eq(H.truthy(x_map), true)
end

T['sub()']['merges opts from parent and nested specs'] = function()
  local name = H.unique_name 'sub-opts'
  local lhs = '<Plug>(mappet-sub-opts)'

  keymap.group(name) { 'n', silent = true } {
    keymap.sub { expr = true } {
      keymap.map(lhs, 'leaf') "v:count == 0 ? 'gj' : 'j'",
    },
  }

  local mapped = H.get_global_map('n', lhs)

  eq(H.truthy(mapped), true)
  eq(mapped.expr, 1)
  eq(mapped.silent, 1)
end

T['sub()']['formats descriptions through nested templates'] = function()
  local name = H.unique_name 'sub-desc'
  local lhs = '<Plug>(mappet-sub-desc)'

  keymap.group(name)('Root %s', { 'n' }) {
    keymap.sub 'Inner %s' {
      keymap.map(lhs, 'Leaf') '<Nop>',
    },
  }

  local mapped = H.get_global_map('n', lhs)

  eq(H.truthy(mapped), true)
  eq(mapped.desc, 'Root Inner Leaf')
end

T['sub()']['keeps nested description when parent has no desc'] = function()
  local name = H.unique_name 'sub-desc-child-only'
  local lhs = '<Plug>(mappet-sub-desc-child-only)'

  keymap.group(name) { 'n' } {
    keymap.sub 'Child %s' {
      keymap.map(lhs, 'Leaf') '<Nop>',
    },
  }

  local mapped = H.get_global_map('n', lhs)

  eq(H.truthy(mapped), true)
  eq(mapped.desc, 'Child Leaf')
end

T['sub()']['errors on parent description with too many placeholders'] = function()
  local name = H.unique_name 'sub-desc-first-placeholder'
  local lhs = '<Plug>(mappet-sub-desc-first-placeholder)'

  expect.error(function()
    keymap.group(name)('Parent %s %s', { 'n' }) {
      keymap.map(lhs, 'Leaf') '<Nop>',
    }
  end, 'merge_desc')
end

T['sub()']['errors on child description with too many placeholders'] = function()
  local name = H.unique_name 'sub-desc-child-first-placeholder'
  local lhs = '<Plug>(mappet-sub-desc-child-first-placeholder)'

  expect.error(function()
    keymap.group(name)('Root %s', { 'n' }) {
      keymap.sub 'Inner %s %s' {
        keymap.map(lhs, 'Leaf') '<Nop>',
      },
    }
  end, 'merge_desc')
end

T['sub()']['supports map syntax: map(lhs) rhs'] = function()
  local name = H.unique_name 'sub-map-syntax-1'
  local lhs = '<Plug>(mappet-sub-map-syntax-1)'

  keymap.group(name) { 'n' } {
    keymap.map(lhs) '<Nop>',
  }

  local mapped = H.get_global_map('n', lhs)

  eq(H.truthy(mapped), true)
end

T['sub()']['supports map syntax: map(lhs, desc) rhs'] = function()
  local name = H.unique_name 'sub-map-syntax-2'
  local lhs = '<Plug>(mappet-sub-map-syntax-2)'

  keymap.group(name) { 'n' } {
    keymap.map(lhs, 'desc') '<Nop>',
  }

  local mapped = H.get_global_map('n', lhs)

  eq(H.truthy(mapped), true)
  eq(mapped.desc, 'desc')
end

T['sub()']['supports map syntax: map(lhs) { rhs, opts }'] = function()
  local name = H.unique_name 'sub-map-syntax-3'
  local lhs = '<Plug>(mappet-sub-map-syntax-3)'

  keymap.group(name) { 'n' } {
    keymap.map(lhs) { '<Nop>', silent = true },
  }

  local mapped = H.get_global_map('n', lhs)

  eq(H.truthy(mapped), true)
  eq(mapped.silent, 1)
end

return T

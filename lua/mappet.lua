local M = {}

---@toc mappet.contents
---@mod mappet.examples Basic Examples

---@brief [[
---Declarative keymap DSL with grouping, nesting and templates.
---
---Quick examples:
--->lua
---  local keymap = require 'mappet'
---  local map, sub = keymap.map, keymap.sub
---
---  local keys = keymap.group 'unique-group-name'
---
---  keys 'Buffer: %s' {
---    map(']b', 'next') '<Cmd>bn<CR>',
---    map('[b', 'previous') '<Cmd>bp<CR>',
---    map('<LocalLeader>w', 'write') '<Cmd>silent w<CR>',
---    map('<Leader>w', 'write all') '<Cmd>silent wa!<CR>',
---  }
---
---  keys('Buffer: %s', { 'x' }) {
---    map('<LocalLeader>s', 'substitute') ':s///g',
---    map('<LocalLeader>gn', 'g norm') ':g//norm ',
---  }
---
---  keys { 'n', 'x' } {
---    map 'n' 'nzzzv',
---    map 'N' 'Nzzzv',
---    sub { expr = true } {
---      map 'k' "v:count == 0 ? 'gk' : 'k'",
---      map 'j' "v:count == 0 ? 'gj' : 'j'",
---    },
---  }
---<
---@brief ]]

---Mode accepted by |vim.keymap.set|.
---@alias MappetMode 'n'|'v'|'x'|'s'|'o'|'i'|'l'|'c'|'t'|'!'

---Right-hand side accepted by |vim.keymap.set|.
---@alias MappetRhs string|fun()

---Table form accepted by `map(lhs) { ... }`.
---The first indexed item is the rhs, the remaining keys are
---forwarded to |vim.keymap.set| options.
---The `buffer` option is not supported here, use `keymap.buffer(...)` instead.
---@class MappetRhsTable: vim.keymap.set.Opts
---@field [1] MappetRhs

---Scope options merged into nested mappings.
---
---Examples:
--->lua
---  keys { 'n', 'x', silent = true } {
---    -- ^ This table is called 'spec'.
---    -- Indexed items are modes.
---    -- Almost all key/values are vim.keymap.set options.
---  }
---
---  keys { when = vim.fn.has('win32') == 1 } {
---    -- Include mappings conditionally, e.g. only on Windows.
---  }
---
---  keys { 'n' } {
---    sub { 'x' } {
---      -- Mappings here will be in BOTH normal and visual modes.
---    },
---  }
---<
---
---@class MappetSpec: vim.keymap.set.Opts
---@field [integer] MappetMode
---@field when? boolean Apply declaration only when true.
---@field desc? string Group description template. Nested scopes use |string.format|

---@private
---@class MappetEntry
---@field mode MappetMode
---@field lhs string
---@field bufnr integer|nil

---@private
---@class MappetMapNode
---@field kind 'map'
---@field lhs string
---@field rhs MappetRhs
---@field opts vim.keymap.set.Opts

---@private
---@class MappetSubNode
---@field kind 'sub'
---@field spec MappetSpec
---@field items MappetDecl

---@private
---@alias MappetNode MappetMapNode|MappetSubNode
---@alias MappetDecl MappetNode[]

---@private
---@class MappetMap
---@field mode MappetMode
---@field lhs string
---@field rhs MappetRhs
---@field opts vim.keymap.set.Opts

---@type table<string, table<string, MappetEntry>>
local global_entries = {}
local buffer_var_prefix = '__keymaps_'

---@param spec MappetSpec
---@return MappetMode[], vim.keymap.set.Opts, string|nil, boolean
local function parse_spec(spec)
  ---@type MappetMode[]
  local modes = {}
  ---@type vim.keymap.set.Opts
  local opts = {}
  local group_desc = nil
  local should_skip = false

  for s_key, s_value in pairs(spec) do
    if type(s_key) == 'number' then
      modes[#modes + 1] = s_value
    elseif s_key == 'when' then
      should_skip = s_value == false
    elseif s_key == 'desc' then
      group_desc = s_value
    elseif s_key == 'buffer' then
      vim.notify(
        'use keymap.buffer to make buffer-local mappings. Parameter is skipped',
        vim.log.levels.WARN
      )
    else
      opts[s_key] = s_value
    end
  end

  return modes, opts, group_desc, should_skip
end

---@param spec_or_desc MappetSpec|string
---@param maybe_spec? MappetSpec
---@param ctx string
---@return MappetSpec
local function normalize_scope_spec(spec_or_desc, maybe_spec, ctx)
  if type(spec_or_desc) == 'table' and maybe_spec == nil then
    return spec_or_desc
  end

  if type(spec_or_desc) == 'string' then
    return vim.tbl_extend('force', { desc = spec_or_desc }, maybe_spec or {})
  end

  error(
    string.format(
      'keymap %s: first argument must be spec table or desc string',
      ctx
    )
  )
end

---@param parent_desc string|nil
---@param child_desc string|nil
---@return string|nil
local function merge_desc(parent_desc, child_desc)
  if parent_desc and child_desc then
    return string.format(parent_desc, child_desc)
  end

  return child_desc or parent_desc
end

---@private
---@class _MappetContext
---@field modes MappetMode[]
---@field opts vim.keymap.set.Opts
---@field group_desc string|false|nil

---@param maps MappetMap[]
---@param node MappetMapNode
---@param context _MappetContext
local function compile_map(maps, node, context)
  local opts = vim.tbl_deep_extend('force', context.opts, node.opts)
  opts.desc = merge_desc(context.group_desc, opts.desc)

  local modes = #context.modes > 0 and context.modes or { 'n' }

  for _, mode in ipairs(modes) do
    maps[#maps + 1] = {
      mode = mode,
      lhs = node.lhs,
      rhs = node.rhs,
      opts = opts,
    }
  end
end

---@param maps MappetMap[]
---@param decl MappetDecl
---@param context _MappetContext
local function compile_decl(maps, decl, context)
  for _, node in ipairs(decl) do
    if node.kind == 'map' then
      compile_map(maps, node, context)
    elseif node.kind == 'sub' then
      local sub_modes, sub_opts, sub_desc, should_skip = parse_spec(node.spec)
      if not should_skip then
        local modes = vim.deepcopy(context.modes)
        vim.list_extend(modes, sub_modes)
        compile_decl(maps, node.items, {
          modes = modes,
          opts = vim.tbl_deep_extend('force', context.opts, sub_opts),
          group_desc = merge_desc(context.group_desc, sub_desc),
        })
      end
    else
      vim.notify(
        ---@diagnostic disable-next-line: undefined-field
        string.format('keymap: node `%s` is not implemented', node.kind),
        vim.log.levels.WARN
      )
    end
  end
end

---@param mode MappetMode
---@param lhs string
---@param bufnr integer|nil
---@return string
local function entry_id(mode, lhs, bufnr)
  return table.concat({ mode, lhs, tostring(bufnr or '_') }, '\0')
end

---@param entry MappetEntry
local function delete_entry(entry)
  local buffer = entry.bufnr
  if
    buffer == nil
    or (
      vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_is_loaded(buffer)
    )
  then
    pcall(vim.keymap.del, entry.mode, entry.lhs, { buffer = buffer })
  end
end

---@param entries table<string, MappetEntry>
---@param maps MappetMap[]
---@param bufnr integer|nil
local function apply_maps(entries, maps, bufnr)
  for _, m in ipairs(maps) do
    local id = entry_id(m.mode, m.lhs, bufnr)
    if entries[id] ~= nil then
      delete_entry(entries[id])
    end

    local opts = vim.deepcopy(m.opts)
    if bufnr ~= nil then
      opts.buf = bufnr
    end

    local ok = pcall(vim.keymap.set, m.mode, m.lhs, m.rhs, opts)
    if ok then
      entries[id] = {
        mode = m.mode,
        lhs = m.lhs,
        bufnr = bufnr,
      }
    else
      vim.notify(
        string.format('keymap: failed to map `%s` in mode `%s`', m.lhs, m.mode),
        vim.log.levels.ERROR
      )
    end
  end
end

---Callable scope returned by `group` and `buffer`.
---@class MappetScope
---@field private __entries table<string, MappetEntry>
---@field private __bufnr integer|nil
---@field package __add_maps fun(self: MappetScope, maps: MappetMap[]): MappetScope
---@overload fun(spec: MappetSpec): fun(decl: MappetDecl): MappetScope
---@overload fun(desc: string): fun(decl: MappetDecl): MappetScope
---@overload fun(desc: string, spec: MappetSpec): fun(decl: MappetDecl): MappetScope
local Scope = {}

Scope.__index = Scope

function Scope:__add_maps(maps)
  apply_maps(self.__entries, maps, self.__bufnr)
  return self
end

function Scope:__call(spec_or_desc, maybe_spec)
  local spec = normalize_scope_spec(spec_or_desc, maybe_spec, 'scope call')

  return function(decl)
    local spec_modes, spec_opts, group_desc, should_skip = parse_spec(spec)
    if should_skip then
      return self
    end

    ---@type MappetMap[]
    local compiled_maps = {}

    compile_decl(compiled_maps, decl, {
      modes = spec_modes,
      opts = spec_opts,
      group_desc = group_desc,
    })

    return self:__add_maps(compiled_maps)
  end
end

---@param entries table<string, MappetEntry>
---@param bufnr integer|nil
---@return MappetScope
local function make_scope(entries, bufnr)
  ---@diagnostic disable-next-line: param-type-mismatch
  return setmetatable({ __entries = entries, __bufnr = bufnr }, Scope)
end

---@mod mappet.scopes Scopes

---@mod mappet.scopes.group Group

---Create or replace a global keymap group.
---
---Calling `group` with an existing name clears mappings created by that group
---first, then applies the new declaration (similar to clearing an |augroup|).
---
---@param name string
---@return MappetScope
---@usage [[
---local keymap = require 'mappet'
---local map = keymap.map
---
---local keys = keymap.group 'group-name'
---
---keys { 'n', silent = true } {
---  map('<Leader>qq', 'Quit') '<Cmd>wqa<CR>',
---}
---@usage ]]
function M.group(name)
  local previous_entries = global_entries[name]
  if previous_entries ~= nil then
    for _, entry in pairs(previous_entries) do
      delete_entry(entry)
    end
  end

  ---@type table<string, MappetEntry>
  local entries = {}
  global_entries[name] = entries

  return make_scope(entries, nil)
end

---@mod mappet.scopes.buffer Buffer

---Create or replace a buffer-local keymap group.
---
---Like `group`, reusing the same name clears previous entries for that
---group, but only in buffer `123`.
---
---For autocommand callbacks, prefer `keymap.template()`
---to keep setup flat and reusable.
---
---@param name string
---@param bufnr integer
---@return MappetScope
---@usage [[
---local keymap = require 'mappet'
---local map = keymap.map
---
----- Assuming buffer 123 is valid and loaded:
---local keys = keymap.buffer('group-name', 123)
---
---keys { 'n' } {
---  -- ...
---}
---@usage ]]
function M.buffer(name, bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    error 'keymap.buffer: buffer number not valid'
  end

  if not vim.api.nvim_buf_is_loaded(bufnr) then
    error 'keymap.buffer: buffer is not loaded'
  end

  local buffer_var_name = buffer_var_prefix .. name

  ---@type table<string, MappetEntry>|nil
  local previous_entries = vim.b[bufnr][buffer_var_name]
  if previous_entries ~= nil then
    for _, entry in pairs(previous_entries) do
      delete_entry(entry)
    end
  end

  ---@type table<string, MappetEntry>
  local entries = {}
  vim.b[bufnr][buffer_var_name] = entries

  return make_scope(entries, bufnr)
end

---@mod mappet.scopes.template Template

---Reusable declaration template that can be applied to scopes.
---@class MappetTemplate
---@field private __maps MappetMap[]
---@field apply fun(self: MappetTemplate, scope: MappetScope): MappetTemplate
---@overload fun(spec: MappetSpec): fun(decl: MappetDecl): MappetTemplate
---@overload fun(desc: string): fun(decl: MappetDecl): MappetTemplate
---@overload fun(desc: string, spec: MappetSpec): fun(decl: MappetDecl): MappetTemplate
local Template = {}

Template.__index = Template

function Template:__call(spec_or_desc, maybe_spec)
  local spec = normalize_scope_spec(spec_or_desc, maybe_spec, 'template call')

  return function(decl)
    local spec_modes, spec_opts, group_desc, should_skip = parse_spec(spec)
    if should_skip then
      return self
    end

    ---@type MappetMap[]
    local compiled_maps = {}

    compile_decl(compiled_maps, decl, {
      modes = spec_modes,
      opts = spec_opts,
      group_desc = group_desc,
    })

    vim.list_extend(self.__maps, compiled_maps)
    return self
  end
end

function Template:apply(scope)
  scope:__add_maps(self.__maps)
  return self
end

---Create a reusable mapping template.
---
---Useful for buffer-local autocommands to avoid lots of indentation.
---@return MappetTemplate
---@usage [[
---local keymap = require 'mappet'
---local map = keymap.map
---
---local qf_keys = keymap.template()
---
---qf_keys('Quickfix: %s' ) {
---  map('q', 'close') '<Cmd>cclose<CR>',
---  -- ...
---}
---
---vim.api.nvim_create_autocmd('FileType', {
---  pattern = 'qf',
---  callback = function(event)
---    -- Create a buffer scope, then merge template into it
---    qf_keys:apply(keymap.buffer('quickfix', event.buf))
---  end,
---})
---@usage ]]
function M.template()
  ---@diagnostic disable-next-line: param-type-mismatch
  return setmetatable({ __maps = {} }, Template)
end

---@mod mappet.nodes Nodes

---@mod mappet.nodes.map Map

---Mapping node constructor.
---@param lhs string
---@param desc? string
---@usage [[
---local keymap = require 'mappet'
---local map = keymap.map
---local keys = keymap.group 'group-name'
---
---keys { 'n' } {
---  -- Simple lhs to rhs:
---  map '<Leader>e' '<Cmd>Oil<CR>'
---
---  -- Add description:
---  map('<Leader>e', 'Explorer') '<Cmd>Oil<CR>'
---
---  -- Braces to indent long command:
---  map('y<C-g>', 'yank buffer path') {
---    '<Cmd>eval setreg(v:register, @%) | echo @%',
---  },
---
---  -- Braces for functions:
---  map('gx', 'system open') {
---    silent = true,  -- `vim.keymap.set` options are supported
---    noremap = true, -- (except buffer)
---    function()
---      vim.ui.open(MiniFiles.get_fs_entry().path)
---    end,
---  },
---}
---@usage ]]
function M.map(lhs, desc)
  ---@param action MappetRhs|MappetRhsTable
  ---@return MappetMapNode
  return function(action)
    ---@type vim.keymap.set.Opts
    local opts = {}

    ---@type MappetRhs
    local rhs
    if type(action) == 'table' then
      rhs = action[1]
      opts = vim.deepcopy(action)
      opts[1] = nil
    else
      ---@cast action MappetRhs
      rhs = action
    end

    opts.desc = opts.desc or desc

    return {
      kind = 'map',
      lhs = lhs,
      rhs = rhs,
      opts = opts,
    }
  end
end

---@mod mappet.nodes.sub Sub

---Nest a declaration subtree with extra scope options.
---@param spec_or_desc MappetSpec|string
---@param maybe_spec? MappetSpec
---@return fun(items: MappetDecl): MappetSubNode
---@usage [[
---local keymap = require 'mappet'
---local map, sub = keymap.map, keymap.sub
---local keys = keymap.group 'window'
---
---keys('Window: %s', { 'n' }) {
---  sub 'go %s' {
---    map('<C-j>', 'down') '<C-w>j',
---    map('<C-k>', 'up') '<C-w>k',
---    map('<C-h>', 'left') '<C-w>h',
---    map('<C-l>', 'right') '<C-w>l',
---  },
---
---  sub { expr = true } {
---    -- ...
---  },
---
---  sub 'Description: %s' { expr = true } {
---    -- ...
---  },
---},
---@usage ]]
function M.sub(spec_or_desc, maybe_spec)
  local spec = normalize_scope_spec(spec_or_desc, maybe_spec, 'sub call')

  ---@param items MappetDecl
  ---@return MappetSubNode
  return function(items)
    return {
      kind = 'sub',
      spec = spec,
      items = items,
    }
  end
end

return M

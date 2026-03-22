# mappet.nvim

Declarative keymap DSL for Neovim

- Group mappings into logic blocks
- Format their descriptions for plugins like [mini.clue](https://github.com/nvim-mini/mini.clue) or [which-key](https://github.com/folke/which-key.nvim)
- Compose nested declarations with `sub { ... }`, reuse [`vim.keymap.set()`](https://neovim.io/doc/user/lua/#vim.keymap.set()) options
- Easier syntax for buffer autocommands with `template()`

Full docs: [`doc/mappet.txt`](doc/mappet.txt) (`:help mappet`).

## Install

<details>
<summary>With <code>vim.pack</code></summary>

```lua
-- Experimental built-in, https://neovim.io/doc/user/pack/#vim.pack.add()
vim.pack.add({ 'https://github.com/Picalines/mappet.nvim' })
```
</details>

<details>
<summary>With <code>lazy.nvim</code></summary>

```lua
{ 'Picalines/mappet.nvim' }
```
</details>

## Quick Examples

```lua
local keymap = require 'mappet'
local map, sub = keymap.map, keymap.sub

-- Name groups like autocommands, so :source will clear previously defined mappings
local keys = keymap.group 'some-global-name'

-- Define mappings for multiple modes at once
keys { 'n', 'x' } {
  map '<C-u>' '<C-u>zz',
  map '<C-d>' '<C-d>zz',
  sub { expr = true } {
    map 'k' "v:count == 0 ? 'gk' : 'k'",
    map 'j' "v:count == 0 ? 'gj' : 'j'",
  },
},

-- Use functions instead of key sequences
keys { 'n' } {
  map('gx', 'open url under cursor') {
    silent = true,
    function()
      vim.ui.open(vim.fn.expand '<cfile>')
    end,
  },
}

-- Describe groups of mappings with string.format
keys 'Buffer: %s' {
  map(']b', 'next') '<Cmd>bn<CR>',
  map('[b', 'previous') '<Cmd>bp<CR>',
  map('<LocalLeader>w', 'write') '<Cmd>silent w<CR>',
  map('<Leader>w', 'write all') '<Cmd>silent wa!<CR>',
}

-- Descriptions merge from top to bottom
keys('Window: %s', { 'n' }) {
  sub 'go %s' {
    map('<C-j>', 'down') '<C-w>j',
    map('<C-k>', 'up') '<C-w>k',
    map('<C-h>', 'left') '<C-w>h',
    map('<C-l>', 'right') '<C-w>l',
  },
}

-- Use templates to reduce nesting in autocommands
local qf_keys = keymap.template()

qf_keys 'Quickfix: %s' {
  map('<Leader>q', 'close') '<Cmd>cclose<CR>',
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  callback = function(event)
    -- Copy mappings from template to the quickfix buffer
    qf_keys:apply(keymap.buffer('quickfix', event.buf))
  end,
})
```

For all options, modes, and API details, see [`doc/mappet.txt`](doc/mappet.txt).

## Why?

I find the standard Neovim APIs hard to type out and experiment with. I started with [this keymap function](https://github.com/Picalines/dotfiles/blob/1a773605fb5366600391666f33e796f9a2a65cd7/nvim/lua/util/keymap.lua) ([usage example](https://github.com/Picalines/dotfiles/blob/c5cf81f9830f10d49292d086debd5e85d5b7c7a0/nvim/lua/settings/global.lua#L62)) in my dotfiles, but it wasn't type-checked and made autocommands too nested

Pure overengineering... just like everything I do :)

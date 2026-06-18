<div align="center">
  <h1>Fyler.nvim</h1>
  <table>
    <tr>
      <td>
        <strong>A file manager for <a href="https://neovim.io">Neovim</a></strong>
      </td>
    </tr>
  </table>
  <div>
    <img
      alt="License"
      src="https://img.shields.io/github/license/FylerOrg/fyler.nvim?style=for-the-badge&logo=starship&color=ee999f&logoColor=D9E0EE&labelColor=302D41"
    />
  </div>
</div>
<img alt="Image" src="https://github.com/user-attachments/assets/aecb2d68-bf7b-46f1-9f4a-679b4aed0b52" />

## Introduction

Fyler.nvim is oil.nvim inspired file manager plugin for neovim which can
manipulate file system like a neovim buffer and provide a proper file-tree
representation of items.

## Requirements

- Neovim >= 0.11

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ 'FylerOrg/fyler.nvim', opts = {} }
```

### [mini.deps](https://github.com/nvim-mini/mini.deps)

```lua
require('mini.deps').add('FylerOrg/fyler.nvim')
require('fyler').setup({})
```

### [vim.pack](https://neovim.io/doc/user/pack)

```lua
vim.pack.add({ 'https://github.com/FylerOrg/fyler.nvim' })
```

## Setup

```lua
local fyler = require('fyler')

fyler.setup({
  -- Whether to skip confirmation for "simple" mutations.
  -- A simple mutation has at most:
  -- - 1 copy operation
  -- - 1 delete operation
  -- - 1 move operation
  -- - 5 create operations
  auto_confirm_simple_mutation = false,
  -- Restricts cursor from moving outside editable region
  bound_cursor = true,
  -- Follow current file
  follow_current_file = true,
  -- Extensions
  extensions = {},
  -- Event hooks
  hooks = {},
  integrations = {},
  -- Buffer kind to use globally.
  kind = 'replace',
  -- Per-kind buffer configuration.
  kind_presets = {
    floating = {
      -- Border style (see: :h winborder)
      border = 'single',
      -- Size of buffer:
      -- - string with '%' for relative (e.g. '70%')
      -- - number for absolute
      height = '80%',
      mappings = { n = { ['<CR>'] = { action = 'select', args = { close = true } } } },
      width = '60%',
      -- Horizontal alignment: 'start' | 'center' | 'end'
      col = 'center',
      -- Vertical alignment: 'start' | 'center' | 'end'
      row = 'center',
    },
    replace = {
      mappings = { n = { ['<CR>'] = { action = 'select', args = { close = true } } } },
    },
    split_above = { height = '50%' },
    split_above_all = { height = '50%' },
    split_below = { height = '50%' },
    split_below_all = { height = '50%' },
    split_left = { width = '25%' },
    split_left_most = { width = '25%' },
    split_right = { width = '25%' },
    split_right_most = { width = '25%' },
  },
  mappings = {
    n = {
      ['-'] = { action = 'visit', args = { parent = true } },
      ['.'] = { action = 'visit', args = { cursor = true } },
      ['<BS>'] = { action = 'shrink', args = { parent = true } },
      ['<C-R>'] = { action = 'refresh' },
      ['<C-S>'] = { action = 'select', args = { split = true } },
      ['<C-T>'] = { action = 'select', args = { tabedit = true } },
      ['<C-V>'] = { action = 'select', args = { vsplit = true } },
      ['<CR>'] = { action = 'select' },
      ['='] = { action = 'visit' },
      ['g.'] = { action = 'toggle_ui', args = { 'hidden_items' } },
      ['gi'] = { action = 'toggle_ui', args = { 'indent_guides' } },
      ['q'] = { action = 'close' },
    },
  },
  -- UI options
  ui = {
    -- Whether to draw indent guides at each depth level.
    hidden_items = {
      -- Toggleable pre-defined switches (e.g. 'dotfiles' to hide files starting with a dot).
      switches = { 'dotfiles' },
      -- Toggleable patterns (Lua patterns matched against the full path).
      patterns = {},
      -- Always visible items matching these patterns, even if they would normally be hidden.
      always_visible = {},
      -- Always hide items matching these patterns, even if they would normally be visible.
      always_hidden = {},
    },
    indent_guides = false,
  },
})
```

## Usage

Open Fyler using the `:Fyler` command:

```vim
:Fyler                    " Open the finder
:Fyler root_path=<path>   " Use a different directory path
:Fyler kind=<buffer_kind> " Open specified kind directly
```

Open Fyler from Lua:

```lua
local fyler = require('fyler')

-- open using defaults
fyler.open()

-- open as a left most split
fyler.open({ kind = "split_left_most" })

-- open with different directory
fyler.open({ root_path = "~" })

-- You can map this to a key
vim.keymap.set("n", "<leader>e", fyler.open, { desc = "Fyler.nvim - Open" })

-- Wrap in a function to pass additional arguments
vim.keymap.set(
    "n",
    "<leader>e",
    function() fyler.open({ kind = "split_left_most" }) end,
    { desc = "Fyler.nvim - Open" }
)
```

## License

Apache 2.0. See [LICENSE](LICENSE).

> [!NOTE]
> Run `:help fyler.nvim` OR visit [wiki pages](https://github.com/FylerOrg/fyler.nvim/wiki) for more detailed explanation and live showcase.

### Credits

- [**GrugFar**](https://github.com/MagicDuck/grug-far.nvim)
- [**Mini.files**](https://github.com/nvim-mini/mini.files)
- [**Neo-tree**](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [**Neogit**](https://github.com/NeogitOrg/neogit)
- [**Nvim-window-picker**](https://github.com/s1n7ax/nvim-window-picker)
- [**Oil**](https://github.com/stevearc/oil.nvim)
- [**Snacks**](https://github.com/folke/snacks.nvim)
- [**Telescope**](https://github.com/nvim-telescope/telescope.nvim)

---

<h4 align="center">Built with ❤️ for the Neovim community</h4>
<a href="https://github.com/FylerOrg/fyler.nvim/graphs/contributors">
  <img
    src="https://contrib.rocks/image?repo=FylerOrg/fyler.nvim&max=750&columns=20"
    alt="contributors"
  />
</a>

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

## INTRODUCTION

Fyler.nvim is oil.nvim inspired file manager plugin for neovim which can
manipulate file system like a neovim buffer and provide a proper file-tree
representation of items.

## REQUIREMENTS

- Neovim >= 0.11

## INSTALLATION

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ 'FylerOrg/fyler.nvim', opts = {} }
```

### [mini.deps](https://github.com/nvim-mini/mini.deps)

```lua
require('mini.deps').add('FylerOrg/fyler.nvim')
```

### [vim.pack](https://neovim.io/doc/user/pack)

```lua
vim.pack.add({ 'https://github.com/FylerOrg/fyler.nvim' })
```

## USAGE

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

## LICENSE

Apache 2.0. See [LICENSE](LICENSE).

> [!NOTE]
> Run `:help fyler.nvim` OR visit [wiki pages](https://github.com/FylerOrg/fyler.nvim/wiki) for more detailed explanation and live showcase.

### CREDITS

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

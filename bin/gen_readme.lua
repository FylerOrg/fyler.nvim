local FORMATTING = {
  heading_base = 2,
  strip_modeline = true,
  strip_separators = true,
  convert_links = true,
  indentation = 2,
}

---@param lines string[]
---@return table[]
local function parse_vimdoc(lines)
  local sections = {}
  local current = { lines = {} }

  for _, line in ipairs(lines) do
    if line:match('^%-%-%-%-') then
      if current and current.tag then table.insert(sections, current) end
      current = { lines = {} }
    elseif current then
      table.insert(current.lines, line)
      if not current.tag then
        local tag = line:match('^%s*%*([%w%.%-_]+)%*%s*$')
        if tag then current.tag = tag end
      end
      if not current.title then
        local title = line:match('^(.+)%~$')
        if title and #vim.trim(title) > 0 then current.title = vim.trim(title) end
      end
    end
  end

  if current and current.tag then table.insert(sections, current) end

  return sections
end

---@param section { tag: string, title: string|nil, lines: string[] }
---@return string
local function render_section(section)
  local result = {}
  local in_code = false
  local escaped_tag = vim.pesc(section.tag)
  local tag_pattern = '^%s*%*' .. escaped_tag .. '%*%s*$'

  for _, line in ipairs(section.lines) do
    if line:match(tag_pattern) then
    elseif FORMATTING.strip_separators and line:match('^%-%-%-%-') then
    elseif in_code and line:match('^<%s*$') then
      table.insert(result, '```')
      in_code = false
    elseif not in_code and line:match('^>(%w*)%s*$') then
      local lang = line:match('^>(%w*)%s*$')
      table.insert(result, '```' .. lang)
      in_code = true
    elseif in_code then
      table.insert(result, line:sub(FORMATTING.indentation + 1))
    elseif FORMATTING.strip_modeline and line:match('^%s*vim:') then
    elseif line:match('^(.+)%~$') then
      local title = vim.trim(line:match('^(.+)%~$'))
      if #title > 0 then table.insert(result, string.rep('#', FORMATTING.heading_base) .. ' ' .. title) end
    else
      local text = line
      if FORMATTING.convert_links then text = text:gsub('|([^|]+)|', '%1') end
      text = text.gsub(text, '%s+$', '')
      table.insert(result, text)
    end
  end

  return table.concat(result, '\n')
end

local sections = parse_vimdoc(vim.fn.readfile('doc/fyler.txt'))

local function render(key)
  local tag = 'fyler.' .. key
  for _, s in ipairs(sections) do
    if s.tag == tag then return render_section(s) end
  end
  return ''
end

local template = [[
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

{{introduction}}
{{requirements}}
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

{{usage}}
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
</a>]]

local content = template:gsub('{{(%w+)}}', render)

vim.fn.writefile(vim.split(content, '\n'), 'README.md')
print('README.md has been generated successfully')

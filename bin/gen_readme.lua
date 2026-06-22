local path_doc = vim.fs.normalize(('%s/doc/fyler.txt'):format(vim.fn.getcwd()))
local path_readme = vim.fs.normalize(('%s/README.md'):format(vim.fn.getcwd()))

local lines = vim.fn.readfile(path_doc)

local section_headers = {
  introduction = 'INTRODUCTION',
  requirements = 'REQUIREMENTS',
  usage = 'USAGE',
  setup = 'SETUP',
}

local function parse_sections(lines)
  local sections = {}
  local tag, current, in_code

  for _, line in ipairs(lines) do
    if line:match('^%-%-%-%-') then
      if tag and current then sections[tag] = current end
      tag, current, in_code = nil, nil, nil
    else
      local found = line:match('%*fyler%.([%w-]+)%*')
      if found and not tag then
        tag = found
        current = { fragments = {} }
      elseif current then
        local lang = line:match('^>(%w+)$')
        if lang then
          in_code = { lang = lang, lines = {} }
          table.insert(current.fragments, in_code)
        elseif line == '<' then
          in_code = nil
        elseif in_code then
          table.insert(in_code.lines, line)
        else
          table.insert(current.fragments, { text = line })
        end
      end
    end
  end

  if tag and current then sections[tag] = current end
  return sections
end

local function render_section(sections, tag)
  local section = sections[tag]
  if not section then return '' end

  local result = {}

  for _, frag in ipairs(section.fragments) do
    if frag.lines then
      table.insert(result, '```' .. frag.lang)
      for _, cline in ipairs(frag.lines) do
        table.insert(result, cline:sub(3))
      end
      table.insert(result, '```')
    else
      local line = frag.text:gsub('%s+$', ''):gsub('^ vim:.*$', '')
      if #line == 0 then
        table.insert(result, '')
      else
        local raw = line:gsub('~$', ''):gsub('%s+$', '')
        if line:match('^%u[%u%l ]+%~$') then
          if raw == section_headers[tag] then
            local title = raw:gsub('%a+', function(w) return w:sub(1, 1) .. w:sub(2):lower() end)
            table.insert(result, '## ' .. title)
          else
            table.insert(result, '**' .. raw .. '**')
          end
        else
          line = line:gsub('|([^|]+)|', function(link) return link:match('^https?://') and link or link end)
          table.insert(result, line)
        end
      end
    end
  end

  return table.concat(result, '\n')
end

local sections = parse_sections(lines)

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
## Installation

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

{{setup}}
{{usage}}
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
</a>]]

local content = template:gsub('{{(%w+)}}', function(key) return render_section(sections, key) end)

vim.fn.writefile(vim.split(content, '\n'), path_readme)
print('README.md has been generated successfully')

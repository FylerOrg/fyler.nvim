local config = Fyler.import('fyler.config')

local M = {}
local H = {}

---@param fs_type string
---@param fs_path string
---@param state { expanded: boolean }|nil
---@return string, string|nil
H.mini_icons = function(fs_type, fs_path, state)
  local mini_icons = Fyler.import('mini.icons')
  assert(mini_icons.is_found, 'mini.icons not found')

  local st = { default = true, directory = true, extension = true, file = true, filetype = true, lsp = true, os = true }
  local category = st[fs_type] and fs_type or 'file'
  local icon, hl = mini_icons.get(category, fs_path)
  if fs_type == 'directory' then
    if state and state.expanded then return '󰝰', hl end
  end
  return icon, hl
end

---@param fs_type string
---@param fs_path string
---@param state { expanded: boolean }|nil
---@return string
---@return string
H.nvim_web_devicons = function(fs_type, fs_path, state)
  local nvim_web_devicons = Fyler.import('nvim-web-devicons')
  assert(nvim_web_devicons.is_found, 'nvim-web-devicons not found')
  if fs_type == 'directory' then
    if state and state.expanded then return '󰝰', 'FylerDirectoryIcon' end
    return '󰉋', 'FylerDirectoryIcon'
  end
  local icon, hl = nvim_web_devicons.get_icon(vim.fs.basename(fs_path))
  return icon or '', hl
end

---@param fs_type string
---@param fs_path string
---@param state { expanded: boolean }|nil
---@return string
H.vim_nerdfont = function(fs_type, fs_path, state)
  assert(vim.fn.exists('*nerdfont#find'), 'vim-nerdfont are not installed or not loaded')
  if fs_type == 'directory' then
    if state and state.expanded then return '' end
    return ''
  end
  return vim.fn['nerdfont#find'](fs_path)
end

---@param fs_type string
---@param fs_path string
---@param state { expanded: boolean }|nil
---@return string|nil
---@return string|nil
M.get = function(fs_type, fs_path, state)
  local integration_name = config.DATA.integrations.icon
  if not (integration_name and H[integration_name]) then return end
  return H[integration_name](fs_type, fs_path, state)
end

return M

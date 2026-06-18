local M = {}

---@class fyler.HooksConfig
---@field on_highlight fun(highlights: table, palette: table)|nil
---@field on_delete fun(path: string)|nil
---@field on_rename fun(old_path: string, new_path: string)|nil

---@class fyler.Config
---@field auto_confirm_simple_mutation boolean
---@field bound_cursor boolean
---@field buf_opts table
---@field extensions table
---@field follow_current_file boolean
---@field hooks fyler.HooksConfig
---@field integrations table
---@field kind fyler.FinderWindowKind
---@field kind_presets table
---@field mappings table
---@field ui table
---@field use_as_default_explorer boolean
---@field win_opts table

--- SETUP ~
---
---@eval
--- local MiniDoc = require('mini.doc')
--- local code_lines = MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
--- local code_table = vim.split(code_lines, '\n')
--- table.remove(code_table, 2)
--- for _ = 1, 4 do table.remove(code_table, #code_table - 1) end
--- table.insert(code_table, 2, "  local fyler = require('fyler')")
--- table.insert(code_table, 3, "")
--- table.insert(code_table, 4, "  fyler.setup({")
--- table.insert(code_table, #code_table, "  })")
--- return table.concat(code_table, '\n')
---
---@tag fyler.setup
local default_config = {
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
  -- Whether to use finder as the default file explorer.
  use_as_default_explorer = true,
}

---@class (partial) fyler.UserConfig : fyler.Config

local function normalize_mappings(mappings)
  local normalized_mappings = {}
  for mode, mode_mappings in pairs(mappings) do
    normalized_mappings[mode] = {}
    for key, mapping in pairs(mode_mappings) do
      normalized_mappings[mode][vim.fn.keytrans(vim.api.nvim_replace_termcodes(key, true, true, true))] = mapping
    end
  end
  return normalized_mappings
end

-- HACK: May there is better way to normalize mappings
function M.get_config(custom_config)
  custom_config = custom_config or {}
  custom_config.kind = custom_config.kind or M.DATA.kind
  if custom_config.mappings then custom_config.mappings = normalize_mappings(custom_config.mappings) end
  return vim.tbl_deep_extend('force', M.DATA, M.DATA.kind_presets[custom_config.kind], custom_config)
end

---@param user_config fyler.UserConfig|nil
M.setup = function(user_config)
  user_config = user_config or {}

  if user_config.mappings then user_config.mappings = normalize_mappings(user_config.mappings) end
  if user_config.kind_presets then
    for _, preset in pairs(user_config.kind_presets) do
      if preset.mappings then preset.mappings = normalize_mappings(preset.mappings) end
    end
  end

  M.DATA = vim.tbl_deep_extend('force', default_config, user_config)

  if not M.DATA.hooks.on_delete then
    M.DATA.hooks.on_delete = function(path)
      local buf = vim.fn.bufnr(path)
      if buf > 0 then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
    end
  end

  if not M.DATA.hooks.on_rename then
    M.DATA.hooks.on_rename = function(old_path, new_path)
      local buf = vim.fn.bufnr(old_path)
      if buf > 0 then pcall(vim.api.nvim_buf_set_name, buf, new_path) end
    end
  end
end

return M

local M = {}

local hl_ns = vim.api.nvim_create_namespace('FylerInput')
local util = require('fyler.util')

---@private
---@param buf_id integer
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
local buffer_set_keymap = function(buf_id, mode, lhs, rhs) vim.keymap.set(mode, lhs, rhs, { buffer = buf_id }) end

---@param lines string[]|nil
---@param highlights table|nil
---@param callback fun(confirmed: boolean)
M.get_confirmation = function(lines, highlights, callback)
  lines = lines or {}
  highlights = highlights or {}

  local buf_id = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  util.buffer_set_option(buf_id, 'bufhidden', 'wipe')
  util.buffer_set_option(buf_id, 'modifiable', false)

  vim.api.nvim_buf_clear_namespace(buf_id, hl_ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(
      buf_id,
      hl_ns,
      hl.start_row,
      hl.start_col,
      { hl_group = hl.hl_group, end_row = hl.end_row, end_col = hl.end_col, hl_mode = 'combine' }
    )
  end

  local confirm_text = ' Want to continue? '
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end
  width = math.max(#confirm_text, math.min(width + 4, vim.o.columns - 4))
  local height = math.min(#lines, vim.o.lines - 4)

  local win_config = {
    border = 'rounded',
    col = math.max(0, (vim.o.columns - width) / 2),
    height = height,
    relative = 'editor',
    row = math.max(0, (vim.o.lines - height) / 2 - 1),
    style = 'minimal',
    title = confirm_text,
    title_pos = 'center',
    width = width,
  }

  local win_id = vim.api.nvim_open_win(buf_id, true, win_config)

  local get_callback = function(returned_value)
    return function()
      pcall(vim.api.nvim_win_close, win_id, true)

      callback(returned_value)
    end
  end

  buffer_set_keymap(buf_id, 'n', 'y', get_callback(true))
  buffer_set_keymap(buf_id, 'n', 'Y', get_callback(true))
  buffer_set_keymap(buf_id, 'n', '<CR>', get_callback(true))
  buffer_set_keymap(buf_id, 'n', 'n', get_callback(false))
  buffer_set_keymap(buf_id, 'n', 'N', get_callback(false))
  buffer_set_keymap(buf_id, 'n', '<ESC>', get_callback(false))
  buffer_set_keymap(buf_id, 'n', '<C-c>', get_callback(false))
end

---@param filter function|nil
---@return integer|nil
M.get_selected_window = function(filter)
  ---@cast filter fun(win_id: integer, buf_id: integer): boolean
  filter = vim.F.if_nil(filter, function(_, buf_id) return not vim.bo[buf_id].filetype:find('^fyler') end)

  local char_to_win_id = {}
  local chars = 'asdfghjkl'
  local win_id_to_char = {}
  local win_id_to_config = {}

  local tabpage_wins = vim
    .iter(vim.api.nvim_tabpage_list_wins(0))
    :filter(function(win_id)
      if #chars == 0 then return false end
      local buf_id = vim.api.nvim_win_get_buf(win_id)
      local win_config = vim.api.nvim_win_get_config(win_id)
      local should_keep = #win_config.relative == 0 and filter(win_id, buf_id)
      if should_keep then
        local char = chars:sub(1, 1)
        win_id_to_char[win_id] = char
        win_id_to_config[win_id] = win_config
        char_to_win_id[char] = win_id
        chars = chars:sub(2)
      end
      return should_keep
    end)
    :totable()

  if #tabpage_wins <= 1 then return tabpage_wins[1] end

  for win_id, win_config in pairs(win_id_to_config) do
    win_config.winbar = vim.wo[win_id].winbar
    win_config.winhighlight = vim.wo[win_id].winhighlight
    vim.wo[win_id].winhighlight = 'WinBar:FylerWinpickMarker,WinBarNC:FylerWinpickMarker'
    vim.wo[win_id].winbar = string.rep(' ', (win_config.width - 1) / 2) .. win_id_to_char[win_id]
  end

  vim.cmd.redraw()

  local choice = vim.fn.getcharstr()
  for win_id, win_config in pairs(win_id_to_config) do
    vim.wo[win_id].winbar = win_config.winbar
    vim.wo[win_id].winhighlight = win_config.winhighlight
  end

  return char_to_win_id[choice]
end

return M

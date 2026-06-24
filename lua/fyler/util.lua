local M = {}
local prior_windows = {} ---@type table<integer, integer>

function M.buffer_is_valid(buf_id) return buf_id and vim.api.nvim_buf_is_valid(buf_id) or false end

function M.highlight_get_color(group, key)
  local hl = vim.api.nvim_get_hl(0, { name = group })
  return hl[key] and string.format('#%06x', hl[key]) or nil
end

function M.list_to_dict(list)
  local dict = {}
  for _, item in ipairs(list) do
    dict[item] = true
  end
  return dict
end

function M.buffer_set_option(buf_id, name, value)
  if M.buffer_is_valid(buf_id) then vim.api.nvim_set_option_value(name, value, { buf = buf_id, scope = 'local' }) end
end

function M.window_set_option(win_id, name, value)
  if M.window_is_valid(win_id) then vim.api.nvim_set_option_value(name, value, { win = win_id, scope = 'local' }) end
end

function M.promise_all(n, callback)
  if n == 0 then
    vim.schedule(callback)
    return function() end
  end
  local count = 0
  return function()
    count = count + 1
    if count == n then vim.schedule(callback) end
  end
end

function M.window_is_valid(win_id) return win_id and vim.api.nvim_win_is_valid(win_id) or false end

---@return integer
---@nodiscard
function M.calculate_view_lines()
  return vim.o.lines - (vim.o.showtabline > 0 and 1 or 0) - (vim.o.laststatus > 0 and 1 or 0) - vim.o.cmdheight
end

---@private
---@param dimension integer|string
---@param reference integer
---@return integer
---@nodiscard
function M.normalize_dimension(dimension, reference)
  local with_bound = function(v) return math.max(1, math.floor(v)) end

  if type(dimension) == 'number' then return with_bound(dimension) end

  assert(type(dimension) == 'string', 'Expected string got ' .. type(dimension))

  local is_relative = vim.endswith(dimension, '%')
  local numeric = tonumber(is_relative and dimension:sub(1, -2) or dimension)

  return with_bound(is_relative and reference * numeric * 0.01 or numeric)
end

---@private
---@param offset integer|string
---@param dimension integer
---@param reference integer
---@return integer
---@nodiscard
function M.normalize_offset(offset, dimension, reference)
  local with_bound = function(v) return math.max(0, math.ceil(v)) end

  if type(offset) == 'number' then return with_bound(offset) end

  assert(type(offset) == 'string', 'Expected string got ' .. type(offset))

  if offset == 'center' then
    return with_bound((reference - dimension) * 0.5)
  elseif offset == 'end' then
    return with_bound(reference - dimension)
  else
    return 0
  end
end

---@private
---@param win_id integer
function M.window_focus(win_id) vim.api.nvim_set_current_win(win_id) end

---@private
---@param window_config table
---@return vim.api.keyset.win_config|nil
---@nodiscard
function M.window_get_config(window_config)
  local win_config = {}

  if window_config.kind == 'replace' then return end

  local has_border = (window_config.kind == 'floating' and window_config.border ~= 'none')
  local has_tabline = vim.o.showtabline > 0
  local view_lines = M.calculate_view_lines()

  if window_config.width then win_config.width = M.normalize_dimension(window_config.width, vim.o.columns) end
  if window_config.height then
    win_config.height = M.normalize_dimension(window_config.height, view_lines) - (has_border and 2 or 0)
  end

  if window_config.kind == 'floating' then
    win_config.border = window_config.border
    win_config.footer = window_config.footer
    win_config.footer_pos = window_config.footer_pos
    win_config.relative = window_config.relative or 'editor'
    win_config.style = window_config.style or 'minimal'
    win_config.title = window_config.title
    win_config.title_pos = window_config.title_pos

    if window_config.col and win_config.width then
      win_config.col = M.normalize_offset(window_config.col, win_config.width, vim.o.columns)
    end
    if window_config.row and win_config.height then
      win_config.row = math.max(0, M.normalize_offset(window_config.row, win_config.height, view_lines) - 2)
      if has_tabline then win_config.row = math.max(1, win_config.row) end
    end
  else
    local split_map = {
      split_above = { split = 'above' },
      split_above_all = { split = 'above', win = -1 },
      split_below = { split = 'below' },
      split_below_all = { split = 'below', win = -1 },
      split_left = { split = 'left' },
      split_left_most = { split = 'left', win = -1 },
      split_right = { split = 'right' },
      split_right_most = { split = 'right', win = -1 },
    }
    win_config = vim.tbl_deep_extend('force', win_config, split_map[window_config.kind])
  end

  return win_config
end

---@private
---@param win_id integer
---@param window_config table
function M.window_resize(win_id, window_config)
  if not M.window_is_valid(win_id) then return end
  local win_config = M.window_get_config(window_config)
  if win_config then pcall(vim.api.nvim_win_set_config, win_id, win_config) end
end

---@param tab_id integer
---@return integer|nil
function M.window_get_prior(tab_id)
  local win_id = prior_windows[tab_id]
  if win_id and vim.api.nvim_win_is_valid(win_id) then return win_id end
  prior_windows[tab_id] = nil
  return nil
end

---@param tab_id integer
---@param win_id integer
function M.window_set_prior(tab_id, win_id) prior_windows[tab_id] = win_id end

return M

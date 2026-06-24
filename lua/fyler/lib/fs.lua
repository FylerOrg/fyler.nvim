local M = {}

---@param path string
---@param hidden_items table
---@return boolean
function M.is_hidden(path, hidden_items)
  local hidden_funcs = { dotfiles = function(p) return vim.startswith(vim.fs.basename(p), '.') end }

  for _, pattern in ipairs(hidden_items.always_visible) do
    if path:match(pattern) then return false end
  end

  for _, pattern in ipairs(hidden_items.always_hidden) do
    if path:match(pattern) then return true end
  end

  for switch_name, enabled in pairs(hidden_items.switches) do
    local func = switch_name and hidden_funcs[switch_name] or nil
    if func and enabled and func(path) then return true end
  end

  for pattern, enabled in pairs(hidden_items.patterns) do
    if path:match(pattern) and enabled then return true end
  end

  return false
end

---@param x fyler.FSEntry
---@param y fyler.FSEntry
---@return boolean
M.sort = function(x, y)
  if not x.path or not y.path then return false end
  local x_is_dir = x.type == 'directory'
  local y_is_dir = y.type == 'directory'
  if x_is_dir and not y_is_dir then
    return true
  elseif not x_is_dir and y_is_dir then
    return false
  else
    ---@param str string
    ---@return string
    local pad = function(str)
      return (str:gsub('%d+', function(n) return string.format('%010d', n) end))
    end
    return pad(x.name) < pad(y.name)
  end
end

return M

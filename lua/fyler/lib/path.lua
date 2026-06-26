local M = {}

M.is_case_insensitive = jit.os == 'Windows' or jit.os == 'OSX'
M.is_windows = jit.os == 'Windows'

---@nodiscard
---@return string
M.do_join = function(...)
  local joined = table.concat({ ... }, '/')
  return M.to_normalize(joined)
end

---@nodiscard
---@return string[]
M.do_split = function(path)
  return vim
    .iter(vim.split(path:gsub('\\', '/'), '/'))
    :filter(function(segment) return #segment > 0 end)
    :map(function(segment)
      local drive = segment:match('^([%a]):$')
      if drive then return drive:lower() end
      return segment
    end)
    :totable()
end

---@nodiscard
---@return boolean
M.is_abs = function(path) return vim.fn.isabsolutepath(path) == 1 end

---@nodiscard
---@param a string
---@param b string
---@return boolean
M.is_equal = function(a, b) return M.to_normalize(a) == M.to_normalize(b) end
if M.is_case_insensitive then
  ---@nodiscard
  ---@param a string
  ---@param b string
  ---@return boolean
  M.is_equal = function(a, b) return M.to_normalize(a:lower()) == M.to_normalize(b:lower()) end
end

---@nodiscard
---@return string
M.to_abs = function(path)
  if M.is_abs(path) then return M.to_normalize(path) end
  return M.to_normalize(vim.fs.abspath(path))
end

---@nodiscard
---@return string
M.to_dirname = function(path) return vim.fs.dirname(M.to_normalize(path)) end

--- Normalizes a path for use as a table key.
--- On case-insensitive systems (macOS, Windows), lowercases the path
--- so lookkeys remain consistent regardless of input casing.
---
---@nodiscard
---@param path string
---@return string
M.to_key = function(path)
  path = M.to_normalize(path)
  if M.is_case_insensitive then path = path:lower() end
  return path
end

---@nodiscard
---@return string
M.to_normalize = function(path)
  local is_unc = M.is_windows and (path:sub(1, 2) == '//' or path:sub(1, 2) == '\\\\')
  local normalized = vim.fs.normalize(path)
  if is_unc and not (normalized:sub(1, 2) == '//') then normalized = '//' .. normalized:match('^/+(.*)') end
  if not M.is_windows then normalized = normalized:gsub('/+', '/') end
  return normalized
end

---@nodiscard
---@return string
M.to_os = function(path) return M.to_normalize(path) end
if M.is_windows then
  M.to_os = function(path)
    local normalized = M.to_normalize(path:gsub('\\', '/'))
    if M.is_abs(path) then
      if normalized:sub(1, 2) == '//' then return normalized end
      local drive, rest = normalized:match('^/([%a])/(.*)$')
      if drive then return ('%s:/%s'):format(drive:upper(), rest) end
      return normalized
    end
    local drive, rest = normalized:match('^/([%a])/(.+)$')
    if drive then
      local candidate = ('%s:/%s'):format(drive:upper(), rest)
      if M.to_posix(candidate) == path then return candidate end
    end
    return normalized
  end
end

---@nodiscard
---@return string
M.to_posix = function(path) return M.to_normalize(path) end
if M.is_windows then
  M.to_posix = function(path)
    if M.is_abs(path) then
      if path:sub(1, 2) == '\\\\' then
        local forward = path:gsub('\\', '/')
        return M.to_normalize('/' .. forward:sub(2))
      end
      local drive, rest = path:match('^([%a]):[/\\](.*)$')
      if drive then return M.to_normalize(('/%s/%s'):format(drive:lower(), rest)) end
    end
    return M.to_normalize(path)
  end
end

---@nodiscard
---@return string
M.to_rel = function(base, target) return vim.fs.relpath(M.to_normalize(base), M.to_normalize(target)) or '' end

---@nodiscard
---@param a string
---@param b string
---@return string|nil
M.common_ancestor = function(a, b)
  a = M.to_normalize(a)
  b = M.to_normalize(b)

  local parts_a = vim.split(a, '/', { plain = true })
  local parts_b = vim.split(b, '/', { plain = true })

  local common = {}
  for i = 1, math.min(#parts_a, #parts_b) do
    if parts_a[i] == parts_b[i] then
      table.insert(common, parts_a[i])
    else
      break
    end
  end

  if #common <= 1 then return nil end

  return table.concat(common, '/')
end

return M

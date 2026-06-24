local M = {}
local H = {}

---@class fyler.ExtMark
---@field row integer
---@field col integer
---@field opts table

---@class fyler.HighlightRange
---@field hl_group string
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer

---@class fyler.LineChange
---@field start_row integer
---@field end_row integer
---@field lines string[]

---@class fyler.RenderResult
---@field changes fyler.LineChange[]
---@field lines string[]
---@field highlights fyler.HighlightRange[]
---@field extmarks fyler.ExtMark[]

---@class fyler.UiComponent
---@field children fyler.UiComponent[]|nil
---@field value string|nil
---@field tag string|nil

---@class fyler.UiComponentCol: fyler.UiComponent
---@field children fyler.UiComponent[]
---@field tag 'col'

---@class fyler.UiComponentRow: fyler.UiComponent
---@field children fyler.UiComponent[]
---@field tag 'row'

---@class fyler.UiComponentText: fyler.UiComponent
---@field tag 'text'
---@field value string
---@field hl string|nil
---@field extmarks table[]|nil

---@param component fyler.UiComponent
---@return fyler.RenderResult
H.compose = function(component)
  local handler_name = ({ text = 'compose_text', row = 'compose_row', col = 'compose_col' })[component.tag]
  if not handler_name then error(('Unknown component tag: %s'):format(tostring(component.tag))) end
  return H[handler_name](component)
end

---@param component fyler.UiComponentCol
---@return fyler.RenderResult
H.compose_col = function(component)
  local children = component.children or {}
  if #children == 0 then return { lines = {}, highlights = {}, extmarks = {} } end

  local acc = { lines = {}, highlights = {}, extmarks = {} }
  local row = 0

  for _, child in ipairs(children) do
    local r = H.compose(child)

    for _, line in ipairs(r.lines) do
      acc.lines[#acc.lines + 1] = line
    end
    for _, hl in ipairs(r.highlights) do
      acc.highlights[#acc.highlights + 1] = H.offset_highlight(hl, row, 0)
    end
    for _, em in ipairs(r.extmarks) do
      acc.extmarks[#acc.extmarks + 1] = H.offset_extmark(em, row, 0)
    end
    row = row + #r.lines
  end

  return acc
end

---@param component fyler.UiComponentRow
---@return fyler.RenderResult
H.compose_row = function(component)
  local children = component.children or {}
  if #children == 0 then return { lines = { '' }, highlights = {}, extmarks = {} } end

  local results = {}
  for _, child in ipairs(children) do
    results[#results + 1] = H.compose(child)
  end

  local max_height = 0
  for _, r in ipairs(results) do
    max_height = math.max(max_height, #r.lines)
  end
  if max_height == 0 then max_height = 1 end

  for _, r in ipairs(results) do
    for i = #r.lines + 1, max_height do
      r.lines[i] = ''
    end
  end

  for _, r in ipairs(results) do
    local max_width = 0
    for _, line in ipairs(r.lines) do
      max_width = math.max(max_width, #line)
    end
    for i, line in ipairs(r.lines) do
      r.lines[i] = line .. string.rep(' ', max_width - #line)
    end
  end

  local acc = { lines = {}, highlights = {}, extmarks = {} }
  local col = 0

  for _, r in ipairs(results) do
    for i = 1, max_height do
      acc.lines[i] = (acc.lines[i] or '') .. r.lines[i]
    end
    for _, hl in ipairs(r.highlights) do
      acc.highlights[#acc.highlights + 1] = H.offset_highlight(hl, 0, col)
    end
    for _, em in ipairs(r.extmarks) do
      acc.extmarks[#acc.extmarks + 1] = H.offset_extmark(em, 0, col)
    end
    col = col + #r.lines[1]
  end

  return acc
end

---@param component fyler.UiComponentText
---@return fyler.RenderResult
H.compose_text = function(component)
  local value = component.value or ''
  local result = {
    lines = { value },
    highlights = {},
    extmarks = {},
  }

  if component.hl then
    result.highlights[1] = {
      hl_group = component.hl,
      start_row = 0,
      start_col = 0,
      end_row = 0,
      end_col = #value,
    }
  end

  if component.extmarks then
    for _, em in ipairs(component.extmarks) do
      result.extmarks[#result.extmarks + 1] = em
    end
  end

  return result
end

---@param em fyler.ExtMark
---@param row_offset integer
---@param col_offset integer
---@return fyler.ExtMark
H.offset_extmark = function(em, row_offset, col_offset)
  if row_offset == 0 and col_offset == 0 then return em end
  return {
    row = em.row + row_offset,
    col = em.col + col_offset,
    opts = em.opts,
  }
end

---@param hl fyler.HighlightRange
---@param row_offset integer
---@param col_offset integer
---@return fyler.HighlightRange
H.offset_highlight = function(hl, row_offset, col_offset)
  if row_offset == 0 and col_offset == 0 then return hl end
  return {
    hl_group = hl.hl_group,
    start_row = hl.start_row + row_offset,
    start_col = hl.start_col + col_offset,
    end_row = hl.end_row + row_offset,
    end_col = hl.end_col + col_offset,
  }
end

---@param old_lines string[]
---@param new_lines string[]
---@return fyler.LineChange[]
H.diff_lines = function(old_lines, new_lines)
  local m, n = #old_lines, #new_lines
  if m == 0 and n == 0 then return {} end

  local prefix = 0
  while prefix < m and prefix < n and old_lines[prefix + 1] == new_lines[prefix + 1] do
    prefix = prefix + 1
  end

  local suffix = 0
  while suffix < m - prefix and suffix < n - prefix and old_lines[m - suffix] == new_lines[n - suffix] do
    suffix = suffix + 1
  end

  local start_row = prefix
  local old_end = m - suffix
  local new_middle = {}
  for i = prefix + 1, n - suffix do
    new_middle[#new_middle + 1] = new_lines[i]
  end

  if #new_middle == 0 and old_end == start_row then return {} end

  return { { start_row = start_row, end_row = old_end, lines = new_middle } }
end

---@nodiscard
---@param component fyler.UiComponent
---@param prev_component fyler.UiComponent|nil
---@return fyler.RenderResult
M.compose = function(component, prev_component)
  local result = H.compose(component)

  if prev_component then
    local prev_result = H.compose(prev_component)
    return {
      changes = H.diff_lines(prev_result.lines, result.lines),
      lines = result.lines,
      highlights = result.highlights,
      extmarks = result.extmarks,
    }
  else
    return {
      changes = { { start_row = 0, end_row = -1, lines = result.lines } },
      lines = result.lines,
      highlights = result.highlights,
      extmarks = result.extmarks,
    }
  end
end

return M

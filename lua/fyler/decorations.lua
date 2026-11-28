local extensions = Fyler.import('fyler.extensions')
local util = Fyler.import('fyler.util')

local M = {}
local H = {}

-- Fixed spacing between entry names and decorations, and between decoration
-- fragments/slots. These are not configurable.
local GAP = 1
local SEPARATOR = ' '

---@alias fyler.DecorationArea 'column'|'inline'

---@class fyler.DecorationCell
---@field chunks table[]|nil Virtual text chunks in `{ text, highlight }` form
---@field entry_hl string|nil Highlight applied to the entry name

---@class fyler.DecorationContext
---@field instance fyler.Finder
---@field entries fyler.FSEntry[]
---@field area fyler.DecorationArea
---@field args table

---@alias fyler.DecorationProvider fun(ctx: fyler.DecorationContext, emit: fun(cells: table<integer, fyler.DecorationCell>)): table<integer, fyler.DecorationCell>|nil

---@class fyler.DecorationDefinition
---@field provide fyler.DecorationProvider
---@field get_area (fun(extension_config: table): fyler.DecorationArea|nil)|nil

local states = setmetatable({}, { __mode = 'k' })

H.namespace = function(buf_id) return vim.api.nvim_create_namespace('FylerDecorationsBuf' .. buf_id) end

H.text_width = function(text) return vim.fn.strdisplaywidth(text) end

H.chunks_width = function(chunks)
  local width = 0
  for _, chunk in ipairs(chunks) do
    width = width + H.text_width(chunk[1])
  end
  return width
end

H.append_text = function(chunks, text, hl)
  if #text > 0 then chunks[#chunks + 1] = { text, hl or 'Normal' } end
end

H.append_spaces = function(chunks, count) H.append_text(chunks, string.rep(' ', count)) end

H.normalize_cells = function(cells, state)
  local normalized = {}
  if type(cells) ~= 'table' then return normalized end

  for entry_id, cell in pairs(cells) do
    if state.entry_ids[entry_id] and type(cell) == 'table' then
      local chunks = {}
      for _, chunk in ipairs(cell.chunks or {}) do
        if type(chunk) == 'table' and type(chunk[1]) == 'string' and #chunk[1] > 0 then
          chunks[#chunks + 1] = { chunk[1], chunk[2] or 'Normal' }
        end
      end

      local entry_hl = type(cell.entry_hl) == 'string' and cell.entry_hl or nil
      if #chunks > 0 or entry_hl then normalized[entry_id] = { chunks = chunks, entry_hl = entry_hl } end
    end
  end

  return normalized
end

H.sort_sources = function(available)
  local order = vim.deepcopy(available)
  table.sort(order)

  return order
end

H.is_current = function(instance, state)
  return states[instance] == state
    and util.buffer_is_valid(state.buf_id)
    and util.window_is_valid(instance.win_id)
    and vim.api.nvim_win_get_buf(instance.win_id) == state.buf_id
    and vim.b[state.buf_id].changedtick == state.changedtick
end

H.visible_line = function(line, item)
  local prefix = line:sub(1, item._name_col)
  prefix = prefix:gsub('/%d+ $', '', 1)
  return prefix .. line:sub(item._name_col + 1)
end

H.notify_error = function(name, err)
  vim.schedule(
    function()
      vim.notify(
        ('Fyler: decoration source "%s" failed: %s'):format(name, err),
        vim.log.levels.WARN,
        { title = 'Fyler.nvim' }
      )
    end
  )
end

H.schedule_render = function(instance, state)
  if state.scheduled then return end
  state.scheduled = true

  vim.schedule(function()
    state.scheduled = false
    if H.is_current(instance, state) then M.render(instance, state) end
  end)
end

H.build_inline = function(state, item)
  local chunks = {}
  local fragment_count = 0

  for _, name in ipairs(state.orders.inline) do
    local source_cells = state.cells[name]
    local cell = source_cells and source_cells[item.id]
    if cell and #cell.chunks > 0 then
      if fragment_count == 0 then
        H.append_spaces(chunks, GAP)
      else
        H.append_text(chunks, SEPARATOR)
      end
      vim.list_extend(chunks, cell.chunks)
      fragment_count = fragment_count + 1
    end
  end

  return chunks
end

H.apply_entry_highlights = function(state, item, row)
  for _, area in ipairs({ 'inline', 'column' }) do
    for _, name in ipairs(state.orders[area]) do
      local source_cells = state.cells[name]
      local cell = source_cells and source_cells[item.id]
      if cell and cell.entry_hl then
        vim.api.nvim_buf_set_extmark(state.buf_id, H.namespace(state.buf_id), row - 1, item._name_col, {
          hl_group = cell.entry_hl,
          end_row = row - 1,
          end_col = item._name_col + #item.name,
          hl_mode = 'combine',
        })
      end
    end
  end
end

H.build_slots = function(state)
  local slots = {}

  for _, name in ipairs(state.orders.column) do
    local source_cells = state.cells[name]
    local cells = {}
    local width = 0

    for row, item in ipairs(state.entries) do
      local cell = source_cells and source_cells[item.id]
      if cell and #cell.chunks > 0 then
        local cell_width = H.chunks_width(cell.chunks)
        cells[row] = { chunks = cell.chunks, width = cell_width }
        width = math.max(width, cell_width)
      end
    end

    if width > 0 then slots[#slots + 1] = {
      cells = cells,
      width = width,
    } end
  end

  return slots
end

H.column_layout = function(instance, state, content_end)
  local slots = H.build_slots(state)
  if #slots == 0 then return nil end

  local cfg = instance.opts.ui.decorations
  local separator = SEPARATOR
  local group_width = (#slots - 1) * H.text_width(separator)
  for _, slot in ipairs(slots) do
    group_width = group_width + slot.width
  end

  local win_info = vim.fn.getwininfo(instance.win_id)[1]
  if not win_info then return nil end
  local available_width = win_info.width - win_info.textoff
  local required_start = content_end + GAP
  local start_col = cfg.area == 'column_end' and available_width - group_width or required_start

  -- The column area is atomic: either every slot fits without overlapping
  -- content, or none of the column decorations are rendered.
  if start_col < required_start or start_col + group_width > available_width then return nil end

  return { separator = separator, slots = slots, start_col = start_col }
end

H.render_columns = function(state, layout)
  for row = 1, #state.entries do
    local chunks = {}
    local has_content = false

    for index, slot in ipairs(layout.slots) do
      if index > 1 then H.append_text(chunks, layout.separator) end

      local cell = slot.cells[row]
      local cell_width = cell and cell.width or 0
      if cell then
        vim.list_extend(chunks, cell.chunks)
        has_content = true
      end
      H.append_spaces(chunks, slot.width - cell_width)
    end

    if has_content then
      vim.api.nvim_buf_set_extmark(state.buf_id, H.namespace(state.buf_id), row - 1, 0, {
        virt_text = chunks,
        virt_text_win_col = layout.start_col,
        hl_mode = 'combine',
      })
    end
  end
end

M.render = function(instance, state)
  local ns = H.namespace(state.buf_id)
  vim.api.nvim_buf_clear_namespace(state.buf_id, ns, 0, -1)

  vim.api.nvim_win_call(instance.win_id, function()
    local content_end = 0

    for row, item in ipairs(state.entries) do
      H.apply_entry_highlights(state, item, row)

      local inline_chunks = H.build_inline(state, item)
      if #inline_chunks > 0 then
        vim.api.nvim_buf_set_extmark(state.buf_id, ns, row - 1, item._name_col + #item.name, {
          virt_text = inline_chunks,
          virt_text_pos = 'inline',
          hl_mode = 'combine',
        })
      end

      local line_width = H.text_width(H.visible_line(state.lines[row], item))
      content_end = math.max(content_end, line_width + H.chunks_width(inline_chunks))
    end

    local layout = H.column_layout(instance, state, content_end)
    if layout then H.render_columns(state, layout) end
  end)
end

M.relayout = function(instance)
  local state = states[instance]
  if state and H.is_current(instance, state) then H.schedule_render(instance, state) end
end

M.refresh = function(instance, entries, lines, args)
  local buf_id = instance.buf_id
  local ns = H.namespace(buf_id)
  vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)

  local state = {
    args = args or {},
    buf_id = buf_id,
    cells = {},
    changedtick = vim.b[buf_id].changedtick,
    entries = entries,
    entry_ids = {},
    lines = lines,
    orders = { column = {}, inline = {} },
    scheduled = false,
  }
  states[instance] = state
  for _, item in ipairs(entries) do
    state.entry_ids[item.id] = true
  end

  local cfg = instance.opts.ui.decorations
  if not cfg.enabled then return end

  local available = { column = {}, inline = {} }
  local active = {}
  for _, source in ipairs(extensions.decoration_sources()) do
    local extension_cfg = (instance.opts.extensions or {})[source.name]
    if extension_cfg and extension_cfg.enabled then
      local placement = source.get_area
          and (function()
            local ok, value = pcall(source.get_area, extension_cfg)
            if not ok then
              H.notify_error(source.name, value)
              return nil
            end
            return value
          end)()
        or cfg.area

      local area = placement == 'inline' and 'inline' or 'column'

      if area == 'inline' or area == 'column' then
        available[area][#available[area] + 1] = source.name
        active[#active + 1] = { area = area, source = source }
      end
    end
  end

  state.orders.inline = H.sort_sources(available.inline)
  state.orders.column = H.sort_sources(available.column)

  for _, item in ipairs(active) do
    local source = item.source
    local ctx = { instance = instance, entries = entries, area = item.area, args = state.args }
    local emit = function(cells)
      if not H.is_current(instance, state) then return end
      state.cells[source.name] = H.normalize_cells(cells, state)
      H.schedule_render(instance, state)
    end

    local ok, result = pcall(source.provide, ctx, emit)
    if not ok then
      H.notify_error(source.name, result)
    elseif type(result) == 'table' then
      emit(result)
    end
  end
end

return M

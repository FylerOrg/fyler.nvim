local Path = require("fyler.lib.path")
local Ui = require("fyler.lib.ui")
local config = require("fyler.config")
local diagnostic = require("fyler.lib.diagnostic")
local git = require("fyler.lib.git")
local util = require("fyler.lib.util")

local Component = Ui.Component
local Text = Ui.Text
local Row = Ui.Row
local Column = Ui.Column

local COLUMN_ORDER = config.values.views.finder.columns_order

local function sort_nodes(nodes)
  table.sort(nodes, function(x, y)
    local x_is_dir = x.type == "directory"
    local y_is_dir = y.type == "directory"
    if x_is_dir and not y_is_dir then
      return true
    elseif not x_is_dir and y_is_dir then
      return false
    else
      local function pad_numbers(str)
        return str:gsub("%d+", function(n) return string.format("%010d", n) end)
      end
      return pad_numbers(x.name) < pad_numbers(y.name)
    end
  end)
  return nodes
end

local function flatten_tree(node, depth, result)
  depth = depth or 0
  result = result or {}

  if not node or not node.children then return result end

  local sorted_items = sort_nodes(node.children)
  for _, item in ipairs(sorted_items) do
    table.insert(result, { item = item, depth = depth })
    if item.children and #item.children > 0 then flatten_tree(item, depth + 1, result) end
  end

  return result
end

---@return string|nil, string|nil
local function icon_and_hl(item)
  local icon, hl = config.icon_provider(item.type, item.path)
  if config.values.integrations.icon == "none" then return icon, hl end

  if item.type == "directory" then
    local icons = config.values.views.finder.icon
    local is_empty = item.open and item.children and #item.children == 0
    local is_expanded = item.open or false
    icon = is_empty and icons.directory_empty
      or (is_expanded and icons.directory_expanded or icons.directory_collapsed)
      or icon
  end

  return icon, hl
end

local function create_column_context(tag, node, flattened_entries, files_column)
  return {
    tag = tag,
    root_dir = node.path,
    entries = flattened_entries,

    get_entry_data = function(index)
      local entry = flattened_entries[index]
      if not entry then return nil end

      return {
        path = entry.item.path,
        name = entry.item.name,
        type = entry.item.type,
        depth = entry.depth,
        ref_id = entry.item.ref_id,
        item = entry.item,
      }
    end,

    get_all_paths = function()
      return util.tbl_map(flattened_entries, function(entry) return entry.item.path end)
    end,

    get_files_column = function() return files_column end,
  }
end

local M = {}

M.tag = 0

-- NOTE: Detail columns now return data via callback instead of directly updating UI
local columns = {
  link = function(ctx, _, _next)
    local column = {}

    for i = 1, #ctx.entries do
      local entry_data = ctx.get_entry_data(i)
      if entry_data and entry_data.item.link then
        table.insert(column, Text(nil, { virt_text = { { " --> " .. entry_data.path, "FylerFSLink" } } }))
      else
        table.insert(column, Text(nil, { virt_text = { { "" } } }))
      end
    end

    _next({ column = column, highlights = {} })
  end,

  git = function(ctx, _, _next)
    git.map_entries_async(ctx.root_dir, ctx.get_all_paths(), function(entries)
      local highlights, column = {}, {}

      for i, get_entry in ipairs(entries) do
        local entry_data = ctx.get_entry_data(i)
        if entry_data then
          local hl = get_entry[2]
          highlights[i] = hl or ((entry_data.type == "directory") and "FylerFSDirectoryName" or nil)
        end
        table.insert(column, Text(nil, { virt_text = { get_entry } }))
      end

      _next({ column = column, highlights = highlights })
    end)
  end,

  diagnostic = function(ctx, _, _next)
    diagnostic.map_entries_async(ctx.root_dir, ctx.get_all_paths(), function(entries)
      local highlights, column = {}, {}

      for i, get_entry in ipairs(entries) do
        local entry_data = ctx.get_entry_data(i)
        if entry_data then
          local hl = get_entry[2]
          highlights[i] = hl or ((entry_data.type == "directory") and "FylerFSDirectoryName" or nil)
        end
        table.insert(column, Text(nil, { virt_text = { get_entry } }))
      end

      _next({ column = column, highlights = highlights })
    end)
  end,

  permission = function(ctx, _, _next)
    local function get_permissions(path)
      local stat = Path.new(path):lstats()
      if not stat then return "----------" end

      local mode = stat.mode
      local perms = {}

      if stat.type == "directory" then
        table.insert(perms, "d")
      elseif stat.type == "link" then
        table.insert(perms, "l")
      else
        table.insert(perms, "-")
      end

      table.insert(perms, (mode % 512 >= 256) and "r" or "-")
      table.insert(perms, (mode % 256 >= 128) and "w" or "-")
      table.insert(perms, (mode % 128 >= 64) and "x" or "-")

      table.insert(perms, (mode % 64 >= 32) and "r" or "-")
      table.insert(perms, (mode % 32 >= 16) and "w" or "-")
      table.insert(perms, (mode % 16 >= 8) and "x" or "-")

      table.insert(perms, (mode % 8 >= 4) and "r" or "-")
      table.insert(perms, (mode % 4 >= 2) and "w" or "-")
      table.insert(perms, (mode % 2 >= 1) and "x" or "-")

      return table.concat(perms)
    end

    local highlights, column = {}, {}

    for i = 1, #ctx.entries do
      local entry_data = ctx.get_entry_data(i)
      if entry_data then
        local perms = get_permissions(entry_data.item.link or entry_data.path)
        table.insert(column, Text(nil, { virt_text = { { perms, "Comment" } } }))
      else
        table.insert(column, Text(nil, { virt_text = { { "" } } }))
      end
    end

    _next({ column = column, highlights = highlights })
  end,

  size = function(ctx, _, _next)
    local function get_size(path)
      if Path.new(path):is_directory() then return nil end

      local stat = Path.new(path):stats()
      if not stat then return nil end

      return stat.size
    end

    local function format_size(bytes)
      if not bytes or bytes < 0 then return "     -" end

      local units = { "B", "K", "M", "G", "T" }
      local unit_index = 1
      local size = bytes

      while size >= 1024 and unit_index < #units do
        size = size / 1024
        unit_index = unit_index + 1
      end

      local formatted
      if unit_index == 1 then
        formatted = string.format("%d%s", size, units[unit_index])
      else
        formatted = string.format("%.1f%s", size, units[unit_index])
      end

      return string.format("%6s", formatted)
    end

    local highlights, column = {}, {}

    for i = 1, #ctx.entries do
      table.insert(
        column,
        Text(nil, { virt_text = { { format_size(get_size(ctx.get_entry_data(i).path)), "Comment" } } })
      )
    end

    _next({ column = column, highlights = highlights })
  end,
}

local function collect_and_render_details(tag, context, files_column, oncollect)
  local results, enabled_columns = {}, {}
  local total, completed = 0, 0
  for _, column_name in ipairs(COLUMN_ORDER) do
    local cfg = config.values.views.finder.columns[column_name]
    if cfg and cfg.enabled and columns[column_name] then
      total = total + 1
      enabled_columns[column_name] = cfg
    end
  end

  if total == 0 then return end

  local function on_column_complete(column_name, column_data)
    if M.tag ~= tag then return end

    results[column_name] = column_data
    completed = completed + 1

    if completed == total then
      local all_highlights = {}
      for _, col_name in ipairs(COLUMN_ORDER) do
        local result = results[col_name]
        if result and result.highlights then
          for index, highlight in pairs(result.highlights) do
            all_highlights[index] = highlight
          end
        end
      end

      for index, highlight in pairs(all_highlights) do
        local row = files_column[index]
        if row and row.children then
          local name_component = row.children[4]
          if name_component then
            name_component.option = name_component.option or {}
            name_component.option.highlight = highlight
          end
        end
      end

      local detail_columns = { Column(files_column) }
      for _, col_name in ipairs(COLUMN_ORDER) do
        local result = results[col_name]
        if result and result.column then
          if #detail_columns > 0 then table.insert(detail_columns, Text("  ")) end

          table.insert(detail_columns, Column(result.column))
        end
      end

      oncollect({ tag = "files", children = { Row(detail_columns) } }, { partial = true })
    end
  end

  for column_name, cfg in pairs(enabled_columns) do
    local column_fn = columns[column_name]
    if column_fn then
      local success = pcall(function()
        column_fn(context, cfg, function(column_data) on_column_complete(column_name, column_data) end)
      end)

      if not success then on_column_complete(column_name, nil) end
    end
  end
end

M.files = Component.new_async(function(node, onupdate)
  M.tag = M.tag + 1

  local current_tag = M.tag
  if not node or not node.children then return onupdate({ tag = "files", children = {} }) end

  local flattened_entries = flatten_tree(node)
  if #flattened_entries == 0 then return onupdate({ tag = "files", children = {} }) end

  local files_column = {}
  for _, entry in ipairs(flattened_entries) do
    local item, depth = entry.item, entry.depth
    local icon, hl = icon_and_hl(item)
    local icon_highlight = (item.type == "directory") and "FylerFSDirectoryIcon" or hl
    local name_highlight = (item.type == "directory") and "FylerFSDirectoryName" or nil
    icon = icon and (icon .. " ") or ""

    local indentation_text = Text(string.rep(" ", 2 * depth))
    local icon_text = Text(icon, { highlight = icon_highlight })
    local ref_id_text = item.ref_id and Text(string.format(" /%05d ", item.ref_id)) or Text("")
    local name_text = Text(item.name, { highlight = name_highlight })
    table.insert(files_column, Row({ indentation_text, icon_text, ref_id_text, name_text }))
  end

  onupdate({ tag = "files", children = { Row({ Column(files_column) }) } })

  collect_and_render_details(
    current_tag,
    create_column_context(current_tag, node, flattened_entries, files_column),
    files_column,
    onupdate
  )
end)

M.operations = Component.new(function(operations)
  local types, details = {}, {}
  for _, operation in ipairs(operations) do
    if operation.type == "create" then
      table.insert(types, Text("CREATE", { highlight = "FylerGreen" }))
      table.insert(details, Text(operation.path))
    elseif operation.type == "delete" then
      table.insert(
        types,
        Text(config.values.views.finder.delete_to_trash and "TRASH" or "DELETE", { highlight = "FylerRed" })
      )
      table.insert(details, Text(operation.path))
    elseif operation.type == "move" then
      table.insert(types, Text("MOVE", { highlight = "FylerYellow" }))
      table.insert(details, Row({ Text(operation.src), Text(" > "), Text(operation.dst) }))
    elseif operation.type == "copy" then
      table.insert(types, Text("COPY", { highlight = "FylerBlue" }))
      table.insert(details, Row({ Text(operation.src), Text(" > "), Text(operation.dst) }))
    else
      error(string.format("Unknown operation type '%s'", operation.type))
    end
  end
  return {
    tag = "operations",
    children = {
      Text(""),
      Row({ Text("  "), Column(types), Text(" "), Column(details), Text("  ") }),
      Text(""),
    },
  }
end)

return M

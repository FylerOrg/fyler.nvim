local config = Fyler.import('fyler.config')
local extensions = Fyler.import('fyler.extensions')
local icon = Fyler.import('fyler.integrations.icon')
local input = Fyler.import('fyler.input')
local libfs = Fyler.import('fyler.lib.fs')
local libpath = Fyler.import('fyler.lib.path')
local libui = Fyler.import('fyler.lib.ui')
local util = Fyler.import('fyler.util')

---@class fyler.FSEntry
---@field full_path string
---@field id integer
---@field link_target string|nil
---@field name string
---@field type string

---@class fyler.Finder
---@field buf_id integer|nil
---@field cache table
---@field opts fyler.FinderOpts
---@field state fyler.FinderState
---@field win_id integer|nil
---@field private _refresh_count integer
---@field private _is_refreshing boolean

---@class fyler.FinderOpts : fyler.WindowConfig, fyler.Config
---@field scheme string|nil
---@field root_path string|nil

---@class fyler.WindowConfig : vim.api.keyset.win_config
---@field col integer|fyler.FinderWindowAlignment|nil
---@field height integer|string|nil
---@field kind fyler.FinderWindowKind
---@field row integer|fyler.FinderWindowAlignment|nil
---@field width integer|string|nil

---@alias fyler.FinderWindowKind
---| 'floating'
---| 'replace'
---| 'split_above'
---| 'split_above_all'
---| 'split_below'
---| 'split_below_all'
---| 'split_left'
---| 'split_left_most'
---| 'split_right'
---| 'split_right_most'

---@alias fyler.FinderScheme
---| 'file'
---| 'scp'

---@alias fyler.FinderWindowAlignment
---| 'center'
---| 'end'
---| 'start'

---@class fyler.FinderState
---@field fs_meta table<string, fyler.FinderFSMeta>
---@field pseudo_root_path string
---@field root fyler.FinderStateNode
---@field root_path string
---@field scheme fyler.FinderSchemeHandler

---@class fyler.FinderFSMeta
---@field expanded boolean

---@class fyler.FinderStateNode
---@field children table<string, fyler.FinderStateNode>
---@field value integer|nil

---@class fyler.StateUpdateOpts
---@field callback function|nil
---@field target_node table|nil
---@field target_path string|nil

---@class fyler.FinderSchemeHandler
---@field fs_is_dir fun(path: string): boolean
---@field fs_scan_dir fun(path: string, cb: fun(err: string|nil, entries: table|nil))
---@field fs_mutate fun(actions: fyler.Action[], cb: fun(err: string|nil))

local M = {}
local H = {}
local instances = {} ---@type table<integer, fyler.Finder>
local prior_windows = {} ---@type table<integer, integer>

local store = {} ---@type table<integer, fyler.FSEntry>
local path_to_id = {} ---@type table<string, integer>
local next_id = 1

local build_fs_action_id = function(fs_action)
  return string.format('%s | %s | %s', fs_action.name, fs_action.src, fs_action.dst)
end

---@param fs_entry table
---@return integer
local store_register = function(fs_entry)
  local id = next_id
  next_id = next_id + 1
  fs_entry.id = id
  store[id] = fs_entry
  path_to_id[libpath.to_key(fs_entry.full_path)] = id
  return id
end

---@private
---@param buf_line string
---@return integer|nil
---@return string
---@return integer
---@return boolean
local parse_buf_line = function(buf_line)
  local id = buf_line:match('/(%d+)')
  local depth = (#buf_line:match('^(%s*)') * 0.5)
  buf_line = buf_line:match('^%s*(.*)$')
  if id then
    local name = buf_line:match('/%d+ (.*)$')
    local id_int = tonumber(id, 10)
    return id_int, name, depth, vim.endswith(name, '/')
  end
  return nil, buf_line, depth, vim.endswith(buf_line, '/')
end

---@private
---@param node fyler.FinderStateNode
---@return table
---@nodiscard
H.sorted_children = function(node)
  local sorted = vim.tbl_values(node.children)
  table.sort(sorted, function(a, b)
    if not a.value or not b.value then return false end
    return libfs.sort(store[a.value], store[b.value])
  end)
  return sorted
end

---@private
---@param inst fyler.Finder
---@param callback fun(node: fyler.FinderStateNode, depth: integer)
---@param opts { skip_hidden: boolean|nil, target_path: string|nil }|nil
H.tree_walk = function(inst, callback, opts)
  opts = opts or {}

  local target_path = opts.target_path
  if target_path then
    local relative = libpath.to_rel(inst.state.pseudo_root_path, target_path)
    if not relative or relative == '' then return end

    if target_path == inst.state.pseudo_root_path then
      callback(inst.state.root, 0)
      return
    end

    local segments = libpath.do_split(relative)
    local node = inst.state.root
    for _, segment in ipairs(segments) do
      if not node.children[segment] then node.children[segment] = { children = {} } end
      node = node.children[segment]
    end
    callback(node, #segments)
    return
  end

  local function rec(node, depth)
    if not node.value then return end
    if opts.skip_hidden and libfs.is_hidden(store[node.value].full_path, inst.cache.ui.hidden_items) then return end
    callback(node, depth)
    local meta = inst.state.fs_meta[libpath.to_key(store[node.value].full_path)]
    if meta and meta.expanded then
      for _, child in ipairs(H.sorted_children(node)) do
        rec(child, depth + 1)
      end
    end
  end

  if inst.state.root.value then
    local root_meta = inst.state.fs_meta[libpath.to_key(store[inst.state.root.value].full_path)]
    if root_meta and root_meta.expanded then
      for _, child in ipairs(H.sorted_children(inst.state.root)) do
        rec(child, 0)
      end
    end
  end
end

---@private
---@param inst fyler.Finder
---@return string
---@nodiscard
H.buffer_name = function(inst)
  local scheme_name = inst.opts.scheme
  local pseudo_root_path = inst.state.pseudo_root_path
  return ('fyler-%s://%s'):format(scheme_name, pseudo_root_path)
end

---@return integer
---@nodiscard
H.calculate_view_lines = function()
  return vim.o.lines - (vim.o.showtabline > 0 and 1 or 0) - (vim.o.laststatus > 0 and 1 or 0) - vim.o.cmdheight
end

---@private
---@param dimension integer|string
---@param reference integer
---@return integer
---@nodiscard
H.normalize_dimension = function(dimension, reference)
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
H.normalize_offset = function(offset, dimension, reference)
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
H.window_focus = function(win_id) vim.api.nvim_set_current_win(win_id) end

---@private
---@param window_config fyler.WindowConfig
---@return vim.api.keyset.win_config|nil
---@nodiscard
H.window_get_config = function(window_config)
  local win_config = {}

  if window_config.kind == 'replace' then return end

  local has_border = (window_config.kind == 'floating' and window_config.border ~= 'none')
  local has_tabline = vim.o.showtabline > 0
  local view_lines = H.calculate_view_lines()

  if window_config.width then win_config.width = H.normalize_dimension(window_config.width, vim.o.columns) end
  if window_config.height then
    win_config.height = H.normalize_dimension(window_config.height, view_lines) - (has_border and 2 or 0)
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
      win_config.col = H.normalize_offset(window_config.col, win_config.width, vim.o.columns)
    end
    if window_config.row and win_config.height then
      win_config.row = math.max(0, H.normalize_offset(window_config.row, win_config.height, view_lines) - 2)
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
---@param window_config fyler.WindowConfig
H.window_resize = function(win_id, window_config)
  if not util.win_valid(win_id) then return end
  local win_config = H.window_get_config(window_config)
  if win_config then pcall(vim.api.nvim_win_set_config, win_id, win_config) end
end

---@param opts table|nil
---@return fyler.FinderOpts
---@nodiscard
H.normalize_opts = function(opts)
  opts = opts or {}
  opts.root_path = libpath.to_normalize(opts.root_path or vim.fn.getcwd(-1, -1))
  opts.scheme = opts.scheme or 'file'
  return config.get_config(opts)
end

---@private
---@param inst fyler.Finder
---@return table
---@nodiscard
H.state_flatten = function(inst)
  local result = {}
  H.tree_walk(inst, function(node, depth)
    local entry = store[node.value]
    local item = {
      id = entry.id,
      full_path = entry.full_path,
      name = entry.name,
      type = entry.type,
      depth = depth,
    }
    if entry.type == 'directory' then
      local meta = inst.state.fs_meta[libpath.to_key(entry.full_path)]
      item.expanded = meta and meta.expanded or false
    end
    table.insert(result, item)
  end)
  return result
end

---@private
---@param inst fyler.Finder
---@param path string
---@param expanded boolean|nil
H.state_toggle_expanded = function(inst, path, expanded)
  path = libpath.to_key(path)
  if not inst.state.fs_meta[path] then inst.state.fs_meta[path] = { expanded = false } end
  inst.state.fs_meta[path].expanded = not expanded and not inst.state.fs_meta[path].expanded or (expanded or false)
end

---@private
---@return table, integer
H.build_fs_entry_ui = function(item)
  local state = item.type == 'directory' and { expanded = item.expanded } or nil
  local icon_char, icon_hl = icon.get(item.type, item.full_path, state)
  local indent = item.depth > 0 and string.rep('  ', item.depth) or ''
  local id_part = string.format('/%0' .. math.ceil(math.log10(next_id)) .. 'd ', item.id)
  local children = {}
  local name_col = 0
  if #indent > 0 then
    table.insert(children, { tag = 'text', value = indent })
    name_col = name_col + #indent
  end
  if icon_char and #icon_char > 0 then
    table.insert(children, { tag = 'text', value = icon_char, hl = icon_hl })
    table.insert(children, { tag = 'text', value = ' ' })
    name_col = name_col + #icon_char + 1
  end
  table.insert(children, { tag = 'text', value = id_part })
  name_col = name_col + #id_part
  table.insert(children, {
    tag = 'text',
    value = item.name,
    hl = item.type == 'directory' and 'FylerDirectoryName' or 'FylerNormal',
  })
  return children, name_col
end

---@private
---@return table, integer, table
H.render_tree = function(inst, flat)
  local visible = {}
  local rows = {}
  for _, item in ipairs(flat) do
    if not libfs.is_hidden(item.full_path, inst.cache.ui.hidden_items) then
      local children, name_col = H.build_fs_entry_ui(item)
      item._name_col = name_col
      visible[#visible + 1] = item
      rows[#rows + 1] = { tag = 'row', children = children }
    end
  end

  local Files = libui.compose({ tag = 'col', children = rows })
  local buf_undolevels = vim.bo.undolevels
  vim.bo.undolevels = -1
  vim.api.nvim_buf_set_lines(inst.buf_id, 0, -1, false, Files.lines)
  vim.bo.undolevels = buf_undolevels

  local hl_ns = vim.api.nvim_create_namespace('FylerFinderBuf' .. inst.buf_id)
  vim.api.nvim_buf_clear_namespace(inst.buf_id, hl_ns, 0, -1)

  for _, hl in ipairs(Files.highlights) do
    vim.api.nvim_buf_set_extmark(inst.buf_id, hl_ns, hl.start_row, hl.start_col, {
      hl_group = hl.hl_group,
      end_row = hl.end_row,
      end_col = hl.end_col,
      hl_mode = 'combine',
    })
  end

  for _, em in ipairs(Files.extmarks) do
    pcall(vim.api.nvim_buf_set_extmark, inst.buf_id, hl_ns, em.row, em.col, em.opts)
  end

  vim.bo[inst.buf_id].modified = false
  vim.bo[inst.buf_id].syntax = 'fyler_finder'

  return visible, hl_ns, Files.lines
end

---@private
local finish_refresh = function(inst)
  inst._is_refreshing = false
  inst._refresh_count = (inst._refresh_count or 0) + 1
  if type(inst._refresh_again_with_args) == 'table' then
    local saved = inst._refresh_again_with_args
    inst._refresh_again_with_args = nil
    inst:refresh(saved)
  end
end

---@private
---@param inst fyler.Finder
---@param args fyler.StateUpdateOpts|nil
H.state_update = function(inst, args)
  args = args or {}

  local target_path = args.target_path or inst.state.pseudo_root_path

  local cache_entry = inst.state.fs_meta[libpath.to_key(target_path)]
  if not (cache_entry and cache_entry.expanded) then return end

  local handle_scan = function(node)
    inst.state.scheme.fs_scan_dir(target_path, function(err, entries)
      if not entries or err then
        if args.callback then vim.schedule(args.callback) end
        if err then vim.schedule_wrap(vim.notify)(err, vim.log.levels.ERROR, { title = 'Fyler.nvim' }) end
        return
      end

      local expanded = {}
      node.children = {}

      for _, entry in ipairs(entries) do
        entry.full_path = libpath.do_join(target_path, entry.name)

        local existing_id = path_to_id[libpath.to_key(entry.full_path)]
        if existing_id then
          entry.id = existing_id
          store[existing_id] = entry
          node.children[entry.name] = { children = {}, value = existing_id }
        else
          node.children[entry.name] = { children = {}, value = store_register(entry) }
        end

        local meta = inst.state.fs_meta[libpath.to_key(entry.full_path)]
        if meta and meta.expanded then expanded[#expanded + 1] = entry.name end
      end

      if #expanded == 0 then
        if args.callback then vim.schedule(args.callback) end
        return
      end

      local pending = #expanded
      local done = 0

      for _, name in ipairs(expanded) do
        local child_node = node.children[name]
        local child_path = child_node.value and store[child_node.value].full_path
        H.state_update(inst, {
          target_path = child_path,
          target_node = child_node,
          callback = function()
            done = done + 1
            if done == pending and args.callback then vim.schedule(args.callback) end
          end,
        })
      end
    end)
  end

  if args.target_node then
    handle_scan(args.target_node)
  else
    H.tree_walk(inst, function(node)
      if node then handle_scan(node) end
    end, { target_path = target_path })
  end
end

---@class fyler.Finder
local Finder = {}

function Finder:close()
  if not util.win_valid(self.win_id) then return end
  pcall(vim.api.nvim_win_close, self.win_id, true)
  pcall(vim.api.nvim_win_call, self.win_id, function()
    if not util.win_valid(self.win_id) then return end
    pcall(vim.api.nvim_buf_delete, self.buf_id, { force = true })
  end)
  self.win_id = nil
  self._refresh_count = nil
  if #vim.fn.win_findbuf(self.buf_id) == 0 then pcall(vim.api.nvim_buf_delete, self.buf_id, { force = true }) end
  vim.cmd.tcd({ args = { vim.fn.fnameescape(vim.fn.getcwd(-1, -1)) }, mods = { silent = true } })
end

---@param args { target_path: string|nil }|nil
function Finder:follow(args)
  args = args or {}

  local raw_path = libpath.to_normalize(args.target_path)
  if not (raw_path and vim.uv.fs_stat(libpath.to_rel(self.state.pseudo_root_path, raw_path))) then
    if not self._refresh_count then self:refresh() end
    return
  end

  local target_path = libpath.to_abs(raw_path)
  local root_path = self.state.pseudo_root_path

  if target_path == root_path then
    if not self._refresh_count then self:refresh() end
    return
  end

  local expand_target = target_path
  if not self.state.scheme.fs_is_dir(target_path) then expand_target = vim.fs.dirname(target_path) end

  local relative = libpath.to_rel(root_path, expand_target)
  if not relative or #relative == 0 then
    if not self._refresh_count then self:refresh() end
    return
  end

  local accumulated = root_path
  for _, segment in ipairs(libpath.do_split(relative)) do
    accumulated = libpath.do_join(accumulated, segment)
    H.state_toggle_expanded(self, accumulated, true)
  end

  self:refresh({
    callback = function()
      if not util.win_valid(self.win_id) then return end
      vim.api.nvim_win_call(self.win_id, function()
        local id = path_to_id[libpath.to_key(target_path)]
        if not id then return end
        vim.fn.search(('/%0' .. math.ceil(math.log10(next_id)) .. 'd '):format(id))
      end)
    end,
  })
end

---@class fyler.Action
---@field name 'create'|'delete'|'move'|'copy'
---@field src string|nil
---@field dst string|nil

---@param inst fyler.Finder
---@param id_to_path table<integer, string>
---@param buf_lines string[]
---@return fyler.Action[], string[]
H.compute_fs_actions = function(inst, id_to_path, buf_lines)
  local seen_ids = {}
  local stack = { { path = inst.state.pseudo_root_path, depth = -1 } }

  local fs_actions = {}
  local transitions = {}
  local errors = {}
  vim.iter(buf_lines):each(function(buf_line)
    local id, name, depth, is_dir = parse_buf_line(buf_line)
    while #stack > 1 and stack[#stack].depth >= depth do
      table.remove(stack)
    end

    local parent_path = stack[#stack].path
    local full_path = libpath.do_join(parent_path, name)
    if id then
      transitions[id] = transitions[id] or {}
      table.insert(transitions[id], full_path)
      seen_ids[id] = true
      if is_dir then
        table.insert(stack, { path = full_path:sub(1, -2), depth = depth })
      elseif store[id] and store[id].type == 'directory' then
        table.insert(stack, { path = store[id].full_path, depth = depth })
      end
    else
      local segments = libpath.do_split(name)
      local current_path = parent_path
      for j = 1, #segments do
        local segment = segments[j]
        local is_last = j == #segments
        local segment_path = libpath.do_join(current_path, segment)
        if is_last then
          table.insert(fs_actions, { name = 'create', dst = segment_path .. (is_dir and '/' or '') })
        else
          table.insert(fs_actions, { name = 'create', dst = segment_path .. '/' })
          current_path = segment_path .. '/'
        end
      end
      if is_dir then table.insert(stack, { path = libpath.do_join(parent_path, name), depth = depth }) end
    end
  end)

  for id, path in pairs(id_to_path) do
    if not seen_ids[id] then table.insert(fs_actions, { name = 'delete', src = path }) end
  end

  for id, transition in pairs(transitions) do
    local keep_original = vim.tbl_contains(transition, id_to_path[id])
    for i, new_path in ipairs(transition) do
      if new_path ~= id_to_path[id] then
        if keep_original or i < #transition then
          table.insert(fs_actions, { name = 'copy', src = id_to_path[id], dst = new_path })
        else
          table.insert(fs_actions, { name = 'move', src = id_to_path[id], dst = new_path })
        end
      end
    end
  end

  local seen = {}
  fs_actions = vim
    .iter(fs_actions)
    :filter(function(fs_action)
      if seen[build_fs_action_id(fs_action)] then return false end
      seen[build_fs_action_id(fs_action)] = true
      return true
    end)
    :totable()

  return fs_actions, errors
end

---@private
---@param order integer[]
---@param fs_actions fyler.Action[]
---@param pseudo_root_path string
---@return table, table
H.build_action_confirmation_ui = function(order, fs_actions, pseudo_root_path)
  local action_name_components = {}
  local action_args_components = {}
  for _, i in ipairs(order) do
    local fs_action = fs_actions[i]
    local action_hl
    if fs_action.name == 'create' or fs_action.name == 'delete' or fs_action.name == 'trash' then
      action_hl = 'DiagnosticInfo'
    elseif fs_action.name == 'move' then
      action_hl = 'DiagnosticWarn'
    elseif fs_action.name == 'copy' then
      action_hl = 'DiagnosticHint'
    end

    local args_row
    if fs_action.name == 'delete' or fs_action.name == 'trash' then
      args_row = { tag = 'text', value = libpath.to_rel(pseudo_root_path, fs_action.src), hl = 'Comment' }
    elseif fs_action.name == 'create' then
      args_row = { tag = 'text', value = libpath.to_rel(pseudo_root_path, fs_action.dst) }
    else
      local src_rel = libpath.to_rel(pseudo_root_path, fs_action.src or '')
      local dst_rel = libpath.to_rel(pseudo_root_path, fs_action.dst)
      args_row = {
        tag = 'row',
        children = {
          { tag = 'text', value = src_rel, hl = 'Comment' },
          { tag = 'text', value = ' -> ' },
          { tag = 'text', value = dst_rel },
        },
      }
    end
    table.insert(action_name_components, {
      tag = 'text',
      value = fs_action.name:gsub('^%l', string.upper),
      hl = action_hl,
    })
    table.insert(action_args_components, args_row)
  end
  local composed = libui.compose({
    tag = 'col',
    children = {
      {
        tag = 'row',
        children = {
          { tag = 'col', children = action_name_components },
          {
            tag = 'col',
            children = vim
              .iter(order)
              :map(function() return { tag = 'text', value = ' │ ', hl = 'FloatBorder' } end)
              :totable(),
          },
          { tag = 'col', children = action_args_components },
        },
      },
    },
  })
  return composed.lines, composed.highlights
end

---@private
---@param left fyler.Action
---@param right fyler.Action
---@param edge_add fun(u: fyler.Action, v: fyler.Action)
---@param errors string[]
H.handle_action_pair = function(left, right, edge_add, errors)
  if build_fs_action_id(left) == build_fs_action_id(right) then return end
  if build_fs_action_id(left) > build_fs_action_id(right) then return end

  local P = { create = 1, delete = 2, copy = 3, move = 4 }
  local function sorted_pair()
    if P[left.name] < P[right.name] then return left, right end
    return right, left
  end

  local first, second = sorted_pair()
  if first.name == 'create' and second.name == 'delete' then
    edge_add(first, second)
  elseif first.name == 'create' and second.name == 'copy' then
    if first.dst == second.src or first.dst == second.dst then
      table.insert(errors, ('Conflict: create %s clashes with copy %s -> %s'):format(first.dst, second.src, second.dst))
    end
  elseif first.name == 'create' and second.name == 'move' then
    if first.dst == second.dst then
      table.insert(errors, ('Conflict: create %s clashes with move %s -> %s'):format(first.dst, second.src, second.dst))
    else
      edge_add(first, second)
    end
  elseif first.name == 'delete' and second.name == 'copy' then
    if first.src == second.src or first.src == second.dst then
      table.insert(errors, ('Conflict: delete %s clashes with copy %s -> %s'):format(first.src, second.src, second.dst))
    end
  elseif first.name == 'delete' and second.name == 'move' then
    if first.src == second.dst then
      table.insert(errors, ('Conflict: delete %s clashes with move %s -> %s'):format(first.src, second.src, second.dst))
    else
      edge_add(first, second)
    end
  elseif first.name == 'copy' and second.name == 'move' then
    if first.dst == second.dst then
      table.insert(
        errors,
        ('Conflict: copy %s -> %s clashes with move %s -> %s'):format(first.src, first.dst, second.src, second.dst)
      )
    else
      edge_add(second, first)
    end
  elseif first.name == 'create' and second.name == 'create' then
    if first.dst == second.dst then table.insert(errors, ('Conflict: create %s appears twice'):format(first.dst)) end
  elseif first.name == 'delete' and second.name == 'delete' then
    if first.src == second.src then table.insert(errors, ('Conflict: delete %s appears twice'):format(first.src)) end
  elseif first.name == 'copy' and second.name == 'copy' then
    if first.dst == second.dst then
      table.insert(
        errors,
        ('Conflict: copy %s -> %s clashes with copy %s -> %s'):format(first.src, first.dst, second.src, second.dst)
      )
    end
  elseif first.name == 'move' and second.name == 'move' then
    if first.dst == second.dst or first.src == second.src then
      table.insert(
        errors,
        ('Conflict: move %s -> %s clashes with move %s -> %s'):format(first.src, first.dst, second.src, second.dst)
      )
    elseif first.dst == second.src then
      edge_add(first, second)
    end
    if second.dst == first.src then edge_add(second, first) end
  end
end

---@param fs_actions fyler.Action[]
---@param pseudo_root_path string
---@param errors string[]
---@return table
---@return table
H.build_action_dependency_graph = function(fs_actions, pseudo_root_path, errors)
  local trie_root = { children = {} }

  vim.iter(fs_actions):each(function(action)
    local splitted_path =
      libpath.do_split(libpath.to_rel(pseudo_root_path, action.name == 'create' and action.dst or action.src))
    local current_node = trie_root
    for i = 1, #splitted_path do
      if not current_node.children[splitted_path[i]] then
        current_node.children[splitted_path[i]] = { children = {} }
      end
      current_node = current_node.children[splitted_path[i]]
    end
    current_node.value = current_node.value or {}
    table.insert(current_node.value, action)
  end)

  local fs_action_indicies = {}
  for i, fs_action in ipairs(fs_actions) do
    local action_key = build_fs_action_id(fs_action)
    if not fs_action_indicies[action_key] then fs_action_indicies[action_key] = i end
  end

  local graph = {}
  local in_degree = {}
  for i = 1, #fs_actions do
    graph[i] = {}
    in_degree[i] = 0
  end

  local edge_add = function(u, v)
    local u_index = fs_action_indicies[build_fs_action_id(u)]
    local v_index = fs_action_indicies[build_fs_action_id(v)]
    table.insert(graph[v_index], u_index)
    in_degree[u_index] = in_degree[u_index] + 1
  end

  local queue = { trie_root }
  local fs_action_parents = {}
  while #queue > 0 do
    local current_node = table.remove(queue, 1)

    local fs_action_siblings = {}
    for _, child in pairs(current_node.children) do
      vim.list_extend(fs_action_siblings, child.value or {})
    end

    vim.iter(fs_action_siblings):each(function(sibling)
      vim.iter(fs_action_parents):each(function(parent)
        if parent.name == 'create' then
          edge_add(sibling, parent)
        else
          edge_add(parent, sibling)
        end
      end)
    end)

    vim.iter(fs_action_siblings):each(function(sr)
      vim.iter(fs_action_siblings):each(function(sl) H.handle_action_pair(sl, sr, edge_add, errors) end)
    end)

    for _, child in pairs(current_node.children) do
      table.insert(queue, child)
    end

    vim.list_extend(fs_action_parents, fs_action_siblings)
  end

  return graph, in_degree
end

function Finder:mutate()
  if not vim.api.nvim_get_option_value('modified', { buf = self.buf_id }) then return end

  local id_to_path = {}
  H.tree_walk(self, function(node) id_to_path[node.value] = store[node.value].full_path end, { skip_hidden = true })

  local buf_lines = vim
    .iter(vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false))
    :filter(function(buf_line) return #buf_line > 0 end)
    :totable()

  local fs_actions, errors = H.compute_fs_actions(self, id_to_path, buf_lines)
  local graph, in_degree = H.build_action_dependency_graph(fs_actions, self.state.pseudo_root_path, errors)

  local queue = {}
  for i = 1, #fs_actions do
    if in_degree[i] == 0 then table.insert(queue, i) end
  end

  local order = {}
  while #queue > 0 do
    local u = table.remove(queue, 1)
    table.insert(order, u)
    for _, v in ipairs(graph[u] or {}) do
      in_degree[v] = in_degree[v] - 1
      if in_degree[v] == 0 then table.insert(queue, v) end
    end
  end

  if #order < #fs_actions then
    local cycled = {}
    for i = 1, #fs_actions do
      if in_degree[i] > 0 then table.insert(cycled, i) end
    end

    local resolved = false
    if #cycled == 2 then
      local a1, a2 = fs_actions[cycled[1]], fs_actions[cycled[2]]
      if a1.name == 'move' and a2.name == 'move' and a1.src == a2.dst and a1.dst == a2.src then
        resolved = true
        local tmp = a1.src .. '.fyler_tmp'
        table.insert(fs_actions, { name = 'move', src = a1.src, dst = tmp })
        table.insert(fs_actions, { name = 'move', src = a2.src, dst = a1.src })
        table.insert(fs_actions, { name = 'move', src = tmp, dst = a1.dst })
        vim.list_extend(order, { #fs_actions - 2, #fs_actions - 1, #fs_actions })
      end
    end

    if not resolved then
      for _, i in ipairs(cycled) do
        local action = fs_actions[i]
        table.insert(errors, ('Cycle detected: %s %s -> %s'):format(action.name, action.src or '', action.dst or ''))
      end
    end
  end

  if #errors > 0 then
    vim.notify(table.concat(errors, '\n'), vim.log.levels.ERROR)
    return
  end

  if #order == 0 then
    util.set_buf_option(self.buf_id, 'modified', false)
    return
  end

  extensions.run_hook('finder_mutate_pre', fs_actions)

  local action_counts = { create = 0, delete = 0, move = 0, copy = 0, trash = 0 }
  for _, i in ipairs(order) do
    local a = fs_actions[i]
    action_counts[a.name] = action_counts[a.name] + 1
  end

  local is_simple = action_counts.copy <= 1
    and action_counts.delete <= 0
    and action_counts.trash <= 0
    and action_counts.move <= 1
    and action_counts.create <= 5

  local do_execute = function()
    local ordered_actions = vim.iter(order):map(function(i) return fs_actions[i] end):totable()
    local function execute()
      self.state.scheme.fs_mutate(ordered_actions, function(err)
        vim.schedule(function()
          if err then
            vim.notify('Failed to apply changes: ' .. err, vim.log.levels.ERROR)
            return
          end

          util.set_buf_option(self.buf_id, 'modified', false)

          local cursor_target = nil
          for i = #ordered_actions, 1, -1 do
            local action = ordered_actions[i]
            if not (action.name == 'delete' or action.name == 'trash') then
              cursor_target = action.dst
              break
            end
          end
          if cursor_target then
            self:follow({ target_path = cursor_target })
          else
            self:refresh()
          end
          local hooks = config.DATA.hooks
          for _, action in ipairs(ordered_actions) do
            if action.name == 'delete' then
              vim.schedule_wrap(hooks.on_delete)(action.src)
            elseif action.name == 'move' then
              vim.schedule_wrap(hooks.on_rename)(action.src, action.dst)
            end
          end
        end)
      end)
    end

    local done = util.once_all(extensions.hook_count('finder_execute_pre'), execute)
    extensions.run_hook('finder_execute_pre', ordered_actions, done)
  end

  if config.DATA.auto_confirm_simple_mutation and is_simple then
    do_execute()
  else
    local lines, highlights = H.build_action_confirmation_ui(order, fs_actions, self.state.pseudo_root_path)
    vim.schedule_wrap(input.get_confirmation)(lines, highlights, function(confirmed)
      if confirmed then do_execute() end
    end)
  end
end

function Finder:open()
  if util.win_valid(self.win_id) then
    H.window_focus(self.win_id)
    return
  end

  local win_config = H.window_get_config(self.opts)

  local buf_name = H.buffer_name(self)
  self.buf_id = vim.fn.bufnr('^' .. buf_name, '$')

  if not util.buf_valid(self.buf_id) then
    self.buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(self.buf_id, buf_name)
  end

  if win_config then
    self.win_id = vim.api.nvim_open_win(self.buf_id, true, win_config)
  else
    self.win_id = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.win_id, self.buf_id)
  end

  util.set_win_option(self.win_id, 'cursorline', false)
  util.set_win_option(self.win_id, 'number', false)
  util.set_win_option(self.win_id, 'relativenumber', false)

  for name, value in pairs(self.opts.buf_opts or {}) do
    util.set_buf_option(self.buf_id, name, value)
  end

  for name, value in pairs(self.opts.win_opts or {}) do
    util.set_win_option(self.win_id, name, value)
  end

  util.set_buf_option(self.buf_id, 'buftype', 'acwrite')
  util.set_buf_option(self.buf_id, 'expandtab', true)
  util.set_buf_option(self.buf_id, 'filetype', 'fyler_finder')
  util.set_buf_option(self.buf_id, 'shiftwidth', 2)
  util.set_buf_option(self.buf_id, 'syntax', 'fyler_finder')

  util.set_win_option(self.win_id, 'concealcursor', 'nvic')
  util.set_win_option(self.win_id, 'conceallevel', 3)
  util.set_win_option(self.win_id, 'signcolumn', 'yes')
  util.set_win_option(self.win_id, 'winfixheight', true)
  util.set_win_option(self.win_id, 'winfixwidth', true)
  util.set_win_option(self.win_id, 'wrap', false)

  for mode, keys in pairs(self.opts.mappings or {}) do
    for key, mapping in pairs(keys) do
      if type(mapping) == 'table' and not mapping.disabled then
        mapping.opts = vim.tbl_deep_extend(
          'force',
          { noremap = true, nowait = true, silent = true },
          mapping.opts or {},
          { buffer = self.buf_id }
        )
        if type(mapping.action) == 'function' then
          vim.keymap.set(mode, key, function() mapping.action(self, mapping.args) end, mapping.opts)
        elseif type(mapping.action) == 'string' then
          local action = self[mapping.action]
          if action then vim.keymap.set(mode, key, function() action(self, mapping.args) end, mapping.opts) end
        end
      end
    end
  end

  local ag = vim.api.nvim_create_augroup('FylerFinderBuf' .. self.buf_id, { clear = true })
  local au = function(event, callback, desc)
    vim.api.nvim_create_autocmd(event, { group = ag, buffer = self.buf_id, callback = callback, desc = desc })
  end

  au('BufReadCmd', function() self:refresh() end, 'Ensure buffer reloads')
  au('BufWriteCmd', function() self:mutate() end, 'Ensure buffer saves')
  au('VimResized', function() self:resize() end, 'Ensure resize')

  if self.opts.bound_cursor then
    au('CursorMoved', function()
      if not util.win_valid(self.win_id) then return end
      local line = vim.api.nvim_get_current_line()
      local _, id_end = line:find('/%d+ ')
      if not id_end then return end
      local pos = vim.api.nvim_win_get_cursor(self.win_id)
      if pos[2] < id_end then vim.api.nvim_win_set_cursor(self.win_id, { pos[1], id_end }) end
    end, 'Ensure cursor boundary')
  end

  vim.cmd.tcd({ args = { vim.fn.fnameescape(self.opts.root_path) }, mods = { silent = true } })
  local target_path = vim.fn.bufname('#')
  if #target_path > 0 and self.opts.follow_current_file then
    self:follow({ target_path = target_path })
  else
    self:refresh()
  end
end

---@param args { callback: function|nil }|nil
function Finder:refresh(args)
  if self._is_refreshing then
    self._refresh_again_with_args = args
    return
  end
  self._is_refreshing = true

  args = args or {}

  local target_path = self.state.pseudo_root_path
  local callback = vim.schedule_wrap(function()
    local flat = H.state_flatten(self)
    local visible, hl_ns, lines = H.render_tree(self, flat)
    if args.callback then args.callback() end

    local done = util.once_all(extensions.hook_count('finder_refresh_post'), function() finish_refresh(self) end)
    extensions.run_hook('finder_refresh_post', self, visible, hl_ns, lines, done)
  end)

  H.state_update(self, { target_path = target_path, callback = callback })
end

function Finder:resize() H.window_resize(self.win_id, self.opts) end

---@param args { close: boolean|nil, tabedit: boolean|nil, split: boolean|nil, vsplit: boolean|nil }|nil
function Finder:select(args)
  args = args or {}

  local node_data = M.parse_cursor_line(self)
  if not node_data then return end
  if node_data.type == 'link' then
    vim.notify('BROKEN SYMLINK: ' .. node_data.full_path, vim.log.levels.WARN)
  elseif node_data.type == 'directory' then
    H.state_toggle_expanded(self, node_data.full_path)
    self:refresh()
  else
    local edit = not (args.split or args.vsplit or args.tabedit)
    ---@return boolean
    local function get_should_close()
      if args.close then return true end
      if self.opts.kind == 'floating' then return not args.tabedit end
      if self.opts.kind == 'replace' then return edit end
      return false
    end
    local should_close = get_should_close()
    if should_close then self:close() end

    local os_path = libpath.to_os(libpath.to_abs(node_data.link_target or node_data.full_path))
    local should_goto_suitable_window = not (should_close or self.opts.kind == 'replace')
    if should_goto_suitable_window then M.window_goto_suitable(self, os_path) end

    local splitright = vim.o.splitright
    local splitbelow = vim.o.splitbelow
    vim.o.splitright = true
    vim.o.splitbelow = true

    vim.cmd[args.tabedit and 'tabedit' or args.split and 'split' or args.vsplit and 'vsplit' or 'edit']({
      args = { vim.fn.fnameescape(os_path) },
      mods = { keepalt = args.split or args.vsplit },
    })

    vim.o.splitright = splitright
    vim.o.splitbelow = splitbelow
  end
end

---@param args { parent: boolean|nil }|nil
function Finder:shrink(args)
  args = args or {}

  local node_data = M.parse_cursor_line(self)
  if not node_data then return end

  if args.parent then
    local parent_path = vim.fs.dirname(node_data.full_path)
    if parent_path == self.state.pseudo_root_path then return end

    local parent_node
    H.tree_walk(self, function(node) parent_node = node end, { target_path = parent_path })

    H.state_toggle_expanded(self, parent_path, false)

    self:refresh({
      callback = function()
        if not util.win_valid(self.win_id) then return end
        vim.api.nvim_win_call(self.win_id, function()
          if parent_node and parent_node.value then
            local id_width = #tostring(next_id - 1)
            vim.fn.search(('/%0' .. id_width .. 'd '):format(parent_node.value))
          end
        end)
      end,
    })
  else
    H.state_toggle_expanded(self, node_data.full_path, false)
    self:refresh()
  end
end

function Finder:toggle()
  if util.win_valid(self.win_id) then
    self:close()
    return
  end

  self:open()
end

---@param args string[]
function Finder:toggle_ui(args)
  vim.iter(args):each(function(arg)
    if arg == 'indent_guides' then
      self.cache.ui.indent_guides = not self.cache.ui.indent_guides
    elseif arg == 'hidden_items' then
      local function toggle_dict(dict)
        for k, v in pairs(dict) do
          dict[k] = not v
        end
      end
      toggle_dict(self.cache.ui.hidden_items.switches)
      toggle_dict(self.cache.ui.hidden_items.patterns)
    end
  end)

  self:refresh()
end

---@param args { parent: boolean|nil, cursor: boolean|nil, path: string|nil }|nil
function Finder:visit(args)
  args = args or {}

  if args.parent then
    args.path = vim.fs.dirname(self.state.pseudo_root_path)
  elseif args.cursor then
    local node_data = M.parse_cursor_line(self)
    if not (node_data and node_data.type == 'directory') then return end
    args.path = node_data.full_path
  else
    args.path = args.path or self.state.root_path
  end

  if self.state.pseudo_root_path == args.path then return end

  -- NOTE: We need to delete the old buffer because
  -- renaming the buffer creates another buffer (don't know why?)
  local old_buf_name = H.buffer_name(self)
  self.state.pseudo_root_path = args.path
  H.state_toggle_expanded(self, args.path, true)
  vim.cmd.tcd({ args = { vim.fn.fnameescape(args.path) }, mods = { silent = true } })
  vim.api.nvim_buf_set_name(self.buf_id, H.buffer_name(self))
  local old_buf_id = vim.fn.bufnr('^' .. old_buf_name .. '$')
  if util.buf_valid(old_buf_id) then vim.api.nvim_buf_delete(old_buf_id, { force = true }) end
  self:refresh()
end

---@param opts fyler.FinderOpts
---@return fyler.Finder
local new_instance = function(opts)
  return setmetatable({
    cache = {
      ui = {
        indent_guides = opts.ui.indent_guides,
        hidden_items = vim.tbl_deep_extend('force', opts.ui.hidden_items, {
          switches = util.list_to_dict(opts.ui.hidden_items.switches),
          patterns = util.list_to_dict(opts.ui.hidden_items.patterns),
        }),
      },
    },
    opts = opts,
    state = {
      fs_meta = { [libpath.to_key(opts.root_path)] = { expanded = true } },
      pseudo_root_path = opts.root_path,
      root_path = opts.root_path,
      root = {
        children = {},
        value = store_register({
          full_path = opts.root_path,
          name = vim.fs.basename(opts.root_path),
          type = 'directory',
        }),
      },
      scheme = Fyler.import(('fyler.schemes.%s'):format(opts.scheme)),
    },
  }, { __index = Finder })
end

M.instance_get = function(tab_id, opts)
  tab_id = tab_id or vim.api.nvim_get_current_tabpage()
  opts = H.normalize_opts(opts)
  if instances[tab_id] and vim.deep_equal(instances[tab_id].opts, opts) then return instances[tab_id] end
  if instances[tab_id] then instances[tab_id]:close() end
  instances[tab_id] = new_instance(opts)
  return instances[tab_id]
end

---@param tab_id integer|nil
---@return fyler.Finder|nil
M.instance_get_or_nil = function(tab_id)
  tab_id = tab_id or vim.api.nvim_get_current_tabpage()
  local inst = instances[tab_id]
  if inst and util.win_valid(inst.win_id) and util.buf_valid(inst.buf_id) then return inst end
  return nil
end

---@private
---@param inst fyler.Finder
---@return fyler.FSEntry|nil
---@nodiscard
M.parse_cursor_line = function(inst)
  if not util.buf_valid(inst.buf_id) then return end
  local buf_line = vim.api.nvim_buf_call(inst.buf_id, function() return vim.api.nvim_get_current_line() end)
  local id = buf_line:match('(%d+)')
  if not id then return end
  local id_int = tonumber(id, 10)
  return store[id_int]
end

---@param tab_id integer
---@return integer|nil
M.window_get_prior = function(tab_id)
  local win_id = prior_windows[tab_id]
  if win_id and vim.api.nvim_win_is_valid(win_id) then return win_id end
  prior_windows[tab_id] = nil
  return nil
end

---@param inst fyler.Finder
---@param path string
M.window_goto_suitable = function(inst, path)
  local is_popup = function(winid)
    local win_config = vim.api.nvim_win_get_config(winid)
    return win_config and (#win_config.relative > 0 or win_config.external)
  end

  local is_suitable = function(winid)
    if is_popup(winid) then return false end
    local bufnr = vim.api.nvim_win_get_buf(winid)
    return vim.bo[bufnr].filetype ~= 'fyler_finder'
  end

  local bufnr = vim.fn.bufnr(path)
  local target_win = util.buf_valid(bufnr) and vim.fn.win_findbuf(bufnr)[1] or nil
  if target_win and is_suitable(target_win) then
    vim.api.nvim_set_current_win(target_win)
    return
  end

  local tab = vim.api.nvim_get_current_tabpage()
  local prior_win_id = M.window_get_prior(tab)
  if prior_win_id and vim.api.nvim_win_is_valid(prior_win_id) and is_suitable(prior_win_id) then
    vim.api.nvim_set_current_win(prior_win_id)
    return
  end

  local attempts = 0
  local initial_win = vim.api.nvim_get_current_win()
  while attempts < 5 do
    if is_suitable(vim.api.nvim_get_current_win()) then return end
    vim.cmd.wincmd('w')
    attempts = attempts + 1
  end

  vim.api.nvim_set_current_win(initial_win)

  local direction = (inst.opts.kind:match('^split_(%a+)') or ''):upper()
  if direction == 'ABOVE' then
    vim.api.nvim_command('rightbelow split')
  elseif direction == 'RIGHT' then
    vim.api.nvim_command('leftabove vsplit')
  elseif direction == 'BELOW' then
    vim.api.nvim_command('leftabove split')
  else
    vim.api.nvim_command('rightbelow vsplit')
  end

  H.window_resize(inst.win_id, inst.opts)
end

---@param tab_id integer
---@param win_id integer
M.window_set_prior = function(tab_id, win_id) prior_windows[tab_id] = win_id end

return M

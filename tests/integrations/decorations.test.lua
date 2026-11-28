local helper = require('tests.helper')
local n = helper.new_child_neovim()
local T = helper.new_set({ hooks = { pre_case = n.setup, post_once = n.stop } })

local eq = helper.expect.equality

local function register_sources(names, deferred, areas)
  n.lua_get(([[(function()
    local deferred = {}
    for _, name in ipairs(%s) do deferred[name] = true end
    local areas = %s
    _G.fyler_test_decorations = { contexts = {}, emits = {} }

    local extensions = require('fyler.extensions')
    for _, name in ipairs(%s) do
      extensions.register({
        name = name,
        decorations = {
          get_area = function() return areas[name] end,
          provide = function(ctx, emit)
            if deferred[name] then
              _G.fyler_test_decorations.contexts[name] = ctx
              _G.fyler_test_decorations.emits[name] = emit
              return
            end

            local cells = {}
            for _, item in ipairs(ctx.entries) do
              cells[item.id] = { chunks = { { name:sub(1, 1):upper(), 'Normal' } } }
            end
            return cells
          end,
        },
      })
    end
  end)()]]):format(vim.inspect(deferred or {}), vim.inspect(areas or {}), vim.inspect(names)))
end

local function setup_sources(names, ui, deferred, areas)
  register_sources(names, deferred, areas)
  local extensions = {}
  for _, name in ipairs(names) do
    extensions[name] = { enabled = true }
  end
  n.fwd_lua('require("fyler").setup')({
    use_as_default_explorer = false,
    extensions = extensions,
    ui = ui,
  })
end

local function open(tmpdir)
  n.fwd_lua('require("fyler").open')({ kind = 'replace', root_path = tmpdir, follow_current_file = false })
  vim.uv.sleep(30)
end

local function get_marks()
  vim.uv.sleep(30)
  return n.lua_get([[(function()
    local buf = vim.api.nvim_get_current_buf()
    local ns = vim.api.nvim_create_namespace('FylerDecorationsBuf' .. buf)
    return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  end)()]])
end

local function filter_marks(marks, kind)
  local filtered = {}
  for _, mark in ipairs(marks) do
    local details = mark[4]
    if kind == 'inline' and details.virt_text_pos == 'inline' then filtered[#filtered + 1] = mark end
    if kind == 'column' and details.virt_text_win_col then filtered[#filtered + 1] = mark end
  end
  table.sort(filtered, function(a, b) return a[2] < b[2] end)
  return filtered
end

local function mark_text(mark)
  return table.concat(vim.tbl_map(function(chunk) return chunk[1] end, mark[4].virt_text or {}))
end

T['uses lexicographical inline order by default'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a-file', 'b-file' })
  setup_sources({ 'zeta', 'alpha' }, {})
  open(tmpdir)

  local inline = filter_marks(get_marks(), 'inline')
  eq(#inline, 2)
  eq(mark_text(inline[1]), ' A Z')
  eq(mark_text(inline[2]), ' A Z')
end

T['renders all sources in the global area in lexicographical order'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a-file', 'b-file' })
  setup_sources({ 'alpha', 'beta', 'zeta' }, { decorations = { area = 'column_start' } })
  open(tmpdir)

  local marks = get_marks()
  local inline = filter_marks(marks, 'inline')
  local columns = filter_marks(marks, 'column')
  eq(#inline, 0)
  eq(#columns, 2)
  eq(mark_text(columns[1]), 'A B Z')
end

T['publishes async sources independently and rejects stale emissions'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a-file', 'b-file' })
  setup_sources({ 'fast', 'slow' }, {}, { 'slow' })
  open(tmpdir)

  local inline = filter_marks(get_marks(), 'inline')
  eq(#inline, 2)
  eq(mark_text(inline[1]), ' F')

  n.lua_get([[(function()
    _G.fyler_test_stale_emit = _G.fyler_test_decorations.emits.slow
    require('fyler.finder').instance_get_or_nil():refresh({ force = true })
    return true
  end)()]])
  vim.uv.sleep(30)
  n.lua_get([[(function()
    local cells = {}
    for _, item in ipairs(_G.fyler_test_decorations.contexts.slow.entries) do
      cells[item.id] = { chunks = { { 'S', 'Normal' } } }
    end
    _G.fyler_test_stale_emit(cells)
    return true
  end)()]])
  inline = filter_marks(get_marks(), 'inline')
  eq(mark_text(inline[1]), ' F')

  n.lua_get([[(function()
    local cells = {}
    for _, item in ipairs(_G.fyler_test_decorations.contexts.slow.entries) do
      cells[item.id] = { chunks = { { 'S', 'Normal' } } }
    end
    _G.fyler_test_decorations.emits.slow(cells)
    return true
  end)()]])
  inline = filter_marks(get_marks(), 'inline')
  eq(mark_text(inline[1]), ' F S')
end

T['pads shorter cells to the slot width'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a', 'long-name' })
  register_sources({ 'zeta' })
  n.lua_get([[(function()
    require('fyler.extensions').register({
      name = 'alpha',
      decorations = {
        provide = function(ctx)
          local cells = {}
          for _, item in ipairs(ctx.entries) do
            cells[item.id] = { chunks = { { item.name == 'a' and 'A' or 'LONG', 'Normal' } } }
          end
          return cells
        end,
      },
    })
    require('fyler').setup({
      use_as_default_explorer = false,
      extensions = { alpha = { enabled = true }, zeta = { enabled = true } },
      ui = { decorations = { area = 'column_start' } },
    })
  end)()]])
  open(tmpdir)

  local columns = filter_marks(get_marks(), 'column')
  eq(#columns, 2)
  eq(mark_text(columns[1]), 'A    Z')
  eq(mark_text(columns[2]), 'LONG Z')
  eq(columns[1][4].virt_text_win_col, 10)
end

T['keeps entry highlights when the column group is hidden'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a', 'long-name' })
  n.set_size(12, 12)
  n.lua_get([[(function()
    require('fyler.extensions').register({
      name = 'alpha',
      decorations = {
        provide = function(ctx)
          local cells = {}
          for _, item in ipairs(ctx.entries) do
            cells[item.id] = { chunks = { { 'A', 'Normal' } }, entry_hl = 'ErrorMsg' }
          end
          return cells
        end,
      },
    })
    require('fyler').setup({
      use_as_default_explorer = false,
      extensions = { alpha = { enabled = true } },
      ui = { decorations = { area = 'column_start' } },
    })
  end)()]])
  open(tmpdir)

  local marks = get_marks()
  eq(#filter_marks(marks, 'column'), 0)
  local highlighted_names = 0
  for _, mark in ipairs(marks) do
    if mark[4].hl_group == 'ErrorMsg' then highlighted_names = highlighted_names + 1 end
  end
  eq(highlighted_names, 2)
end

T['hides the complete column group when it cannot fit but keeps inline text'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a', 'long-name' })
  n.set_size(12, 50)
  setup_sources({ 'alpha', 'beta', 'zeta' }, { decorations = { area = 'column_end' } }, nil, { beta = 'inline' })
  open(tmpdir)

  local marks = get_marks()
  local columns = filter_marks(marks, 'column')
  eq(#columns, 2)
  eq(columns[1][4].virt_text_win_col, 45)

  n.set_size(12, 20)
  columns = filter_marks(get_marks(), 'column')
  eq(#columns, 2)
  eq(columns[1][4].virt_text_win_col, 15)

  n.set_size(12, 14)
  marks = get_marks()
  eq(#filter_marks(marks, 'column'), 0)
  eq(#filter_marks(marks, 'inline'), 2)
end

T['uses display width and visible text for column positioning'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a', '界' })
  n.lua_get([[(function()
    require('fyler.extensions').register({
      name = 'alpha',
      decorations = {
        get_area = function() return 'inline' end,
        provide = function(ctx)
          local cells = {}
          for _, item in ipairs(ctx.entries) do
            cells[item.id] = { chunks = { { item.name == 'a' and '界' or 'x', 'Normal' } } }
          end
          return cells
        end,
      },
    })
  end)()]])
  register_sources({ 'zeta' })
  n.fwd_lua('require("fyler").setup')({
    use_as_default_explorer = false,
    extensions = { alpha = { enabled = true }, zeta = { enabled = true } },
    ui = { decorations = { area = 'column_start' } },
  })
  open(tmpdir)

  local columns = filter_marks(get_marks(), 'column')
  eq(#columns, 2)
  eq(columns[1][4].virt_text_win_col, 5)
end

T['does nothing when decorations are disabled'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a-file' })
  setup_sources({ 'alpha' }, { decorations = { enabled = false, area = 'column_start' } })
  open(tmpdir)

  eq(#get_marks(), 0)
end

T['passes the resolved area to providers'] = function()
  local tmpdir = helper.get_tmpdir('decorations-data', { 'a-file' })
  n.lua_get([[(function()
    _G.fyler_test_resolved_area = {}
    local extensions = require('fyler.extensions')
    extensions.register({
      name = 'alpha',
      decorations = {
        get_area = function() return 'column' end,
        provide = function(ctx)
          _G.fyler_test_resolved_area.alpha = ctx.area
          local cells = {}
          for _, item in ipairs(ctx.entries) do
            cells[item.id] = { chunks = { { 'A', 'Normal' } } }
          end
          return cells
        end,
      },
    })
    extensions.register({
      name = 'beta',
      decorations = {
        provide = function(ctx)
          _G.fyler_test_resolved_area.beta = ctx.area
          local cells = {}
          for _, item in ipairs(ctx.entries) do
            cells[item.id] = { chunks = { { 'B', 'Normal' } } }
          end
          return cells
        end,
      },
    })
    require('fyler').setup({
      use_as_default_explorer = false,
      extensions = { alpha = { enabled = true }, beta = { enabled = true } },
      ui = { decorations = { area = 'inline' } },
    })
  end)()]])
  open(tmpdir)

  local resolved = n.lua_get('_G.fyler_test_resolved_area')
  eq(resolved.alpha, 'column')
  eq(resolved.beta, 'inline')
end

T['supports the legacy git inline option'] = function()
  local actual = n.lua_get([[(function()
    require('fyler').setup({
      use_as_default_explorer = false,
      extensions = { git = { enabled = true, inline = false } },
    })
    for _, source in ipairs(require('fyler.extensions').decoration_sources()) do
      if source.name == 'git' then
        return table.concat({
          source.get_area({ inline = false }),
          tostring(source.get_area({})),
          source.get_area({ inline = true }),
        }, ',')
      end
    end
  end)()]])
  eq(actual, 'column,nil,inline')
end

return T

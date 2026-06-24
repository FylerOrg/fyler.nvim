local MiniTest = require('mini.test')

local util = {}

function util.abspath(...) return util.normpath(vim.fn.fnamemodify(util.joinpath(...), ':p')) end

util.expect = MiniTest.expect
util.expect.match = MiniTest.new_expectation(
  'string matching',
  function(str, pattern) return str:find(pattern) ~= nil end,
  function(str, pattern) return string.format('Pattern: %s\nObserved string: "%s"', vim.inspect(pattern), str) end
)

function util.get_tmpdir(name, children)
  local get_testpath = function(...) return util.abspath(util.joinpath('tmp', ...)) end

  local temp_dir = get_testpath(name or 'data')
  vim.fn.mkdir(temp_dir, 'p')

  MiniTest.finally(function() vim.fn.delete(temp_dir, 'rf') end)

  for _, path in ipairs(children) do
    local path_ext = temp_dir .. '/' .. path
    if vim.endswith(path, '/') then
      vim.fn.mkdir(path_ext, 'p')
    else
      vim.fn.writefile({ 'ROOT/' .. path }, path_ext)
    end
  end

  return temp_dir
end

function util.is_windows() return vim.fn.has('win32') == 1 end
if util.is_windows() then
  function util.normpath(path) return (path:gsub('\\', '/'):gsub('(.)/$', '%1'):gsub('^(%a):/+([^/])', '%1:/%2')) end
else
  function util.normpath(path) return (path:gsub('\\', '/'):gsub('(.)/$', '%1')) end
end

function util.joinpath(...) return table.concat({ ... }, '/') end

function util.new_child_neovim()
  local child = MiniTest.new_child_neovim()

  function child.setup() child.restart({ '-u', 'tests/minimal_init.lua' }) end

  function child.set_size(lines, columns)
    if type(lines) == 'number' then child.o.lines = lines end
    if type(columns) == 'number' then child.o.columns = columns end
  end

  function child.fwd_lua(fun_str)
    local lua_cmd = fun_str .. '(...)'
    return function(...) return child.lua_get(lua_cmd, { ... }) end
  end

  function child.expect_screenshot(opts, path)
    opts = opts or {}
    local screenshot_opts = { redraw = opts.redraw }
    opts.redraw = nil
    MiniTest.expect.reference_screenshot(child.get_screenshot(screenshot_opts), path, opts)
  end

  return child
end

util.new_set = MiniTest.new_set

return util

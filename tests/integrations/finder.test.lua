local helper = require('tests.helper')
local n = helper.new_child_neovim()
local T = helper.new_set({ hooks = { pre_case = n.setup, post_once = n.stop } })

T['Finder with kind'] = helper.new_set({
  hooks = { pre_case = function() n.set_size(12, 50) end },
  parametrize = {
    { 'floating' },
    { 'replace' },
    { 'split_left' },
    { 'split_left_most' },
    { 'split_above' },
    { 'split_above_all' },
    { 'split_right' },
    { 'split_right_most' },
    { 'split_below' },
    { 'split_below_all' },
  },
})

T['Finder with kind']['can render entries'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-dir/', 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can render entries from dotfile root'] = function(kind)
  local tmpdir = helper.get_tmpdir('.hidden-root', { 'a-dir/', 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  local lines = n.api.nvim_buf_get_lines(0, 0, -1, false)
  helper.expect.equality(#lines, 2)
  helper.expect.match(table.concat(lines, '\n'), 'a-dir')
  helper.expect.match(table.concat(lines, '\n'), 'a-file')
end

T['Finder with kind']['can expand directory'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-dir/', 'a-dir/aa-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('<CR>')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can collapse parent'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-dir/', 'a-dir/aa-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<CR>')
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('j', '<BS>')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can collapse directory with enter'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-dir/', 'a-dir/aa-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<CR>')
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('<CR>')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can toggle hidden items'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { '.hidden-file', 'visible-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('g.')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can toggle hidden items twice'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { '.hidden-file', 'visible-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('g.')
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('g.')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can enter directory under cursor'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'sub/', 'sub/file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('.')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can navigate to parent'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'sub/', 'sub/file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('.')
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('-')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can navigate to root'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'sub/', 'sub/nested/', 'sub/nested/deep' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('.')
  vim.uv.sleep(10)
  n.type_keys('.')
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('=')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can close finder'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('q')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can toggle indent guides'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-dir/', 'a-dir/aa-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<CR>')
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('gi')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can toggle indent guides twice'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-dir/', 'a-dir/aa-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<CR>')
  vim.uv.sleep(10)
  n.type_keys('gi')
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('gi')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can toggle finder'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").toggle')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.fwd_lua('require("fyler").toggle')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.fwd_lua('require("fyler").toggle')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can follow current file'] = function(kind)
  if kind == 'floating' or kind == 'replace' then return end
  local tmpdir = helper.get_tmpdir('data', { 'dir/', 'dir/file' })
  n.fwd_lua('require("fyler").setup')({ follow_current_file = true })
  n.fwd_lua('vim.cmd.edit')(helper.joinpath(tmpdir, 'dir', 'file'))
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can open file'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<CR>')
  n.expect_screenshot()
end

T['Finder with kind']['can open file in split'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<C-s>')
  n.expect_screenshot()
end

T['Finder with kind']['can open file in vsplit'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<C-v>')
  n.expect_screenshot()
end

T['Finder with kind']['can open file in tabedit'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<C-t>')
  n.expect_screenshot()
end

T['Finder with kind']['can dispatch refresh'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  helper.get_tmpdir('data', { 'c-file', 'd-file' })
  n.type_keys('<C-r>')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can create split window if not available'] = function(kind)
  if kind == 'floating' or kind == 'replace' then return end
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ '<C-w><C-o>', '<CR>' })
  n.expect_screenshot()
end

T['Finder with kind']['can prevent user from hijacking window'] = function(kind)
  if kind == 'float' or kind == 'replace' then return end
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.fwd_lua('vim.cmd.edit')(helper.joinpath(tmpdir, 'a-file'))
  n.expect_screenshot()
end

T['Finder with kind']['can delete file'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ 'dd', ':w<CR>' })
  vim.uv.sleep(10)
  n.type_keys('y')
  vim.uv.sleep(10)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'a-file')), 0)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'b-file')), 1)
end

T['Finder with kind']['can rename file'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ '0', 'C', 'renamed-file', '<ESC>', ':w<CR>' })
  vim.uv.sleep(10)
  n.type_keys('y')
  vim.uv.sleep(10)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'renamed-file')), 1)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'a-file')), 0)
end

T['Finder with kind']['can create file'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ 'o', 'new-file', '<ESC>', ':w<CR>' })
  vim.uv.sleep(10)
  n.type_keys('y')
  vim.uv.sleep(10)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'new-file')), 1)
end

T['Finder with kind']['can copy file'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ 'yyp', '0', 'C', 'copied-file', '<ESC>', ':w<CR>' })
  vim.uv.sleep(10)
  n.type_keys('y')
  vim.uv.sleep(10)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'a-file')), 1)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'copied-file')), 1)
end

T['Finder with kind']['can cancel mutation'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ 'o', 'new-file', '<ESC>', ':w<CR>' })
  vim.uv.sleep(10)
  n.expect_screenshot()
  n.type_keys('n')
  vim.uv.sleep(10)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'new-file')), 0)
end

T['Finder with kind']['can auto-confirm simple mutation'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file' })
  n.fwd_lua('require("fyler").setup')({ auto_confirm_simple_mutation = true })
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ 'o', 'new-file', '<ESC>', ':w<CR>' })
  vim.uv.sleep(10)
  helper.expect.equality(vim.fn.filereadable(helper.joinpath(tmpdir, 'new-file')), 1)
end

T['Finder with kind']['can handle swap in file system manipulation'] = function(kind)
  local statusline = n.o.statusline
  n.o.statusline = ' '
  require('mini.test').finally(function() n.o.statusline = statusline end)

  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file' })

  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ '0', 'rb', 'j', 'ra', ':w<CR>' })
  vim.uv.sleep(10)
  helper.expect.equality(
    vim.tbl_contains({
      'Move│a-file->a-file.fyler_tmp\\nMove│b-file->a-file\\nMove│a-file.fyler_tmp->b-file',
      'Move│b-file->b-file.fyler_tmp\\nMove│a-file->b-file\\nMove│b-file.fyler_tmp->a-file',
    }, (table.concat(n.api.nvim_buf_get_lines(0, 0, -1, false), '\\n'):gsub('%s*', ''))),
    true
  )
  n.type_keys('y')
  vim.uv.sleep(10)
  n.expect_screenshot()
end

T['Finder with kind']['can handle chain-dependencies in file system manipulation'] = function(kind)
  local tmpdir = helper.get_tmpdir('data', { 'a-file', 'b-file', 'c-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.fwd_lua('require("fyler").open')({ kind = kind, root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys({ '0', 'rb', 'j', 'rc', 'j', 'rd', ':w<CR>' })
  vim.uv.sleep(10)
  n.type_keys('y')
  vim.uv.sleep(10)
  helper.expect.equality(vim.fn.readfile(helper.joinpath(tmpdir, 'b-file')), { 'ROOT/a-file' })
  helper.expect.equality(vim.fn.readfile(helper.joinpath(tmpdir, 'c-file')), { 'ROOT/b-file' })
  helper.expect.equality(vim.fn.readfile(helper.joinpath(tmpdir, 'd-file')), { 'ROOT/c-file' })
end

T['follow_current_file does not move cursor in unfocused windows'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'dir/', 'dir/a-file', 'dir/b-file', 'dir/c-file' })
  n.fwd_lua('require("fyler").setup')({ follow_current_file = true })
  n.fwd_lua('require("fyler").open')({ kind = 'split_left_most', root_path = tmpdir })
  vim.uv.sleep(50)

  local deep_file = helper.joinpath(tmpdir, 'dir', 'c-file')

  -- Open a non-finder window holding a 10-line buffer, park the cursor on line 1,
  -- focus it, then queue a follow() targeting a deep tree entry. The follow refresh
  -- restores the saved view on a later tick (vim.schedule); by then this non-finder
  -- window is focused. The restore must target the finder window, never this one.
  n.lua(
    [[
    local finder = require('fyler.finder')
    local instance = assert(finder.instance_get_or_nil(), 'finder instance missing')

    vim.cmd('botright vsplit')
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {}
    for i = 1, 10 do lines[i] = 'line ' .. i end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    vim.api.nvim_set_current_win(win)

    _G.obs_win = win
    instance:follow({ target_path = ..., force = true })
  ]],
    { deep_file }
  )

  vim.uv.sleep(50)

  helper.expect.equality(n.lua_get('vim.api.nvim_win_get_cursor(_G.obs_win)[1]'), 1)
end

T['Visit close replace'] = helper.new_set()

local count_fyler_bufs_lua = [[vim.tbl_count(vim.tbl_filter(function(b)
  local ok, name = pcall(vim.api.nvim_buf_get_name, b)
  return ok and name:match('^fyler%-') ~= nil
end, vim.api.nvim_list_bufs()))]]

T['Visit close replace']['visit cursor then close restores origin without scratch'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'sub/', 'sub/file', 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  local origin_file = helper.joinpath(tmpdir, 'a-file')
  n.fwd_lua('vim.cmd.edit')(origin_file)
  local origin_buf = n.lua_get('vim.api.nvim_get_current_buf()')
  n.fwd_lua('require("fyler").open')({ kind = 'replace', root_path = tmpdir })
  vim.uv.sleep(50)
  n.type_keys('gg', '.')
  vim.uv.sleep(50)
  -- Regression for issue-366: rename in `visit()` must not clobber `#`
  -- with the unlisted ghost holding the old `fyler-...` name.
  helper.expect.equality(n.lua_get('vim.fn.bufnr("#")'), origin_buf)
  helper.expect.equality(n.lua_get(count_fyler_bufs_lua), 1)
  n.type_keys('q')
  vim.uv.sleep(50)
  helper.expect.equality(n.lua_get('vim.api.nvim_get_current_buf()'), origin_buf)
  helper.expect.equality(n.lua_get(count_fyler_bufs_lua), 0)
  local cur_name = n.lua_get('vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())')
  helper.expect.equality(cur_name ~= '', true)
  helper.expect.equality(cur_name:match('^fyler%-') == nil, true)
end

T['Visit close replace']['visit parent then close restores origin'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'sub/', 'sub/file', 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  local origin_file = helper.joinpath(tmpdir, 'a-file')
  n.fwd_lua('vim.cmd.edit')(origin_file)
  local origin_buf = n.lua_get('vim.api.nvim_get_current_buf()')
  n.fwd_lua('require("fyler").open')({ kind = 'replace', root_path = helper.joinpath(tmpdir, 'sub') })
  vim.uv.sleep(50)
  n.lua([[require('fyler.finder').instance_get_or_nil():visit({ parent = true })]])
  vim.uv.sleep(50)
  helper.expect.equality(n.lua_get('vim.fn.bufnr("#")'), origin_buf)
  n.type_keys('q')
  vim.uv.sleep(50)
  helper.expect.equality(n.lua_get('vim.api.nvim_get_current_buf()'), origin_buf)
  helper.expect.equality(n.lua_get(count_fyler_bufs_lua), 0)
end

T['Visit close replace']['double visit then close restores origin'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'sub/', 'sub/file', 'a-file' })
  n.fwd_lua('require("fyler").setup')({})
  local origin_file = helper.joinpath(tmpdir, 'a-file')
  n.fwd_lua('vim.cmd.edit')(origin_file)
  local origin_buf = n.lua_get('vim.api.nvim_get_current_buf()')
  n.fwd_lua('require("fyler").open')({ kind = 'replace', root_path = tmpdir })
  vim.uv.sleep(50)
  local subdir = helper.joinpath(tmpdir, 'sub')
  n.lua([[require('fyler.finder').instance_get_or_nil():visit({ path = ... })]], { subdir })
  vim.uv.sleep(50)
  n.lua([[require('fyler.finder').instance_get_or_nil():visit({ parent = true })]])
  vim.uv.sleep(50)
  helper.expect.equality(n.lua_get(count_fyler_bufs_lua), 1)
  n.type_keys('q')
  vim.uv.sleep(50)
  helper.expect.equality(n.lua_get('vim.api.nvim_get_current_buf()'), origin_buf)
  helper.expect.equality(n.lua_get(count_fyler_bufs_lua), 0)
end

return T

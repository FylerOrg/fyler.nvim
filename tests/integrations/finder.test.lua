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

return T

local helper = require('tests.helper')
local n = helper.new_child_neovim()
local T = helper.new_set({ hooks = { pre_case = n.setup, post_once = n.stop } })
local eq = helper.expect.equality

T['sort sorts by directory then name'] = function()
  n.lua([[_G.fs = require('fyler.lib.fs')]])
  local entries = {
    { path = '/root/z_file', name = 'z_file', type = 'file' },
    { path = '/root/a_dir', name = 'a_dir', type = 'directory' },
    { path = '/root/b_file', name = 'b_file', type = 'file' },
    { path = '/root/m_dir', name = 'm_dir', type = 'directory' },
  }
  n.lua(
    [[
    _G.entries = ...
    table.sort(_G.entries, _G.fs.sort)
  ]],
    { entries }
  )
  local sorted = n.lua_get('_G.entries')
  eq(sorted[1].name, 'a_dir')
  eq(sorted[2].name, 'm_dir')
  eq(sorted[3].name, 'b_file')
  eq(sorted[4].name, 'z_file')
end

T['is_hidden returns true for dotfiles'] = function()
  n.lua([[_G.fs = require('fyler.lib.fs')]])
  local hidden_items = { switches = { dotfiles = true }, patterns = {}, always_visible = {}, always_hidden = {} }
  n.lua('_G.hidden_items = ...', { hidden_items })
  eq(n.lua_get('_G.fs.is_hidden("/root/.hidden", _G.hidden_items)'), true)
  eq(n.lua_get('_G.fs.is_hidden("/root/..hidden", _G.hidden_items)'), true)
end

T['is_hidden returns false for non-dotfiles'] = function()
  n.lua([[_G.fs = require('fyler.lib.fs')]])
  local hidden_items = { switches = { dotfiles = true }, patterns = {}, always_visible = {}, always_hidden = {} }
  n.lua('_G.hidden_items = ...', { hidden_items })
  eq(n.lua_get('_G.fs.is_hidden("/root/visible", _G.hidden_items)'), false)
  eq(n.lua_get('_G.fs.is_hidden("/root/a", _G.hidden_items)'), false)
end

return T

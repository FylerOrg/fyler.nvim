local helper = require('tests.helper')
local n = helper.new_child_neovim()
local T = helper.new_set({ hooks = { pre_case = n.setup, post_once = n.stop } })
local eq = helper.expect.equality

T['is_abs returns true for absolute path'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then
    eq(n.lua_get('_G.path.is_abs("C:\\\\Users\\\\foo")'), true)
  else
    eq(n.lua_get('_G.path.is_abs("/home/user/file")'), true)
  end
end

T['is_abs returns false for relative path'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then
    eq(n.lua_get('_G.path.is_abs("relative\\\\path")'), false)
  else
    eq(n.lua_get('_G.path.is_abs("relative/path")'), false)
  end
end

T['to_posix passes through posix path unchanged'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  eq(n.lua_get('_G.path.to_posix("/home/user/file")'), '/home/user/file')
end

T['to_posix converts windows absolute path'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then
    eq(n.lua_get('_G.path.to_posix("C:\\\\Users\\\\foo")'), '/c/Users/foo')
    eq(n.lua_get('_G.path.to_posix("c:\\\\Users\\\\foo")'), '/c/Users/foo')
  end
end

T['to_posix converts windows relative path'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then eq(n.lua_get('_G.path.to_posix("foo\\\\bar\\\\baz")'), 'foo/bar/baz') end
end

T['to_os passes through posix path unchanged'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  eq(n.lua_get('_G.path.to_os("/home/user/file")'), '/home/user/file')
end

T['to_os converts posix absolute path to windows'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then eq(n.lua_get('_G.path.to_os("/c/Users/foo")'), 'C:/Users/foo') end
end

T['to_os converts posix relative path to windows'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then eq(n.lua_get('_G.path.to_os("foo/bar/baz")'), 'foo/bar/baz') end
end

T['to_posix and to_os round-trip'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then
    eq(n.lua_get('_G.path.to_os(_G.path.to_posix("C:\\\\Users\\\\foo"))'), 'C:/Users/foo')
    eq(n.lua_get('_G.path.to_os(_G.path.to_posix("foo\\\\bar"))'), 'foo/bar')
  end
end

T['to_normalize removes trailing slash'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  eq(n.lua_get('_G.path.to_normalize("/Home/User/File/")'), '/Home/User/File')
  eq(n.lua_get('_G.path.to_normalize("/Home/User/File//")'), '/Home/User/File')
end

T['to_normalize normalizes backslashes on windows'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then eq(n.lua_get('_G.path.to_normalize("C:\\\\Users\\\\foo")'), 'C:/Users/foo') end
end

T['do_join preserves original casing'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  eq(n.lua_get('_G.path.do_join("/Home/User", "Dir", "File")'), '/Home/User/Dir/File')
end

T['is_equal matches paths with different case on case-insensitive fs'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' or jit.os == 'OSX' then
    eq(n.lua_get('_G.path.is_equal("/Home/User/File", "/home/user/file")'), true)
  else
    eq(n.lua_get('_G.path.is_equal("/Home/User/File", "/home/user/file")'), false)
  end
end

T['do_split splits posix path into segments'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  local result = n.lua_get('_G.path.do_split("/home/user/dir/file")')
  eq(result, { 'home', 'user', 'dir', 'file' })
end

T['do_split splits windows path into posix segments'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  if jit.os == 'Windows' then
    local result = n.lua_get('_G.path.do_split("C:\\\\Users\\\\foo")')
    eq(result, { 'c', 'Users', 'foo' })
  end
end

T['to_abs passes through absolute path unchanged'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  eq(n.lua_get('_G.path.to_abs("/home/user/file")'), '/home/user/file')
end

T['to_abs resolves relative path to absolute'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  local result = n.lua_get('_G.path.to_abs("relative/path")')
  eq(vim.fn.isabsolutepath(result), 1)
  eq(string.sub(result, -#'/relative/path'), '/relative/path')
end

T['to_dirname returns parent directory'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  eq(n.lua_get('_G.path.to_dirname("/home/user/file")'), '/home/user')
end

T['to_dirname returns dirname for root path'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  eq(n.lua_get('_G.path.to_dirname("/home/user/")'), '/home')
end

T['to_rel computes relative path within project'] = function()
  n.lua([[_G.path = require('fyler.lib.path')]])
  n.lua([[
    _G.cwd = vim.fn.getcwd()
    _G.target = _G.cwd .. '/lua/fyler/lib/path.lua'
    _G.result = _G.path.to_rel(_G.cwd, _G.target)
  ]])
  eq(n.lua_get('_G.result'), 'lua/fyler/lib/path.lua')
end

return T

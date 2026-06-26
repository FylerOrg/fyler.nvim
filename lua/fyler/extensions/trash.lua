local Spinner = require('fyler.spinner')
local extensions = require('fyler.extensions')
local libpath = require('fyler.lib.path')
local hooks = require('fyler.config').DATA.hooks

local uv = vim.uv
local H = {}

if jit.os == 'Linux' then H.platform = 'linux' end
if jit.os == 'OSX' then H.platform = 'macos' end
if jit.os == 'Windows' then H.platform = 'windows' end

function H.get_xdg_data_home()
  local xdg = vim.env.XDG_DATA_HOME
  if xdg and #xdg > 0 then return xdg end
  return vim.fn.expand('~/.local/share')
end

function H.ensure_trash_dirs_linux()
  local root = libpath.do_join(H.get_xdg_data_home(), 'Trash')
  H.trash_files_dir = libpath.do_join(root, 'files')
  H.trash_info_dir = libpath.do_join(root, 'info')
  for _, dir in ipairs({ H.trash_files_dir, H.trash_info_dir }) do
    if not uv.fs_stat(dir) then uv.fs_mkdir(dir, 448) end
  end
end

function H.async_resolve_trash_path(src, cb)
  local basename = vim.fs.basename(src)
  local function try(n)
    local name = n == 0 and basename or basename .. '.' .. n
    local candidate = libpath.do_join(H.trash_files_dir, name)
    uv.fs_stat(candidate, function(err)
      if err then
        cb(candidate)
      elseif n < 999 then
        try(n + 1)
      else
        cb(libpath.do_join(H.trash_files_dir, basename .. '.' .. os.time()))
      end
    end)
  end
  try(0)
end

function H.async_write_trashinfo(info_path, content, cb)
  uv.fs_open(info_path, 'w', 420, function(open_err, fd)
    if open_err then
      cb(open_err)
      return
    end
    uv.fs_write(fd, content, -1, function(write_err)
      uv.fs_close(fd, function() cb(write_err) end)
    end)
  end)
end

function H.process_serially(actions, idx, done)
  if idx > #actions then
    done()
    return
  end

  local action = actions[idx]
  if not (action.name == 'trash') then
    H.process_serially(actions, idx + 1, done)
    return
  end

  if H.platform == 'linux' then
    H.async_resolve_trash_path(action.src, function(target)
      local info_path = libpath.do_join(H.trash_info_dir, vim.fs.basename(target) .. '.trashinfo')
      local info_content = ('[Trash Info]\nPath=%s\nDeletionDate=%s\n'):format(action.src, os.date('%Y-%m-%dT%H:%M:%S'))

      H.async_write_trashinfo(info_path, info_content, function(err)
        if err then vim.notify('Failed to write trash info: ' .. err, vim.log.levels.ERROR) end
        action.name = 'move'
        action.dst = target
        vim.schedule_wrap(hooks.on_delete)(action.src)
        H.process_serially(actions, idx + 1, done)
      end)
    end)
  elseif H.platform == 'macos' then
    vim.system({ '/usr/bin/trash', action.src }, { text = true }, function(result)
      if result.code == 0 then
        vim.schedule_wrap(hooks.on_delete)(action.src)
        H.process_serially(actions, idx + 1, done)
      else
        vim.notify('Trash failed: ' .. (result.stdout or result.stderr or 'unknown error'), vim.log.levels.ERROR)
      end
    end)
  elseif H.platform == 'windows' then
    local cmd = ("Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::%s('%s', 'OnlyErrorDialogs', 'SendToRecycleBin')"):format(
      vim.fn.isdirectory(action.src) == 1 and 'DeleteDirectory' or 'DeleteFile',
      action.src:gsub("'", "''")
    )
    vim.system({ 'powershell', '-NoProfile', '-Command', cmd }, { text = true }, function(result)
      if result.code == 0 then
        vim.schedule_wrap(hooks.on_delete)(action.src)
        H.process_serially(actions, idx + 1, done)
      else
        vim.notify('Trash failed: ' .. (result.stdout or result.stderr or 'unknown error'), vim.log.levels.ERROR)
      end
    end)
  else
    H.process_serially(actions, idx + 1, done)
  end
end

extensions.register({
  name = 'trash',
  setup = function(opts, config)
    config.extensions.trash = vim.tbl_deep_extend('force', {
      enabled = false,
    }, opts)

    if H.platform == 'linux' and config.extensions.trash.enabled then H.ensure_trash_dirs_linux() end
  end,
  hooks = {
    finder_mutate_pre = function(fs_actions)
      local cfg = require('fyler.config').DATA.extensions.trash
      if not cfg or not cfg.enabled then return end
      for _, action in ipairs(fs_actions) do
        if action.name == 'delete' then action.name = 'trash' end
      end
    end,
    finder_execute_pre = function(actions, done)
      local cfg = require('fyler.config').DATA.extensions.trash
      if not cfg or not cfg.enabled then
        done()
        return
      end
      if not H.platform then
        done()
        return
      end
      local s = Spinner.new({ message = 'Moving to trash...' })
      s:start()
      H.process_serially(actions, 1, function()
        s:stop()
        done()
      end)
    end,
  },
})

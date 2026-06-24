local extensions = require('fyler.extensions')
local libpath = require('fyler.lib.path')
local uv = vim.uv

local H = {}

---@type table<integer, { handles: table<string, uv.uv_fs_event_t>, timer: uv.uv_timer_t|nil, pending_refresh: table|nil }>
local watch_state = {}

---@param buf_id integer
---@param dir_path string
---@param on_event fun(filename: string|nil, status: table|nil)
function H.start_handle(buf_id, dir_path, on_event)
  local state = watch_state[buf_id]
  if not state or state.handles[dir_path] then return end

  local handle = uv.new_fs_event()
  if not handle then return end

  local ok = handle:start(dir_path, { watch_entry = true }, function(err, filename, status)
    if err then return end
    on_event(filename, status)
  end)

  if ok then
    state.handles[dir_path] = handle
  else
    handle:close()
  end
end

---@param buf_id integer
---@param dir_path string
function H.stop_handle(buf_id, dir_path)
  local state = watch_state[buf_id]
  if not state then return end
  local handle = state.handles[dir_path]
  if not handle then return end
  pcall(handle.stop, handle)
  pcall(handle.close, handle)
  state.handles[dir_path] = nil
end

---@param buf_id integer
function H.stop_all(buf_id)
  local state = watch_state[buf_id]
  if not state then return end
  for _, handle in pairs(state.handles) do
    pcall(handle.stop, handle)
    pcall(handle.close, handle)
  end
  if state.timer then
    state.timer:stop()
    state.timer:close()
  end
  watch_state[buf_id] = nil
end

extensions.register({
  name = 'watcher',
  setup = function(opts, config)
    config.extensions.watcher = vim.tbl_deep_extend('force', {
      enabled = true,
      debounce_ms = 200,
      known_git_roots = {},
    }, opts)
  end,
  hooks = {
    finder_refresh_post = function(instance)
      local cfg = require('fyler.config').DATA.extensions.watcher
      if not cfg.enabled then return end

      local buf_id = instance.buf_id
      if not buf_id then return end

      if not watch_state[buf_id] then watch_state[buf_id] = { handles = {}, timer = nil } end
      local state = watch_state[buf_id]

      local dirs_to_watch = {}

      local state_mod = require('fyler.state')

      for key, expanded in pairs(instance.state.meta) do
        if expanded then
          local id = state_mod.store_path_id[key]
          if id then
            local entry = state_mod.store[id]
            if entry and entry.type == 'directory' then dirs_to_watch[entry.path] = true end
          end
        end
      end

      local known_roots = cfg.known_git_roots or {}
      local has_known_roots = next(known_roots) ~= nil

      if has_known_roots then
        for root, _ in pairs(known_roots) do
          dirs_to_watch[libpath.do_join(root, '.git')] = true
        end
      else
        for dir, _ in pairs(dirs_to_watch) do
          local git_dir = libpath.do_join(dir, '.git')
          if uv.fs_stat(git_dir) then dirs_to_watch[git_dir] = true end
        end
      end

      for dir_path, _ in pairs(state.handles) do
        if not dirs_to_watch[dir_path] then H.stop_handle(buf_id, dir_path) end
      end

      for dir_path, _ in pairs(dirs_to_watch) do
        if not state.handles[dir_path] then
          local is_git_dir = dir_path:match('/%.git$')
          H.start_handle(buf_id, dir_path, function(filename, status)
            if is_git_dir and filename and filename ~= 'index' then return end
            if not is_git_dir and not (status and status.rename) then return end

            if is_git_dir then
              state.pending_refresh = { force = true, recursive = true }
            elseif not state.pending_refresh then
              state.pending_refresh = { force = true, recursive = true, target_path = dir_path }
            end

            if not state.timer then state.timer = uv.new_timer() end
            state.timer:stop()
            state.timer:start(cfg.debounce_ms, 0, function()
              vim.schedule(function()
                if not watch_state[buf_id] then return end
                local pending = state.pending_refresh
                pcall(function() instance:refresh(pending) end)
              end)
            end)
          end)
        end
      end
    end,
    finder_close_post = function(instance) H.stop_all(instance.buf_id) end,
  },
})

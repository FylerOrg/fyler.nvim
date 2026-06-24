local M = {}

local function pack(...)
  local t, n = {}, select('#', ...)
  for i = 1, n do
    t[i] = select(i, ...)
  end
  t.n = n
  return t
end

function M.wrap(fn)
  return function(...)
    local co = coroutine.running()
    assert(co, 'async.wrap: must be called from within a coroutine')

    local status = 'running'
    local ret

    local cb = function(...)
      if status == 'done' then return end
      status = 'done'
      if coroutine.status(co) == 'suspended' then
        coroutine.resume(co, ...)
      else
        ret = pack(...)
      end
    end

    local args = { ... }
    table.insert(args, cb)
    fn(unpack(args))

    if status == 'running' then
      return coroutine.yield()
    else
      return unpack(ret, 1, ret.n)
    end
  end
end

function M.run(fn, cb)
  local co = coroutine.create(function()
    local ok, err = pcall(fn)
    if cb then
      if ok then
        cb(nil)
      else
        cb(tostring(err))
      end
    end
  end)
  local ok, err = coroutine.resume(co)
  if not ok and cb then cb(tostring(err)) end
end

function M.void(fn) return coroutine.wrap(fn)() end

return M

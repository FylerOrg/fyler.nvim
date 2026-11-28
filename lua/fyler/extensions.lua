--- EXTENSION DECORATIONS ~
---
--- Extensions can contribute text and icons without managing buffer geometry.
--- Register a decoration provider next to other extension fields:
---
--- >lua
---   extensions.register({
---     name = 'example',
---     decorations = {
---       provide = function(ctx, emit)
---         local cells = {}
---         for _, entry in ipairs(ctx.entries) do
---           cells[entry.id] = {
---             chunks = { { '*', 'FylerGitModified' } },
---             -- Optional highlight over the entry name.
---             entry_hl = 'FylerGitModified',
---           }
---         end
---         return cells
---       end,
---     },
---   })
--- <
---
--- `ctx.area` resolves to `inline` or `column` from `ui.decorations` or the
--- extension's `get_area`; use it when content differs by area. Providers may
--- return cells synchronously or call `emit(cells)` asynchronously. `emit` may
--- also be called multiple times.
--- Results are keyed by `entry.id`. Async emissions are discarded when the
--- finder refreshes, closes, or its buffer changes.
---
--- Column providers receive an independent slot. Slot widths and ordering are
--- managed centrally. Inline fragments are joined with a fixed gap and
--- single-space separator. Highlight ranges over entry names are independent of
--- placement.
---
---@tag fyler.decorations

local M = {}
local registry = {}

---@class fyler.Extension
---@field name string
---@field setup function|nil
---@field hooks table<string, function>|nil
---@field decorations fyler.DecorationDefinition|nil

---@param ext fyler.Extension
function M.register(ext) registry[ext.name] = ext end

---@param config table<string, table>
function M.setup(config)
  for name, opts in pairs(config or {}) do
    if not registry[name] then pcall(require, 'fyler.extensions.' .. name) end
    local ext = registry[name]
    if ext and ext.setup then
      ext.setup(opts, require('fyler.config').DATA)
    elseif not ext then
      vim.notify(('Fyler: extension "%s" not found'):format(name), vim.log.levels.WARN)
    end
  end
end

function M.decoration_sources()
  local sources = {}
  for name, ext in pairs(registry) do
    if ext.decorations and type(ext.decorations.provide) == 'function' then
      sources[#sources + 1] = {
        name = name,
        provide = ext.decorations.provide,
        get_area = ext.decorations.get_area,
      }
    end
  end
  table.sort(sources, function(a, b) return a.name < b.name end)
  return sources
end

function M.hook_count(name)
  local count = 0
  for _, ext in pairs(registry) do
    if ext.hooks and ext.hooks[name] then count = count + 1 end
  end
  return count
end

function M.run_hook(name, ...)
  for _, ext in pairs(registry) do
    if ext.hooks and ext.hooks[name] then ext.hooks[name](...) end
  end
end

return M

---@class MiniIconsIntegration
local M = {}

function M.get(type, name)
  local ok, miniicons = pcall(require, "mini.icons")
  assert(ok, "mini.icons are not installed or not loaded")

  local supported = {
    default = true,
    directory = true,
    extension = true,
    file = true,
    filetype = true,
    lsp = true,
    os = true,
  }

  local category = supported[type] and type or "file"
  return miniicons.get(category, name)
end

return M

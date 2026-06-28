local config = Fyler.import('fyler.config')
local input = Fyler.import('fyler.input')

local M = {}
local H = {}

H.builtin = function(filter) return input.get_selected_window(filter) end

M.get_selected_window = function(filter)
  local integration = config.DATA.integrations.window_picker
  if type(integration) == 'function' then return integration(filter) end
  if type(integration) == 'string' and H[integration] then return H[integration](filter) end
  return H.builtin(filter)
end

return M

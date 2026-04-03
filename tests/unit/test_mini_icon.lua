local helper = require("tests.helper")
local mini_icons = require("fyler.integrations.icon.mini_icons")

local equal = helper.equal

local T = helper.new_set()

local function with_stubbed_mini_icons(fn)
  local original = package.loaded["mini.icons"]
  package.loaded["mini.icons"] = {
    get = function(category, name) return category, name end,
  }

  local ok, err = pcall(fn)
  package.loaded["mini.icons"] = original
  assert(ok, err)
end

T["Supported Types"] = helper.new_set({
  parametrize = {
    { "default" },
    { "directory" },
    { "extension" },
    { "file" },
    { "filetype" },
    { "lsp" },
    { "os" },
  },
})

T["Supported Types"]["Pass Through Category"] = function(category)
  with_stubbed_mini_icons(function()
    local actual_category, actual_name = mini_icons.get(category, "test_default")
    equal(actual_category, category)
    equal(actual_name, "test_default")
  end)
end

T["Unsupported Types"] = helper.new_set({
  parametrize = {
    { "socket" },
    { "block" },
    { "char" },
  },
})

T["Unsupported Types"]["Fallback To File"] = function(category)
  with_stubbed_mini_icons(function()
    local actual_category, actual_name = mini_icons.get(category, "test_default")
    equal(actual_category, "file")
    equal(actual_name, "test_default")
  end)
end

return T

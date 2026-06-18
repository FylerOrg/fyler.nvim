local helper = require('tests.helper')
local n = helper.new_child_neovim()
local T = helper.new_set({ hooks = { pre_case = n.setup, post_once = n.stop } })

local eq = helper.expect.equality

local expect_config = function(field, value) eq(n.lua_get('require("fyler.config").DATA.' .. field), value) end

T['Creates default configuration'] = function()
  n.fwd_lua('require("fyler").setup')()

  expect_config('auto_confirm_simple_mutation', false)
  expect_config('kind', 'replace')
  expect_config('kind_presets.floating.border', 'single')
  expect_config('kind_presets.floating.height', '80%')
  expect_config('kind_presets.floating.mappings.n["<CR>"].action', 'select')
  expect_config('kind_presets.floating.mappings.n["<CR>"].args.close', true)
  expect_config('kind_presets.floating.width', '60%')
  expect_config('kind_presets.floating.col', 'center')
  expect_config('kind_presets.floating.row', 'center')
  expect_config('kind_presets.replace.mappings.n["<CR>"].action', 'select')
  expect_config('kind_presets.replace.mappings.n["<CR>"].args.close', true)
  expect_config('kind_presets.split_above.height', '50%')
  expect_config('kind_presets.split_above_all.height', '50%')
  expect_config('kind_presets.split_below.height', '50%')
  expect_config('kind_presets.split_below_all.height', '50%')
  expect_config('kind_presets.split_left.width', '25%')
  expect_config('kind_presets.split_left_most.width', '25%')
  expect_config('kind_presets.split_right.width', '25%')
  expect_config('kind_presets.split_right_most.width', '25%')
  expect_config('mappings.n["<BS>"].action', 'shrink')
  expect_config('mappings.n["<BS>"].args.parent', true)
  expect_config('mappings.n["<C-R>"].action', 'refresh')
  expect_config('mappings.n["<C-S>"].action', 'select')
  expect_config('mappings.n["<C-S>"].args.split', true)
  expect_config('mappings.n["<C-T>"].action', 'select')
  expect_config('mappings.n["<C-T>"].args.tabedit', true)
  expect_config('mappings.n["<C-V>"].action', 'select')
  expect_config('mappings.n["<C-V>"].args.vsplit', true)
  expect_config('mappings.n["<CR>"].action', 'select')
  expect_config('mappings.n["g."].action', 'toggle_ui')
  expect_config('mappings.n["q"].action', 'close')
  expect_config('ui.hidden_items.always_hidden', {})
  expect_config('ui.hidden_items.always_visible', {})
  expect_config('ui.hidden_items.patterns', {})
  expect_config('ui.hidden_items.switches', { 'dotfiles' })
  expect_config('use_as_default_explorer', true)
end

T['Respect custom configuration'] = function()
  n.fwd_lua('require("fyler").setup')({ use_as_default_explorer = false })

  expect_config('use_as_default_explorer', false)
end

return T

--- Author   : Lavin Raj Mohan <lavinrajmohan@gmail.com>
--- Homepage : |https://github.com/FylerOrg/fyler.nvim|
--- License  : Apache 2.0
--- Tags     : *fyler.nvim* *fyler.txt*

--- TABLE OF CONTENTS ~
---
--- 1. Introduction                                          |fyler.introduction|
--- 2. Requirements                                          |fyler.requirements|
--- 3. Usage                                                        |fyler.usage|
--- 4. Setup                                                        |fyler.setup|
---
---@tag fyler.table-of-contents

--- INTRODUCTION ~
---
--- Fyler.nvim is |oil.nvim| inspired file manager plugin for neovim which can
--- manipulate file system like a neovim buffer and provide a proper file-tree
--- representation of items.
---
---@tag fyler.introduction

--- REQUIREMENTS ~
---
--- - Neovim >= 0.11
---
---@tag fyler.requirements

--- USAGE ~
---
--- Open Fyler using the `:Fyler` command:
---
--- >vim
---   :Fyler                    " Open the finder
---   :Fyler root_path=<path>   " Use a different directory path
---   :Fyler kind=<buffer_kind> " Open specified kind directly
--- <
---
--- Open Fyler from Lua:
---
--- >lua
---   local fyler = require('fyler')
---
---   -- open using defaults
---   fyler.open()
---
---   -- open as a left most split
---   fyler.open({ kind = "split_left_most" })
---
---   -- open with different directory
---   fyler.open({ root_path = "~" })
---
---   -- You can map this to a key
---   vim.keymap.set("n", "<leader>e", fyler.open, { desc = "Fyler.nvim - Open" })
---
---   -- Wrap in a function to pass additional arguments
---   vim.keymap.set(
---       "n",
---       "<leader>e",
---       function() fyler.open({ kind = "split_left_most" }) end,
---       { desc = "Fyler.nvim - Open" }
---   )
--- <
---
---@tag fyler.usage

local Fyler = {}
local H = {}
local did_setup = false

-- A unified module system similar to |snacks.nvim|. It holds a lazy import
-- function with a namespace of `Fyler` so that it won't conflict with other
-- globals.
--
---@param module_name string
---@return table
Fyler.import = function(module_name)
  -- A function to check whether a module was found or not?
  return setmetatable({ is_found = function() return (pcall(require, module_name)) end }, {
    __call = function(_, ...)
      -- Returned table handles callable behaviour.
      return require(module_name)(...)
    end,
    __index = function(_, k)
      -- Returned table handles indexable behaviour.
      return require(module_name)[k]
    end,
  })
end

local util = Fyler.import('fyler.util')

H.setup_autocmds = function()
  local config = Fyler.import('fyler.config').DATA
  local finder = Fyler.import('fyler.finder')

  local gr = vim.api.nvim_create_augroup('FylerFinder', {})
  local au = function(event, pattern, callback, desc)
    vim.api.nvim_create_autocmd(event, { group = gr, pattern = pattern, callback = callback, desc = desc })
  end

  au('ColorScheme', '*', H.setup_highlights, 'Ensure colors')

  au('WinEnter', '*', function()
    if vim.bo.filetype == 'fyler_finder' then return end
    finder.window_set_prior(vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win())
  end, 'Track prior window')

  au('BufEnter', '*', function()
    if vim.bo.filetype == 'fyler_finder' then return end

    local prior_buf_id = vim.fn.bufnr('#')
    if prior_buf_id < 1 then return end
    if vim.bo[prior_buf_id].filetype ~= 'fyler_finder' then return end

    local current_tab_id = vim.api.nvim_get_current_tabpage()
    local current_win_id = vim.api.nvim_get_current_win()
    local instance = finder.instance_get_or_nil(current_tab_id)
    if not instance then return end
    if instance.win_id ~= current_win_id then return end

    if instance.opts.kind == 'replace' then return end

    local buf_id = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(0)
    vim.api.nvim_win_set_buf(instance.win_id, instance.buf_id)
    vim.schedule(function()
      finder.window_goto_suitable(instance, bufname)
      vim.api.nvim_set_current_buf(buf_id)
    end)
  end, 'Redirect file open to suitable window')

  if config.use_as_default_explorer then
    vim.cmd('silent! autocmd! FileExplorer *')
    vim.cmd('autocmd VimEnter * ++once silent! autocmd! FileExplorer *')

    au('BufEnter', '*', function()
      -- TODO: supports all schemes
      local buf_name = vim.api.nvim_buf_get_name(0)
      if vim.fn.isdirectory(buf_name) == 0 then return end
      vim.api.nvim_buf_delete(0, { force = true })
      vim.schedule_wrap(Fyler.open)({ root_path = buf_name })
    end, 'Track directory edit')
  end

  if config.follow_current_file then
    au('BufEnter', '*', function()
      if vim.bo.filetype == 'fyler_finder' then return end
      local buf_name = vim.api.nvim_buf_get_name(0)
      if not buf_name or buf_name == '' then return end
      local instance = finder.instance_get_or_nil()
      if not instance then return end
      instance:follow({ target_path = buf_name })
    end, 'Follow current file')
  end
end

H.setup_highlights = function()
  local getbg = function(group) return util.get_hl_color(group, 'bg') end
  local getfg = function(group) return util.get_hl_color(group, 'fg') end

  -- stylua: ignore
  local palette = {
    bg   = getbg('Normal'),
    blue = getfg('Directory'),
    fg   = getfg('Normal'),
    grey = getfg('NonText'),
  }

  -- stylua: ignore
  local highlights = {
    FylerDirectoryIcon = { fg = palette.blue },
    FylerDirectoryName = { fg = palette.blue },
    FylerFloat         = { bg = palette.bg, fg = palette.fg },
    FylerFloatBorder   = { bg = palette.bg, fg = palette.fg },
    FylerFloatTitle    = { bg = palette.bg, fg = palette.fg },
    FylerIndentGuide   = { fg = palette.grey },
    FylerNormal        = { fg = palette.fg },
  }

  local hooks = Fyler.import('fyler.config').DATA.hooks
  if hooks.on_highlight then hooks.on_highlight(highlights, palette) end

  for name, value in pairs(highlights) do
    value.default = true
    vim.api.nvim_set_hl(0, name, value)
  end

  Fyler.import('fyler.extensions').run_hook('highlights_post')
end

---@param user_config fyler.UserConfig|nil
Fyler.setup = function(user_config)
  -- A safety check to prevent NVIM < 0.11, although it could work for some lower
  -- versions as well but better safe then sorry.
  if vim.fn.has('nvim-0.11') == 0 then
    vim.notify('Fyler.nvim requires at least NVIM 0.11', vim.log.levels.ERROR, { title = 'Fyler.nvim' })
    return
  end

  -- Prevent user from re-setup.
  if did_setup then
    vim.notify('Fyler.nvim can be setup once', vim.log.levels.WARN, { title = 'Fyler.nvim' })
    return
  end

  _G.Fyler = Fyler

  Fyler.import('fyler.config').setup(user_config)
  Fyler.import('fyler.extensions').setup(Fyler.import('fyler.config').DATA.extensions)

  H.setup_autocmds()
  H.setup_highlights()

  -- Public APIs --------------------
  local finder = Fyler.import('fyler.finder')

  Fyler.close = function()
    local inst = finder.instance_get_or_nil()
    if inst then inst:close() end
  end

  Fyler.getcwd = function()
    local inst = finder.instance_get_or_nil()
    if inst then return inst.state.pseudo_root_path end
  end

  Fyler.open = function(opts) finder.instance_get(nil, opts):open() end

  Fyler.toggle = function(opts) finder.instance_get(nil, opts):toggle() end

  did_setup = true
end

return Fyler

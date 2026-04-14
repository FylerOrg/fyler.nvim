local deprecated = require("fyler.deprecated")
local util = require("fyler.lib.util")

local config = {}

local DEPRECATION_RULES = {
  deprecated.rename("views.finder.git", "views.finder.columns.git"),
  deprecated.transform(
    "views.finder.indentscope.marker",
    "views.finder.indentscope.markers",
    function() return { { "│", "FylerIndentMarker" }, { "└", "FylerIndentMarker" } } end
  ),
}

---@class FylerConfigGitStatus
---@field enabled boolean
---@field symbols table<string, string>

---@alias FylerConfigIntegrationsIcon
---| "none"
---| "mini_icons"
---| "nvim_web_devicons"
---| "vim_nerdfont"

---@alias FylerConfigIntegrationsWinpickName
---| "none"
---| "builtin"
---| "nvim-window-picker"
---| "snacks"

---@alias FylerConfigIntegrationsWinpickFn fun(win_filter: integer[], onsubmit: fun(winid: integer|nil), opts: table)

---@class FylerConfigWinpickBuiltinOpts
---@field chars string|nil

---@class FylerConfigWinpickTable
---@field provider FylerConfigIntegrationsWinpickName|FylerConfigIntegrationsWinpickFn
---@field opts FylerConfigWinpickBuiltinOpts|table<string, any>|nil

---@alias FylerConfigWinpick
---| FylerConfigIntegrationsWinpickName
---| FylerConfigIntegrationsWinpickFn
---| FylerConfigWinpickTable

---@class FylerConfigIntegrations
---@field icon FylerConfigIntegrationsIcon
---@field winpick FylerConfigWinpick

---@alias FylerConfigFinderMapping
---| ""
---| "CloseView"
---| "GotoCwd"
---| "GotoNode"
---| "GotoParent"
---| "Select"
---| "SelectSplit"
---| "SelectTab"
---| "SelectVSplit"
---| "CollapseAll"
---| "CollapseNode"

---@class FylerConfigIndentScope
---@field enabled boolean
---@field group string
---@field marker string

---@alias FylerConfigBorder
---| "bold"
---| "double"
---| "none"
---| "rounded"
---| "shadow"
---| "single"
---| "solid"

---@class FylerConfigWinKindOptions
---@field height string|number|nil
---@field width string|number|nil
---@field top string|number|nil
---@field left string|number|nil
---@field win_opts table<string, any>|nil

---@class FylerConfigWin
---@field border FylerConfigBorder|string[]|nil
---@field bottom integer|string|nil
---@field buf_opts table<string, any>|nil
---@field footer string|nil
---@field footer_pos string|nil
---@field height integer|string|nil
---@field kind WinKind|nil
---@field kinds table<WinKind|string, FylerConfigWinKindOptions>|nil
---@field left integer|string|nil
---@field right integer|string|nil
---@field title_pos string|nil
---@field top integer|string|nil
---@field width integer|string|nil
---@field win_opts table<string, any>|nil

---@class FylerConfigViewsFinder
---@field close_on_select boolean|nil
---@field confirm_simple boolean|nil
---@field default_explorer boolean|nil
---@field delete_to_trash boolean|nil
---@field git_status FylerConfigGitStatus|nil
---@field icon table<string, string|nil>|nil
---@field indentscope FylerConfigIndentScope|nil
---@field mappings table<string, FylerConfigFinderMapping|function>|nil
---@field mappings_opts vim.keymap.set.Opts|nil
---@field follow_current_file boolean|nil
---@field win FylerConfigWin|nil

---@class FylerConfigViews
---@field finder FylerConfigViewsFinder|nil

---@class FylerConfig
---@field hooks table<string, any>|nil
---@field integrations FylerConfigIntegrations|nil
---@field views FylerConfigViews|nil

---@class FylerSetupIntegrations
---@field icon FylerConfigIntegrationsIcon|nil
---@field winpick FylerConfigWinpick|nil

---@class FylerSetupIndentScope
---@field enabled boolean|nil
---@field group string|nil
---@field marker string|nil

---@class FylerSetupWin
---@field border FylerConfigBorder|string[]|nil
---@field buf_opts table<string, any>|nil
---@field kind WinKind|nil
---@field kinds table<WinKind|string, FylerConfigWinKindOptions>|nil
---@field win_opts table<string, any>|nil

---@class FylerSetup
---@field hooks table<string, any>|nil
---@field integrations FylerSetupIntegrations|nil
---@field views FylerConfigViews|nil

--- CONFIGURATION
---
--- To setup Fyler put following code anywhere in your neovim runtime:
---
--- >lua
---   require("fyler").setup()
--- <
---
--- CONFIGURATION.DEFAULTS
---
--- To know more about plugin customization. visit:
--- `https://github.com/A7Lavinraj/fyler.nvim/wiki/configuration`
---
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@tag fyler.config
function config.defaults()
  return {
    -- Hooks are functions automatically called for corresponding events:
    -- hooks.on_delete:    function(path: string)
    -- hooks.on_rename:    function(src: string, dst: string)
    -- hooks.on_highlight: function(src: string, dst: string)
    hooks = {},
    -- Integration is a way to hijack generic plugin calls.
    integrations = {
      icon = "mini_icons",
      winpick = "none",
    },
    -- View is a plugin component with dedicated window, UI and config
    views = {
      finder = {
        -- Automatically closes after open a file
        close_on_select = true,
        -- Skip confirmation for simple operations
        confirm_simple = false,
        -- Disables NETRW and take over
        default_explorer = false,
        -- Move to trash instead of permanent delete
        delete_to_trash = false,
        -- Define order of information columns
        columns_order = { "link", "permission", "size", "git", "diagnostic" },
        -- Define configuration fo each available information column
        columns = {
          git = {
            enabled = true,
            symbols = {
              Untracked = "?",
              Added = "A",
              Modified = "M",
              Deleted = "D",
              Renamed = "R",
              Copied = "C",
              Conflict = "!",
              Ignored = " ",
            },
          },
          diagnostic = {
            enabled = true,
            symbols = {
              Error = "E",
              Warn = "W",
              Info = "I",
              Hint = "H",
            },
          },
          link = {
            enabled = true,
          },
          permission = {
            enabled = true,
          },
          size = {
            enabled = true,
          },
        },
        -- Overrides directory icons for vairous state
        icon = {
          directory_empty = nil,
          directory_expanded = nil,
          directory_collapsed = nil,
        },
        -- Defines indentation guides config
        indentscope = {
          enabled = true,
          markers = {
            { "│", "FylerIndentMarker" },
            { "└", "FylerIndentMarker" },
          },
        },
        -- Defines key mapping
        mappings = {
          ["q"] = "CloseView",
          ["<CR>"] = "Select",
          ["<C-t>"] = "SelectTab",
          ["|"] = "SelectVSplit",
          ["-"] = "SelectSplit",
          ["^"] = "GotoParent",
          ["="] = "GotoCwd",
          ["."] = "GotoNode",
          ["#"] = "CollapseAll",
          ["<BS>"] = "CollapseNode",
        },
        -- Defines key mapping options
        mappings_opts = {
          nowait = false,
          noremap = true,
          silent = true,
        },
        -- Automatically focus file in the finder UI
        follow_current_file = true,
        -- Automatically updated finder on file system events
        watcher = {
          enabled = false,
        },
        win = {
          border = vim.o.winborder == "" and "single" or vim.o.winborder,
          buf_opts = {
            bufhidden = "hide",
            buflisted = false,
            buftype = "acwrite",
            expandtab = true,
            filetype = "fyler",
            shiftwidth = 2,
            syntax = "fyler",
            swapfile = false,
          },
          kind = "replace",
          kinds = {
            float = {
              height = "70%",
              width = "70%",
              top = "10%",
              left = "15%",
            },
            replace = {},
            split_above = {
              height = "70%",
            },
            split_above_all = {
              height = "70%",
              win_opts = {
                winfixheight = true,
              },
            },
            split_below = {
              height = "70%",
            },
            split_below_all = {
              height = "70%",
              win_opts = {
                winfixheight = true,
              },
            },
            split_left = {
              width = "30%",
            },
            split_left_most = {
              width = "30%",
              win_opts = {
                winfixwidth = true,
              },
            },
            split_right = {
              width = "30%",
            },
            split_right_most = {
              width = "30%",
              win_opts = {
                winfixwidth = true,
              },
            },
          },
          win_opts = {
            concealcursor = "nvic",
            conceallevel = 3,
            cursorline = false,
            number = false,
            relativenumber = false,
            signcolumn = "no",
            winhighlight = "Normal:FylerNormal,NormalNC:FylerNormalNC",
            wrap = false,
          },
        },
      },
    },
  }
end

---@param name string
---@param kind WinKind|nil
---@return FylerConfigViewsFinder
function config.view_cfg(name, kind)
  local view = vim.deepcopy(config.values.views[name] or {})
  view.win = require("fyler.lib.util").tbl_merge_force(view.win, view.win.kinds[kind or view.win.kind])
  return view
end

---@param name string
---@return table<string, string[]>
function config.rev_maps(name)
  local rev_maps = {}
  for k, v in pairs(config.values.views[name].mappings or {}) do
    if type(v) == "string" then
      local current = rev_maps[v]
      if current then
        table.insert(current, k)
      else
        rev_maps[v] = { k }
      end
    end
  end

  setmetatable(rev_maps, {
    __index = function() return "<nop>" end,
  })

  return rev_maps
end

---@param name string
---@return table<string, function>
function config.usr_maps(name)
  local user_maps = {}
  for k, v in pairs(config.values.views[name].mappings or {}) do
    if type(v) == "function" then user_maps[k] = v end
  end

  return user_maps
end

--- INTEGRATIONS.ICON
---
--- Icon provider for file and directory icons.
---
--- >lua
---   integrations = {
---     icon = "mini_icons",        -- nvim-mini/mini.icons (default)
---     icon = "nvim_web_devicons", -- nvim-tree/nvim-web-devicons
---     icon = "vim_nerdfont",      -- lambdalisue/vim-nerdfont
---     icon = "none",              -- disable icons
---   }
--- <
---
--- INTEGRATIONS.WINPICK
---
--- Window picker for selecting which window to open files in (split kinds).
---
--- >lua
---   integrations = {
---     -- Use winpick = "<provider>" or { provider = "<provider>", opts = {} }
---     winpick = "none",
---     winpick = "snacks",
---     winpick = "builtin",
---     winpick = "nvim-window-picker",
---     winpick = function(win_filter, on_submit, opts)
---       -- custom logic...
---     end)
---   }
--- <
---
--- Custom winpick function example:
---
--- >lua
---   integrations = {
---     winpick = function(win_filter, on_submit, opts)
---       on_submit(require("window-picker").pick_window())
---     end,
---     opts = {}, -- this is what is passed as opts to the above function
---   }
--- <
---
---@tag fyler.setup

---@param opts FylerSetup|nil
function config.setup(opts)
  opts = opts or {}

  config.values = util.tbl_merge_force(config.defaults(), deprecated.migrate(opts, DEPRECATION_RULES))

  local icon_provider = config.values.integrations.icon
  if type(icon_provider) == "string" then
    config.icon_provider = require("fyler.integrations.icon")[icon_provider]
  else
    config.icon_provider = icon_provider
  end

  -- Support shorthand: winpick = "provider-name" or winpick = function
  local winpick_config = config.values.integrations.winpick
  local winpick_provider = type(winpick_config) == "table" and winpick_config.provider or winpick_config
  config.winpick_opts = type(winpick_config) == "table" and winpick_config.opts or {}
  if type(winpick_provider) == "string" then
    config.winpick_provider = require("fyler.integrations.winpick")[winpick_provider]
  else
    config.winpick_provider = winpick_provider
  end

  for _, sub_module in ipairs({
    "fyler.autocmds",
    "fyler.hooks",
    "fyler.lib.hl",
  }) do
    require(sub_module).setup(config)
  end
end

return config

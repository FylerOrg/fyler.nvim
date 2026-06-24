local finder = Fyler.import('fyler.finder')
local ns = vim.api.nvim_create_namespace('FylerIndentGuide')

---@param indents table<integer, integer>
---@param blanks table<integer, boolean>
---@param from integer
---@param bottom integer
---@param max_indent integer
---@return integer|nil
local function next_sibling_indent(indents, blanks, from, bottom, max_indent)
  for j = from + 1, bottom do
    if indents[j] == nil then return nil end
    if not blanks[j] and indents[j] <= max_indent then return indents[j] end
  end
  return nil
end

---@param indents table<integer, integer>
---@param blanks table<integer, boolean>
---@param from integer
---@param bottom integer
---@param level integer
---@return boolean
local function has_sibling_below(indents, blanks, from, bottom, level)
  for j = from + 1, bottom do
    if indents[j] == nil then return false end
    if not blanks[j] then
      if indents[j] < level then return false end
      if indents[j] == level then return true end
    end
  end
  return false
end

vim.api.nvim_set_decoration_provider(ns, {
  on_win = function(_, _, bufnr, toprow, botrow)
    local inst = finder.instance_get_or_nil(vim.api.nvim_get_current_tabpage())
    if not inst then return end

    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    if not (inst.cache.ui.indent_guides and vim.bo[bufnr].filetype == 'fyler_finder') then return end

    if toprow == 0 then
      toprow = toprow + 1
      botrow = botrow + 1
    end

    local sw = vim.bo[bufnr].shiftwidth
    if sw == 0 then sw = vim.bo[bufnr].tabstop end

    vim.api.nvim_buf_call(bufnr, function()
      -- Scan the FULL buffer so sibling lookups are never truncated by the
      -- visible window range.  line_count is 0-indexed from the API but
      -- vim.fn.* use 1-indexed lines, so scanbot is the last 1-indexed line.
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      local scantop = 1 -- always start from line 1
      local scanbot = line_count -- always scan to the last line

      local indents, blanks = {}, {}

      for l = scantop, scanbot do
        indents[l] = vim.fn.indent(l)
        if vim.fn.getline(l):find('^%s*$') then
          -- blank line: inherit indent from previous non-blank line
          local prev = vim.fn.prevnonblank(l)
          if prev > 0 then
            indents[l] = indents[prev] or vim.fn.indent(prev)
            -- not truly blank for guide purposes once we have an indent
          else
            blanks[l] = true
          end
        end
      end

      -- Only DRAW extmarks for the visible range (toprow..botrow)
      for l = toprow, botrow do
        local indent = indents[l]
        if indent and indent > 0 then
          local depth = indent / sw

          for lvl = 1, depth do
            local ilevel = lvl * sw
            local col = (lvl - 1) * sw
            local ch

            if lvl < depth then
              -- Use scanbot (full buffer) not botrow (visible window)
              ch = has_sibling_below(indents, blanks, l, scanbot, ilevel) and '│ ' or '  '
            else
              local ni = next_sibling_indent(indents, blanks, l, scanbot, indent)
              ch = (not ni or ni ~= indent) and '└╴' or '├╴'
            end

            vim.api.nvim_buf_set_extmark(bufnr, ns, l - 1, col, {
              virt_text = { { ch, 'FylerIndentGuide' } },
              virt_text_pos = 'overlay',
              hl_mode = 'combine',
            })
          end
        end
      end
    end)
  end,
})

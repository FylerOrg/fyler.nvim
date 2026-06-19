local finder = Fyler.import('fyler.finder')
local ns = vim.api.nvim_create_namespace('FylerIndentGuide')

---@param indents table<integer, integer> table of all indent levels for each line
---@param blanks table<integer, boolean> table storing whether line is blank
---@param from integer line to start scan from
---@param bottom integer bottom of scan range
---@param max_indent integer if next line has indent level greater than max_indent, then return nil as this is the final line in this level
---@return integer|nil
local function next_sibling_indent(indents, blanks, from, bottom, max_indent)
  for j = from + 1, bottom do
    if indents[j] == nil then return nil end
    if not blanks[j] and indents[j] <= max_indent then return indents[j] end
  end
  return nil
end

---check if the line has siblings at the same indent level below it
---@param indents table<integer, integer> table of all indent levels for each line
---@param blanks table<integer, boolean> table storing whether line is blank
---@param from integer line to start scan from
---@param bottom integer bottom of scan range
---@param level integer indent level to check for siblings
---@return boolean `true` if more siblings (same indent level) below
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
    if not (inst and inst.cache.ui.indent_guides and vim.bo[bufnr].filetype == 'fyler_finder') then return end

    if toprow == 0 then
      toprow = toprow + 1
      botrow = botrow + 1
    end

    local sw = vim.bo[bufnr].shiftwidth
    if sw == 0 then sw = vim.bo[bufnr].tabstop end

    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_call(bufnr, function()
      local indents, blanks = {}, {}

      for l = toprow, botrow do
        indents[l] = vim.fn.indent(l)
        if vim.fn.getline(l):find('^%s*$') then
          blanks[l] = true
          local prev = vim.fn.prevnonblank(l)
          if prev > 0 then
            indents[l] = indents[prev] or vim.fn.indent(prev)
            blanks[l] = nil
          end
        end
      end

      for l = toprow, botrow do
        local indent = indents[l]
        if indent > 0 then
          local depth = indent / sw
          local parts = {}

          for lvl = 1, depth do
            local ilevel = lvl * sw

            if lvl < depth then
              parts[#parts + 1] = has_sibling_below(indents, blanks, l, botrow, ilevel) and '│ ' or '  '
            else
              local ni = next_sibling_indent(indents, blanks, l, botrow, indent)
              parts[#parts + 1] = (not ni or ni ~= indent) and '└╴' or '├╴'
            end
          end

          vim.api.nvim_buf_set_extmark(bufnr, ns, l - 1, 0, {
            virt_text = { { table.concat(parts), 'FylerIndentGuide' } },
            virt_text_pos = 'overlay',
            hl_mode = 'combine',
          })
        end
      end
    end)
  end,
})

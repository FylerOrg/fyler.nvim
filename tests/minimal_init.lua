-- Immediately add plugins to runtimepath
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fs.joinpath(vim.fn.getcwd(), 'tmp', 'deps', 'mini.test'))

-- Clear all highlights (better for screenshots)
vim.cmd('hi! clear')

local shorten_path = function(bufname)
  bufname = bufname:gsub('\\', '/'):gsub('(fyler%-%w+)://.+/tmp/data', '%1://ROOT')
  if #bufname > 0 and not bufname:find('fyler%-%w+://') then bufname = vim.fn.fnamemodify(bufname, ':p') end
  return (bufname:gsub('^.+/tmp/data', 'ROOT'))
end

function _G.custom_statusline() return shorten_path(vim.fn.expand('%:p')) .. ' %l,%c%V' end

function _G.custom_tabline()
  local s = ''
  for i = 1, vim.fn.tabpagenr('$') do
    local winnr = vim.fn.tabpagewinnr(i)
    local bufnr = vim.fn.tabpagebuflist(i)[winnr]
    local label = shorten_path(vim.fn.bufname(bufnr))
    if label == '' then label = '[No Name]' end
    if i == vim.fn.tabpagenr() then
      s = s .. '%#TabLineSel#' .. label .. ' '
    else
      s = s .. '%#TabLine#' .. label .. ' '
    end
  end
  return s .. '%#TabLineFill#'
end

for o, v in pairs({
  background = 'dark',
  backup = false,
  cmdheight = 0,
  fillchars = {
    eob = ' ',
    horiz = '-',
    horizup = '-',
    horizdown = '-',
    vert = '|',
    vertleft = '|',
    vertright = '|',
    verthoriz = '+',
    fold = '-',
    foldopen = '-',
    foldclose = '+',
    foldsep = '|',
  },
  laststatus = 3,
  readonly = true,
  statusline = '%!v:lua.custom_statusline()',
  swapfile = false,
  tabline = '%!v:lua.custom_tabline()',
  writebackup = false,
}) do
  ---@diagnostic disable-next-line: assign-type-mismatch
  vim.opt[o] = v
end

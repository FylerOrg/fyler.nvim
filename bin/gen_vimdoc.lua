vim.iter({ 'nvim-mini/mini.doc' }):each(function(repo)
  local module_name = repo:match('/(.*)$')
  local install_path = string.format('%s/tmp/deps/%s', vim.fn.getcwd(), module_name)

  if not vim.uv.fs_stat(install_path) then
    print('* Downloading ' .. module_name .. " to '" .. install_path .. "/'")

    vim.system({ 'git', 'clone', '--depth=1', 'https://github.com/' .. repo, install_path }):wait()

    if vim.v.shell_error > 0 then error('Error while cloning dependency: ' .. module_name) end
  end

  vim.opt.runtimepath:append(install_path)
end)

vim.opt.runtimepath:append(vim.fn.getcwd())

local mini_doc_opts = {
  hooks = {
    file = function() end,
    sections = {
      ['@signature'] = function(s) s:remove() end,
      ['@return'] = function(s) s.parent:clear_lines() end,
      ['@alias'] = function(s) s.parent:clear_lines() end,
      ['@class'] = function(s) s.parent:clear_lines() end,
      ['@param'] = function(s) s.parent:clear_lines() end,
    },
  },
}

local doc_files = { 'lua/fyler.lua', 'lua/fyler/config.lua', 'lua/fyler/extensions.lua' }

require('mini.doc').generate(doc_files, 'doc/fyler.txt', mini_doc_opts)

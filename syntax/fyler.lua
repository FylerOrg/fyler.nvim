vim.cmd([[
  if exists("b:current_syntax")
    finish
  endif

  syn match FylerReferenceId / \/\d* / conceal

  let b:current_syntax = "Fyler"
]])

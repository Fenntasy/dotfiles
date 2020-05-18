augroup jsFolds
  autocmd!
  autocmd FileType javascript,typescript,json syntax region braceFold start="{" end="}" transparent fold
  autocmd FileType javascript,typescript,json syntax region bracketFold start="\[" end="\]" transparent fold
  autocmd FileType javascript,typescript,json syntax sync fromstart
  autocmd FileType javascript,typescript,json set foldmethod=syntax
augroup end

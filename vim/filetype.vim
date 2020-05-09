autocmd BufRead,BufNewFile Dockerfile,Dockerfile.* set filetype=dockerfile
autocmd BufRead,BufNewFile *.avsc set filetype=json
autocmd BufRead,BufNewFile *.dot.m4 set filetype=dot
autocmd BufReadPost,BufNewFile *.md set filetype=markdown
autocmd BufRead,BufNewFile *.slim set filetype=slim
autocmd BufRead,BufNewFile mix.lock set filetype=elixir
autocmd FileType markdown setlocal spell
autocmd FileType gitcommit setlocal spell
autocmd FileType eruby,html,slim setlocal cursorcolumn cursorline
autocmd FileType elm setlocal shiftwidth=4
autocmd FileType Makefile setlocal autoindent noexpandtab tabstop=4 shiftwidth=4

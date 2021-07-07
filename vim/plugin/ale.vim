let g:ale_fix_on_save = 1
let g:ale_completion_enabled = 1
let g:ale_cursor_detail = 0
let g:ale_elixir_elixir_ls_release = $HOME . '/Workspace/elixir/elixir-ls/release'
let g:ale_elixir_credo_strict = 1
let g:ale_go_langserver_executable = 'gopls'
let g:ale_keep_list_window_open = 0
let g:ale_lint_on_text_changed = 'never'
let g:ale_set_loclist = 1
let g:ale_sign_column_always = 1
let g:ale_sign_error = ' >'
let g:ale_sign_warning = ' !'
let g:ale_linters = {
\  'elixir': ['credo', 'elixir-ls'],
\  'css': ['stylelint'],
\}
" \  'javascript': ['eslint', 'tsserver'],
" \  'typescript': ['eslint', 'tsserver'],

let g:ale_fixers = {
\  '*': ['remove_trailing_lines', 'trim_whitespace'],
\  'elixir': ['mix_format'],
\  'go': ['gofmt'],
\  'json': ['eslint'],
\  'css': ['stylelint'],
\}
" \  'javascript': ['eslint'],
" \  'typescript': ['eslint'],
" \  'typescriptreact': ['eslint'],

nnoremap <silent> <leader>aj :ALENext<cr>
nnoremap <silent> <leader>ak :ALEPrevious<cr>
nnoremap <silent> <buffer> <C-]> :ALEGoToDefinition<cr>
nnoremap <silent> <buffer> <C-W><C-]> :ALEGoToDefinitionInVSplit<cr>
nnoremap <silent> gh :ALEHover<cr>

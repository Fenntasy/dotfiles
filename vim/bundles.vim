call plug#begin('~/.vim/plugged')

Plug 'chaoren/vim-wordmotion'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'ntpeters/vim-better-whitespace'
" Plug 'sheerun/vim-polyglot'
" Plug 'Valloric/YouCompleteMe', { 'do': './install.py --all' }
" Plug 'tpope/vim-commentary'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'kana/vim-textobj-user'
Plug 'michaeljsmith/vim-indent-object'
Plug 'scrooloose/nerdtree'
Plug 'junegunn/goyo.vim'
Plug 'tpope/vim-markdown'

" Elm
Plug 'elmcast/elm-vim'

" Elixir
Plug 'andyl/vim-textobj-elixir'

" JavaScript
Plug 'prettier/vim-prettier', { 'do': 'npm install' }

" Tests
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Themes
Plug 'chriskempson/base16-vim'
Plug 'aradunovic/perun.vim'

call plug#end()

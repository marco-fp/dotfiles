set number
set showmode
set autoread
set hidden
syntax on
set autoindent
set smartindent
set wrap
set linebreak
set scrolloff=8
set sidescrolloff=15
set sidescroll=1
set visualbell 
set backspace=indent,eol,start
set t_vb=

let g:javascript_plugin_flow = 1
let g:jsx_ext_required = 0

let g:ale_lint_on_save = 1
let g:ale_lint_on_text_changed = 0

colorscheme spacegray

call plug#begin('~/.vim/plugged')

Plug 'https://github.com/pangloss/vim-javascript.git'
Plug 'https://github.com/mxw/vim-jsx.git'
Plug 'https://github.com/christoomey/vim-tmux-navigator.git'
Plug 'https://github.com/leshill/vim-json.git'
Plug 'https://github.com/ajh17/Spacegray.vim.git'

call plug#end()

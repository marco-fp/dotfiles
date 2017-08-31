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
set mouse=a

let g:javascript_plugin_flow = 1
let g:jsx_ext_required = 0

let g:ale_lint_on_save = 1
let g:ale_lint_on_text_changed = 0
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab

colorscheme spacegray

call plug#begin('~/.vim/plugged')

Plug 'https://github.com/pangloss/vim-javascript.git'
Plug 'https://github.com/mxw/vim-jsx.git'
Plug 'https://github.com/christoomey/vim-tmux-navigator.git'
Plug 'https://github.com/leshill/vim-json.git'
Plug 'https://github.com/ajh17/Spacegray.vim.git'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'

call plug#end()


" This is the default extra key bindings
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" Default fzf layout
" - down / up / left / right
let g:fzf_layout = { 'down': '~40%' }

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

let g:fzf_history_dir = '~/.local/share/fzf-history'

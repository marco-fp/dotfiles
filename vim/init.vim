filetype on
set number
set mouse=a
set clipboard=unnamed
 
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab

filetype plugin indent on 

nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

nmap <F1> :Vexplore <CR>

nmap <C-s> <Esc> :w <CR>
imap <C-s> <Esc> :w <CR>

nmap <A-w> <Esc> :tabclose <CR>
imap <A-w> <Esc> :tabclose <CR>

nmap <A-h> <Esc> :tabp <CR>
imap <A-h> <Esc> :tabp <CR>

nmap <A-l> <Esc> :tabn <CR>
imap <A-l> <Esc> :tabn <CR>

"" NERDTree configuration
let g:NERDTreeChDirMode=2
let g:NERDTreeIgnore=['\.rbc$', '\~$', '\.pyc$', '\.db$', '\.sqlite$', '__pycache__']
let g:NERDTreeSortOrder=['^__\.py$', '\/$', '*', '\.swp$', '\.bak$', '\~$']
let g:NERDTreeShowBookmarks=0
let NERDTreeMinimalUI=1
let g:nerdtree_tabs_focus_on_files=1
let g:NERDTreeMapOpenInTabSilent = '<RightMouse>'
let g:NERDTreeWinSize = 25
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*.pyc,*.db,*.sqlite

nnoremap <silent> <F2> :NERDTreeFind<CR>
nnoremap <silent> <F3> :NERDTreeToggle<CR>

call plug#begin('~/.vim/plugged')

Plug 'ctrlpvim/ctrlp.vim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'Yggdroot/indentLine'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'airblade/vim-gitgutter'
Plug 'fatih/vim-go', {'do': ':GoInstallBinaries'}
Plug 'jelera/vim-javascript-syntax'
Plug 'prettier/vim-prettier', { 'do': 'yarn install' }

Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'fxn/vim-monochrome'

Plug 'scrooloose/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'jistr/vim-nerdtree-tabs'

call plug#end()

syntax on
let g:dracula_italic = 0
colorscheme dracula 
set noshowmode
highlight Normal ctermbg=None

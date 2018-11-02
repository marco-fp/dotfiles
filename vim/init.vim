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

tnoremap <Esc> <C-\><C-n>

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
let g:NERDTreeWinSize = 35
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

Plug 'pangloss/vim-javascript'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'chrisbra/vim-xml-ftplugin'

Plug 'prettier/vim-prettier', { 'do': 'yarn install' }
Plug 'Valloric/YouCompleteMe', { 'do': './install.py --tern-completer' }

Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'altercation/vim-colors-solarized'
Plug 'arcticicestudio/nord-vim', { 'branch': 'develop' }

Plug 'scrooloose/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'jistr/vim-nerdtree-tabs'

call plug#end()

syntax on
"" let g:dracula_italic = 0
"" colorscheme dracula 
"" colorscheme monochrome
set noshowmode
"" highlight Normal ctermbg=None

"" let g:solarized_termcolors=256 "this is what fixed it for me
"" let g:solarized_termtrans = 1 " This gets rid of the grey background
"" set background=dark
"" colorscheme solarized
"" colorscheme spacegray
colorscheme nord
let g:airline_theme='nord'
let g:nord_uniform_status_lines = 1
let g:nord_comment_brightness = 20
let g:nord_uniform_diff_background = 1
let g:nord_cursor_line_number_background = 1



let g:javascript_plugin_flow = 1
let g:vim_jsx_pretty_colorful_config = 1
"" Save prettify on file save
"" let g:prettier#autoformat = 0
"" autocmd BufWritePre *.js,*.css,*.scss,*.less PrettierAsync

set wildmode=list:longest,list:full
set wildignore+=*.o,*.obj,.git,*.rbc,*.pyc,__pycache__
let $FZF_DEFAULT_COMMAND =  "find * -path '*/\.*' -prune -o -path 'vendor/**' -prune -o -path 'node_modules/**' -prune -o -path 'target/**' -prune -o -path 'dist/**' -prune -o  -type f -print -o -type l -print 2> /dev/null"


" Start autocompletion after 4 chars
let g:ycm_min_num_of_chars_for_completion = 4
let g:ycm_min_num_identifier_candidate_chars = 4
let g:ycm_enable_diagnostic_highlighting = 0

" Don't show YCM's preview window [ I find it really annoying ]
set completeopt-=preview
let g:ycm_add_preview_to_completeopt = 0

"" Show all characters in json files
set conceallevel=0

set cursorline
let g:indentLine_char = '·'

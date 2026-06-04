" Bootstrap vim-plug
let data_dir = expand('~/.vim')
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fsSLo ' . data_dir . '/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'vim-airline/vim-airline'
Plug 'luochen1990/rainbow'
Plug 'hashivim/vim-terraform'
" Plug 'tpope/vim-sleuth'
Plug 'godlygeek/tabular'
Plug 'vim-python/python-syntax'
Plug 'andoriyu/salt-vim'
Plug 'elzr/vim-json'
Plug 'rhysd/conflict-marker.vim'
Plug 'justinmk/vim-matchparenalways'
" Plug 'airblade/vim-gitgutter'
Plug 'psycofdj/yaml-path'
" Plug 'tpope/vim-markdown'
" Plug 'preservim/vim-markdown'
" Plug 'gabrielelana/vim-markdown'

call plug#end()

autocmd VimEnter *
  \  if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \|   PlugInstall --sync | source $MYVIMRC
  \| endif


syntax on
filetype plugin indent on


" http://blog.smalleycreative.com/tutorials/using-git-and-github-to-manage-your-dotfiles/
set nocompatible          " get rid of Vi compatibility mode. SET FIRST!
filetype plugin indent on " filetype detection[ON] plugin[ON] indent[ON]
set t_Co=256              " enable 256-color mode.
syntax enable             " enable syntax highlighting (previously syntax on).
"colorscheme desert        " set colorscheme
"set number                " show line numbers
set laststatus=2          " last window always has a statusline
filetype indent on        " activates indenting for files
set nohlsearch            " Don't continue to highlight searched phrases.
set incsearch             " But do highlight as you type your search.
set ignorecase            " Make searches case-insensitive.
set ruler                 " Always show info along bottom.
set autoindent            " auto-indent
set tabstop=4             " tab spacing
set softtabstop=4         " unify
set shiftwidth=4          " indent/outdent by 4 columns
set shiftround            " always indent/outdent to the nearest tabstop
set expandtab             " use spaces instead of tabs
set smarttab              " use tabs at the start of a line, spaces elsewhere
set nowrap                " don't wrap text
set hlsearch              " highlight search




" vimrc file for following the coding standards specified in PEP 7 & 8.
"
" To use this file, source it in your own personal .vimrc file (``source
" <filename>``) or, if you don't have a .vimrc file, you can just symlink to it
" (``ln -s <this file> ~/.vimrc``).  All options are protected by autocmds
" (read below for an explanation of the command) so blind sourcing of this file
" is safe and will not affect your settings for non-Python or non-C files.
"
"
" All setting are protected by 'au' ('autocmd') statements.  Only files ending
" in .py or .pyw will trigger the Python settings while files ending in *.c or
" *.h will trigger the C settings.  This makes the file "safe" in terms of only
" adjusting settings for Python and C files.
"
" Only basic settings needed to enforce the style guidelines are set.
" Some suggested options are listed but commented out at the end of this file.


" Number of spaces to use for an indent.
" This will affect Ctrl-T and 'autoindent'.
" Python: 4 spaces
" C: 8 spaces (pre-existing files) or 4 spaces (new files)
au BufRead,BufNewFile *.py,*pyw,*wsgi set shiftwidth=4

" Number of spaces that a pre-existing tab is equal to.
" For the amount of space used for a new tab use shiftwidth.
" Python: 8
" C: 8
au BufRead,BufNewFile *py,*pyw,*.wsgi set tabstop=8
au BufRead,BufNewFile *py,*pyw,*.wsgi set softtabstop=4

" Replace tabs with the equivalent number of spaces.
" Also have an autocmd for Makefiles since they require hard tabs.
" Python: yes
" C: no
" Makefile: no
au BufRead,BufNewFile *.py,*.pyw,*.wsgi set expandtab

" Use the below highlight group when displaying bad whitespace is desired
highlight BadWhitespace ctermbg=red guibg=red

" Display tabs at the beginning of a line in Python mode as bad.
au BufRead,BufNewFile *.py,*.pyw,*.wsgi match BadWhitespace /^\t\+/
" Make trailing whitespace be flagged as bad.
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" Wrap text after a certain number of characters
" Python: 79
" C: 79
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*.wsgi set textwidth=179

" Turn off settings in 'formatoptions' relating to comment formatting.
" - c : do not automatically insert the comment leader when wrapping based on
"    'textwidth'
" - o : do not insert the comment leader when using 'o' or 'O' from command mode
" - r : do not insert the comment leader when hitting <Enter> in insert mode
" Python: not needed
" C: prevents insertion of '*' at the beginning of every line in a comment
au BufRead,BufNewFile *.c,*.h set formatoptions-=c formatoptions-=o formatoptions-=r

" Use UNIX (\n) line endings.
" Only used for new files so as to not force existing files to change their
" line endings.
" Python: yes
" C: yes
au BufNewFile *.py,*.pyw,*.c,*.h,*.wsgi set fileformat=unix


" ----------------------------------------------------------------------------
" The following section contains suggested settings.  While in no way required
" to meet coding standards, they are helpful.

" Set the default file encoding to UTF-8: ``set encoding=utf-8``

" Puts a marker at the beginning of the file to differentiate between UTF and
" UCS encoding (WARNING: can trick shells into thinking a text file is actually
" a binary file when executing the text file): ``set bomb``

" For full syntax highlighting:
let python_highlight_all=1
"syntax on

" Automatically indent based on file type: ``
"filetype indent on
" Keep indentation level from previous line:
"set autoindent

" Folding based on indentation: ``set foldmethod=indent``
"set shiftwidth=4
autocmd BufRead *.py set smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class
au BufRead,BufNewFile *.py,*.pyw,*.wsgi set syntax=python
autocmd BufReadPost *.tpl :e ++enc=cp1251
autocmd BufWritePre *.tpl :set fileencoding=cp1251
au BufRead,BufNewFile *.tpl set filetype=smarty
"set autoindent
"set expandtab
"set softtabstop=4
"set shiftwidth=4
"
"http://vim.wikia.com/wiki/Toggle_auto-indenting_for_code_paste
nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>
set showmode


"http://stackoverflow.com/questions/953398/how-to-execute-file-im-editing-in-vim
function! Setup_ExecNDisplay()
  execute "w"
  execute "silent !chmod +x %:p"
  let n=expand('%:t')
  execute "silent !%:p 2>&1 | tee ~/.vim/output_".n
  " I prefer vsplit
  "execute "split ~/.vim/output_".n
  execute "vsplit ~/.vim/output_".n
  execute "redraw!"
  set autoread
endfunction

function! ExecNDisplay()
  execute "w"
  let n=expand('%:t')
  execute "silent !%:p 2>&1 | tee ~/.vim/output_".n
  " I use set autoread
  "execute "1 . 'wincmd e'"
endfunction

:nmap <F9> :call Setup_ExecNDisplay()<CR>
:nmap <F10> :call ExecNDisplay()<CR>

nmap <F5> :w<CR>:silent !chmod 755 %<CR>:!./% <CR>

nmap <F6> :set syntax=whitespace<CR>

nmap <F7> :set wrap!<CR>

nmap <F8> :%!iconv -f utf-8 -t ascii//translit<CR>

" auto convert fancy unicode characters
:autocmd BufWritePost <buffer> !iconv -f utf-8 -t ascii//translit %

"set laststatus=2 "show the status line
"set statusline=%-10.3n "buffer number
map <silent> <leader>2 :diffget 2<CR> :diffupdate<CR>
map <silent> <leader>3 :diffget 3<CR> :diffupdate<CR>
map <silent> <leader>4 :diffget 4<CR> :diffupdate<CR>

" file is large from 10mb
let g:LargeFile = 1024 * 1024 * 10
augroup LargeFile
 autocmd BufReadPre * let f=getfsize(expand("<afile>")) | if f > g:LargeFile || f == -2 | call LargeFile() | endif
augroup END

function LargeFile()
 " no syntax highlighting etc
 set eventignore+=FileType
 " save memory when other file is viewed
 setlocal bufhidden=unload
 " is read-only (write with :w new_filename)
 setlocal buftype=nowrite
 " no undo possible
 setlocal undolevels=-1
 " display message
 autocmd VimEnter *  echo "The file is larger than " . (g:LargeFile / 1024 / 1024) . " MB, so some options are changed (see .vimrc for details)."
endfunction

autocmd Filetype ruby setlocal ts=2 sts=2 sw=2
autocmd Filetype terraform setlocal ts=2 sts=2 sw=2

nnoremap <F3> :set list! list?<CR>
nnoremap <F4> :set relativenumber! relativenumber?<CR>
nnoremap <F1> :set wrap! wrap?<CR>

let g:rainbow_active = 1 "0 if you want to enable it later via :RainbowToggle

" http://vim.wikia.com/wiki/Toggle_between_tabs_and_spaces
" virtual tabstops using spaces
let my_tab=4
execute "set shiftwidth=".my_tab
execute "set softtabstop=".my_tab
set expandtab
" allow toggling between local and default mode
function! TabToggle()
  if &expandtab
    set shiftwidth=8
    set softtabstop=0
    set noexpandtab
  else
    execute "set shiftwidth=".g:my_tab
    execute "set softtabstop=".g:my_tab
    set expandtab
  endif
endfunction
nmap <F9> mz:execute TabToggle()<CR>'z

" force markdown
autocmd BufNewFile,BufReadPost *.md set filetype=markdown

" Templates
au BufNewFile */roles/*.rb 0r ~/.vim/chef_role.rb.skel

" in makefiles, don't expand tabs to spaces, since actual tab characters are
" needed, and have indentation at 8 chars to be sure that all indents are tabs
" (despite the mappings later):
autocmd FileType make set noexpandtab shiftwidth=8 softtabstop=0

autocmd FileType md set textwidth=80

" Disable annoying beeping
set noerrorbells
set vb t_vb=

" Disable concealing quotes in vim-json plugin
let g:vim_json_syntax_conceal = 0


" fix yaml indentation jumps
" https://stackoverflow.com/a/37488992
"  filetype plugin indent on
" autocmd FileType yml,yaml,yaml.gotmpl setlocal ts=2 sts=2 sw=2 expandtab " indentkeys-=0# indentkeys-=<:>
"  autocmd FileType sh,shell setlocal ts=4 sts=4 sw=4 expandtab

"syntax enable
"set smartindent
"set tabstop=4
"set shiftwidth=4
"set expandtab
"autocmd FileType javascript set tabstop=2|set shiftwidth=2|set expandtab
"autocmd FileType sh set tabstop=4|set shiftwidth=4|set expandtab

" filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

autocmd FileType sh,shell set tabstop=4|set shiftwidth=4|set expandtab

" https://stackoverflow.com/a/15459337
function ExtendedHome()
    let column = col('.')
    normal! ^
    if column == col('.')
        normal! 0
    endif
endfunction
noremap <silent> <Home> :call ExtendedHome()<CR>
inoremap <silent> <Home> <C-O>:call ExtendedHome()<CR>


" https://stackoverflow.com/a/73129790 move between visible lines, not real
" lines
nnoremap <Up> gk
nnoremap gk k
nnoremap <Down> gj
nnoremap gj j

" https://stackoverflow.com/a/982252
set scrolloff=3 " Keep 3 lines below and above the cursor

highlight MatchParen ctermfg=black ctermbg=159 gui=underline
" term=underline cterm=underline

" Uncomment the following to have Vim jump to the last position when
" reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" set list listchars=tab:>-

" https://github.com/psycofdj/yaml-path/blob/master/plugin/README.md
" let yamlpath_auto=1

" highlight link markdownCode somegroup
" highlight link markdownCodeBlock somegroup

" autocmd BufNewFile,BufReadPost *.yaml,*.yml,*yaml.gotmpl set filetype=yaml
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab " indentkeys-=0# indentkeys-=<:>


" set langmap=wd,WD

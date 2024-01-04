" SPDX-License-Identifier: GPL-3.0-or-later
"
" My personal vim settings
"
" Copyright (C) 2017-2019 Nathan Chancellor

if &shell =~# 'fish$'
    set shell=sh
endif

" Special indenting for C and Makefiles (since most will be kernel files)
filetype plugin indent on

" Sexy af status line
set laststatus=2                            " Always show status line
set statusline=
set statusline+=%f                          " Show relative path of file being edited
set statusline+=\ %{FugitiveStatusline()}   " Show git branch if applicable
set statusline+=%=                          " Column break
set statusline+=\ %l\:%v                    " Show line and column
set statusline+=\ \(%p%%\)                  " Show location of cursor location percentage

" Ensure color scheme always works
set background=dark

syntax enable                               " Enable syntax processing
set tabstop=4                               " Show tabs as four spaces
set softtabstop=4                           " When hit, tab = 4 spaces
set shiftwidth=4                            " When indenting with '>', use 4 spaces width
set expandtab                               " Hitting tab generates four spaces
set number                                  " Show line numbers when editing
set showcmd                                 " Show last command
set cursorline                              " Show current selected line
set wildmenu                                " Show auto completion menu when typing commands
set incsearch                               " Show search results in realtime
set hlsearch                                " Highlight search matches
set lazyredraw                              " Redraw only when we need to
set modeline                                " For whatever reason, Ubuntu doesn't have this set by default
set wrap                                    " Wrap lines over a certain length. This is on by default with Arch and I am used to it...
set tabpagemax=100                          " Allow me to open up to 100 tabs
set history=10000                           " Remember a large amount of commands

" Shut up all bells
set noerrorbells visualbell t_vb=
autocmd GUIEnter * set visualbell t_vb=

highlight ColorColumn ctermbg=0 guibg=lightgrey

" Map Ctrl + left/right arrow keys to Home and End
inoremap <esc>[1;5D <C-o>0
inoremap <esc>[1;5C <C-o>$
nnoremap <esc>[1;5D 0
nnoremap <esc>[1;5C $

" Map Alt + left/right arrow keys to move one word like most shells
noremap <esc>[1;3C w
noremap <esc>[1;3D b

" Move to beginning/end of line or skip letters
nnoremap B 0
nnoremap E $

" 0/$/^ doesn't do anything
nnoremap 0 <nop>
nnoremap $ <nop>

" Toggle between tabs and spaces
function! TglInd()
    if(&expandtab == 1)
        set noexpandtab
        set tabstop=8
        set softtabstop=8
        set shiftwidth=8
    else
        set expandtab
        set tabstop=4
        set softtabstop=4
        set shiftwidth=4
    endif
endfunc

" Toggle color column
function! TglCC()
    if(&colorcolumn == 80)
        set colorcolumn=0
    else
        set colorcolumn=80
    endif
endfunc

" Strip trailing whitespace
nnoremap <silent> -- :let _s=@/ <Bar> :%s/\s\+$//e <Bar> :let @/=_s <Bar> :nohl <Bar> :unlet _s <CR>

" clang-format
map <C-K> :py3f /usr/share/clang/clang-format.py<cr>
imap <C-K> <c-o>:py3f /usr/share/clang/clang-format.py<cr>

" highlight trailing whitespace in red
hi ExtraWhitespace ctermbg=darkred
match ExtraWhitespace /\s\+$/
au BufWinEnter * match ExtraWhitespace /\s\+$/

" highlight tabs in yellow
hi Tabs ctermbg=yellow
call matchadd('Tabs', '\t')
au BufWinEnter * call matchadd('Tabs', '\t')
if version >= 702
  au BufWinLeave * call clearmatches()
endif

" When editing a file, always jump to the last known cursor position.
" Don't do it when the position is invalid, when inside an event handler
" (happens when dropping a file on gvim) and for a commit message (it's
" likely a different one than last time).
autocmd BufReadPost *
  \ if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit'
  \ |   exe "normal! g`\""
  \ | endif

" Skeleton files
autocmd BufNewFile *.fish 0r $ENV_FOLDER/configs/common/vim/skeletons/fish
autocmd BufNewFile *.py 0r $ENV_FOLDER/configs/common/vim/skeletons/python
autocmd BufNewFile *.sh 0r $ENV_FOLDER/configs/common/vim/skeletons/bash

" Spell check certain files automatically
autocmd FileType gitcommit setlocal spell
autocmd FileType markdown setlocal spell
autocmd FileType rst setlocal spell

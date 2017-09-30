"
" My personal vim settings
"
" Copyright (C) 2017 Nathan Chancellor
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>

" Special indenting for C and Makefiles (since most will be kernel files)
filetype plugin indent on

" Sexy af status line
set laststatus=2                            " Always show status line
set statusline=
set statusline+=%f                          " Show relative path of file being edited
set statusline+=\ %{fugitive#statusline()}  " Show git branch if applicable
set statusline+=%=                          " Column break
set statusline+=\ %l\:%v                    " Show line and column
set statusline+=\ \(%p%%\)                  " Show location of cursor location percentage


colorscheme cobalt                          " Dope af
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
set mouse=a                                 " Enable mouse in all modes

highlight ColorColumn ctermbg=0 guibg=lightgrey

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
    else
        set expandtab
        set tabstop=4
        set softtabstop=4
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

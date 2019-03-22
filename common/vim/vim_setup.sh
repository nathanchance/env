#!/usr/bin/env bash

# Move into the folder this script is being run from
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" || return

# Colors
COLORS=${HOME}/.vim/colors
mkdir -p "${COLORS}"
curl -LSso "${COLORS}"/cobalt.vim https://github.com/gkjgh/cobalt/raw/master/colors/cobalt.vim

# Indents
INDENT=${HOME}/.vim/indent
mkdir -p "${INDENT}"
cp -v indent/make.vim "${INDENT}"

# Plugins
PLUGIN=${HOME}/.vim/plugin
START=${HOME}/.vim/my-plugins/start
mkdir -p "${PLUGIN}" "${START}"
if [[ ! -d ${START}/vim-fugitive ]]; then
    git -C "${START}" clone https://github.com/tpope/vim-fugitive
else
    git -C "${START}"/vim-fugitive pull
fi
if [[ ! -d ${START}/vim-linux-coding-style ]]; then
    git -C "${START}" clone https://github.com/vivien/vim-linux-coding-style
else
    git -C "${START}"/vim-linux-coding-style pull
fi
curl -LSso "${PLUGIN}"/git_patch_tags.vim https://www.vim.org/scripts/download_script.php?src_id=20912

# .vimrc
cp .vimrc "${HOME}"

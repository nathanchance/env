#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Copyright (C) 2021 Nathan Chancellor

# Move into the folder this script is being run from
VIM=$(dirname "$(readlink -f "${0}")")

# Indents
INDENT=${HOME}/.vim/indent
mkdir -p "${INDENT}"
ln -fsv "${VIM}"/indent/make.vim "${INDENT}"/make.vim

# Plugins
PLUGIN=${HOME}/.vim/plugin
START=${HOME}/.vim/pack/my-plugins/start

mkdir -p "${PLUGIN}" "${START}"

[[ -d ${START}/vim-fish ]] || git -C "${START}" clone https://github.com/blankname/vim-fish
git -C "${START}"/vim-fish pull

[[ -d ${START}/vim-fugitive ]] || git -C "${START}" clone https://github.com/tpope/vim-fugitive
git -C "${START}"/vim-fugitive pull

[[ -d ${START}/vim-linux-coding-style ]] || git -C "${START}" clone https://github.com/vivien/vim-linux-coding-style
git -C "${START}"/vim-linux-coding-style pull

[[ -d ${START}/vim-one ]] || git -C "${START}" clone https://github.com/rakr/vim-one
git -C "${START}"/vim-one pull

curl -LSso "${PLUGIN}"/git_patch_tags.vim 'https://www.vim.org/scripts/download_script.php?src_id=20912'

# .vimrc
ln -fsv "${VIM}"/.vimrc "${HOME}"/.vimrc

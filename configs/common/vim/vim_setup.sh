#!/usr/bin/env zsh

# Move into the folder this script is being run from
cd "$(dirname "$(readlink -f "${0}")")" || return

# Indents
INDENT=${HOME}/.vim/indent
mkdir -p "${INDENT}"
ln -fs "${PWD}"/indent/make.vim "${INDENT}"/make.vim

# Plugins
PLUGIN=${HOME}/.vim/plugin
START=${HOME}/.vim/pack/my-plugins/start
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
if [[ ! -d ${START}/vim-one ]]; then
    git -C "${START}" clone https://github.com/rakr/vim-one
else
    git -C "${START}"/vim-one pull
fi
curl -LSso "${PLUGIN}"/git_patch_tags.vim 'https://www.vim.org/scripts/download_script.php?src_id=20912'

# .vimrc
ln -fs "${PWD}"/.vimrc "${HOME}"/.vimrc

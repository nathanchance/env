#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function git_setup -d "Configure git"
    git config --global user.name "Nathan Chancellor"
    git config --global user.email "nathan@kernel.org"

    git config --global core.editor vim

    git config --global branch.sort -committerdate

    git config --global color.ui auto

    git config --global diff.renamelimit 0

    git config --global init.defaultBranch main

    git config --global pull.rebase false

    git config --global sendemail.smtpEncryption tls
    git config --global sendemail.smtpServer mail.kernel.org
    git config --global sendemail.smtpServerPort 587
    git config --global sendemail.smtpUser nathan

    if gpg_key_usable
        git config --global commit.gpgsign true
        git config --global user.signingkey 1D6B269171C01A96
    end

    git config --global url."https://github.com".insteadOf git://github.com
    git config --global url."https://git.kernel.org".insteadOf git://git.kernel.org

    if command -q delta
        git config --global core.pager "env LESS=RF delta"

        git config --global interactive.diffFilter "delta --color-only"

        git config --global delta.dark true
        git config --global delta.file-added-label [A]
        git config --global delta.file-copied-label [C]
        git config --global delta.file-decoration-style "yellow ul"
        git config --global delta.file-modified-label [M]
        git config --global delta.file-removed-label [D]
        git config --global delta.file-renamed-label [R]
        git config --global delta.file-style yellow
        git config --global delta.hunk-header-decoration-style "purple box"
        git config --global delta.hunk-header-style normal
        git config --global delta.line-numbers true
        git config --global delta.line-numbers-minus-style red
        git config --global delta.line-numbers-plus-style green
        git config --global delta.line-numbers-zero-style 252
        git config --global delta.minus-emph-style "white 124"
        git config --global delta.minus-style "red bold"
        git config --global delta.navigate true
        git config --global delta.plus-emph-style "black 40"
        git config --global delta.plus-style "green bold"
        git config --global delta.right-arrow "->"
        git config --global delta.zero-style normal

        git config --global diff.colorMoved true

        git config --global merge.conflictstyle diff3
    else
        git config --global core.pager "less -+X"
    end

    git_aliases

    if command -q gh; and gh auth status &>/dev/null
        if not gh extension list &| grep -q gennaro-tedesco/gh-f
            gh extension install gennaro-tedesco/gh-f
        end
    end
end

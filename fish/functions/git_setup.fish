#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function git_setup -d "Configure git"
    git config --global user.name "Nathan Chancellor"
    git config --global user.email "nathan@kernel.org"

    git config --global core.editor vim

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

    git_aliases
end

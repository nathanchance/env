#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function sync_aur_pkgs -d "Sync vendored AUR packages"
    for pkg in $argv
        set pkgdir $ENV_FOLDER/pkgbuilds/aur/$pkg

        rm -fr $pkgdir
        and git clone https://aur.archlinux.org/$pkg.git $pkgdir
        and rm -fr $pkgdir/.{git,SRCINFO}
        or break
    end
end

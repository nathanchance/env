#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_gen_korg_readme -d "Generate kernel.org toolchains README"
    if not in_orb
        print_error "README should be generated from within OrbStack"
        return 1
    end
    if not in_venv
        py_venv c e markdown
        and pip install --upgrade \
            markdown \
            pip \
            pymdown-extensions
    end

    for arg in $argv
        switch $arg
            case -p --prompt-for-new-versions
                set versions_prompt true
            case llvm rust
                if set -q tc
                    print_error "Toolchain has already been specified ('$tc') but another one was supplied ('$arg')?"
                    return 1
                else
                    set tc $arg
                end
            case '*'
                if set -q old_ver
                    if set -q new_ver
                        print_error "Unexpected argument ('$arg') found?"
                        return 1
                    else
                        set new_ver $arg
                    end
                else
                    set old_ver $arg
                end
        end
    end
    if not set -q tc
        print_error "No toolchain set?"
        return 1
    end
    if set -q old_ver; and not set -q new_ver
        print_error "Old version supplied without new version?"
        return 1
    end

    switch $tc
        case llvm
            set md_base 'LLVM toolchains README.md'
        case rust
            set md_base 'LLVM+Rust toolchains README.md'
    end

    set md $MAC_FOLDER(dirname $ICLOUD_DOCS_FOLDER)/iCloud~md~obsidian/Documents/Tech/Kernel/Work/$md_base
    if not test -e $md
        print_error "$md does not exist?"
        return 1
    end

    set mac_html /Users/$USER/Downloads/$tc-index.html
    set lnx_html $MAC_FOLDER$mac_html

    if set -q versions_prompt
        read -l -P 'Old version: ' old_ver
        read -l -P 'New version: ' new_ver
    end
    if set -q old_ver; and set -q new_ver
        sed -i "s;$old_ver;$new_ver;g" $md
    end

    python -m markdown \
        -f $lnx_html \
        -x pymdownx.superfences \
        -x tables \
        $md
    or return

    rm -f $lnx_html.asc
    gpg --detach-sign --armor $lnx_html
    or return

    mac open $mac_html
    or return

    py_venv x r markdown

    set tailscale $MAC_FOLDER/Applications/Tailscale.app/Contents/MacOS/Tailscale
    if test -e $tailscale; and $tailscale status &>/dev/null
        set ip ($tailscale ip -4 thelio-3990X)
    else
        set ip 192.168.4.188
    end
    rsync --progress $lnx_html* nathan@$ip:$NVME_FOLDER/tmp/pgo-llvm-builder-staging
end

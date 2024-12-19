#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_upload_korg_llvm -d "Upload kernel.org toolchain releases with kup"
    if test $PWD != $TMP_FOLDER/pgo-llvm-builder-staging
        print_error "Not in $TMP_FOLDER/pgo-llvm-builder-staging?"
        return 1
    end

    set kup_src $SRC_FOLDER/kup
    set kup $kup_src/kup

    if not test -e $kup
        mkdir -p (dirname $kup_src)
        git clone https://git.kernel.org/pub/scm/utils/kup/kup.git $kup_src
        or return
    end
    if not test -e $HOME/.kuprc
        printf 'host = git@gitolite.kernel.org\nsubcmd = kup-server\n' >$HOME/.kuprc
    end

    for tar in *.tar
        if string match -qr -- '-[0-9a-f]{40}-' $tar
            set -a prerelease_tars $tar
        else if string match -qr -- -rust- $tar
            set -a rust_tars $tar
        else
            set -a release_tars $tar
        end

        rm -f $tar.asc

        gpg --detach-sign --armor $tar
        or return
    end

    if test -n "$release_tars"; and not test -f llvm-index.html
        print_error 'No index.html generated for LLVM?'
        return 1
    end
    if test -n "$rust_tars"; and not test -f rust-index.html
        print_error 'No index.html generated for Rust?'
        return 1
    end

    for tar in $release_tars
        $kup put $tar{,.asc} /pub/tools/llvm/files/$tar.gz
        or return

        set llvm_ver (string match -gr 'llvm-([0-9|.]+)' $tar)
        if test (string split . $llvm_ver | count) != 3
            print_error "Malformed LLVM version found ('$llvm_ver')?"
            return 1
        end
        if not contains $llvm_ver $llvm_vers
            set -a llvm_vers $llvm_ver
        end
    end
    for tar in $rust_tars
        $kup put $tar{,.asc} /pub/tools/llvm/rust/files/$tar.gz
        or return
    end
    if test -n "$release_tars"
        $kup put llvm-index.html{,.asc} /pub/tools/llvm/index.html
        or return

        if test (count $llvm_vers) = 1
            set llvm_maj (string split -f 1 . $llvm_ver)
            echo "Hi all,

I have built and uploaded LLVM $llvm_ver to
https://mirrors.edge.kernel.org/pub/tools/llvm/.

If there are any issues found, please let us know via email or
https://github.com/ClangBuiltLinux/linux/issues/new, so that we have an
opportunity to get them fixed in main and backported before the $llvm_maj.x
series is no longer supported.

Cheers,
Nathan" >msg

            for korg_user in conor ojeda
                set -a mutt_args -c $korg_user@kernel.org
            end
            echo "#!/usr/bin/env fish

echo 'Contents of msg for mailing list announcement:'
echo
cat msg
echo

read -P 'Would you like to edit the mailing list announcement before sending? [Y/N] ' req
if test (string lower \$req) = y
    \$EDITOR msg
end

read -P 'Send mailing list announcement? [Y/N] ' req
if test (string lower \$req) = y
    mutt $mutt_args -s 'Prebuilt LLVM $llvm_ver uploaded' -- llvm@lists.linux.dev linux-kernel@vger.kernel.org <msg
end

read -P 'Would you like to link announcement on GitHub issue? [Y/N] ' req
if test (string lower \$req) = y
    read -P 'GitHub issue: ' gh_issue
    read -P 'lore.kernel.org Message-ID: ' msg_id

    if test -n \"\$gh_issue\"; and test -n \"\$msg_id\"
        gh -R ClangBuiltLinux/linux issue comment \$gh_issue -b \"$llvm_ver uploaded to kernel.org: https://lore.kernel.org/\$msg_id/\"
    end
end" >announce
            chmod +x announce
        end
    end
    if test -n "$rust_tars"
        $kup put rust-index.html{,.asc} /pub/tools/llvm/rust/index.html
        or return
    end

    for tar in $prerelease_tars
        $kup put $tar{,.asc} /pub/tools/llvm/files/prerelease/$tar.gz
        or return

        set -l target_arch (string split -f 2 -m 1 -r - $tar)
        $kup ln /pub/tools/llvm/files/prerelease/{$tar,llvm-main-latest-$target_arch.tar}.gz
        or return
    end
    bell
end

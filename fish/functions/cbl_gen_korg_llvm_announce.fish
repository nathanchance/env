#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function cbl_gen_korg_llvm_announce -d "Generate kernel.org LLVM release announcement"
    if test $PWD != $TMP_FOLDER/pgo-llvm-builder-staging
        __print_error "Not in $TMP_FOLDER/pgo-llvm-builder-staging?"
        return 1
    end

    if not test (count $argv) -eq 1
        __print_error (status function)' <ver>'
        return 1
    end

    set llvm_ver $argv[1]
    set llvm_maj (string split -f 1 . $llvm_ver)

    for korg_user in ojeda
        set -a mutt_args -c $korg_user@kernel.org
    end

    begin
        echo "Hi all,

I have built and uploaded LLVM $llvm_ver to
https://mirrors.edge.kernel.org/pub/tools/llvm/.
"
        if string match -qr -- -rc $llvm_ver
            echo "This is a prerelease version of LLVM, similar to how the Linux kernel
release candidates work. If there are any issues found, please let us
know via email or https://github.com/ClangBuiltLinux/linux/issues/new,
so that we have an opportunity to get them fixed in main and backported
to the $llvm_maj.x branch before $llvm_maj.1.0 is officially released."
        else
            echo "If there are any issues found, please let us know via email or
https://github.com/ClangBuiltLinux/linux/issues/new, so that we have an
opportunity to get them fixed in main and backported before the $llvm_maj.x
series is no longer supported."
        end
        echo "
Cheers,
Nathan"
    end >msg

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

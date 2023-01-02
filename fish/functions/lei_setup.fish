#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function lei_setup -d "Sets up local email interface for Linux kernel mailing lists"
    # Make sure that folders exists that will hold configuration files
    mkdir -p $XDG_FOLDER/{cache,config,share}/lei $MAIL_FOLDER

    # Setup query for certain lists that are interesting
    set -a lists_query l:kernel-janitors.vger.kernel.org
    set -a lists_query OR
    set -a lists_query l:linux-arm-kernel.lists.infradead.org
    set -a lists_query OR
    set -a lists_query l:linux-kbuild.vger.kernel.org
    set -a lists_query OR
    set -a lists_query l:linux-kernel.vger.kernel.org
    set -a lists_query OR
    set -a lists_query l:linux-m68k.vger.kernel.org
    set -a lists_query OR
    set -a lists_query l:linux-next.vger.kernel.org
    set -a lists_query OR
    set -a lists_query l:linuxppc-dev.lists.ozlabs.org
    set -a lists_query OR
    set -a lists_query l:linux-riscv.lists.infradead.org
    set -a lists_query OR
    set -a lists_query l:linux-s390.vger.kernel.org
    set -a lists_query OR
    set -a lists_query l:stable.vger.kernel.org
    set -a lists_query OR
    set -a lists_query l:tools.linux.kernel.org
    set -a lists_query OR
    set -a lists_query l:workflows.vger.kernel.org

    lei q -I https://lore.kernel.org/all/ -o $MAIL_FOLDER/lists --dedupe=mid "($lists_query) AND rt:1.week.ago.."

    # Setup query for LLVM mail that might not be CC'd to llvm@lists.linux.dev or me
    set -a lists_query OR l:netdev.vger.kernel.org
    set llvm_exclusions {t, OR c}:llvm@lists.linux.dev "OR "{f,t,c}:nathan@kernel.org
    set llvm_inclusions {nq:c, OR nq:C}lang "OR nq:"{LLVM,llvm}

    lei q -I https://lore.kernel.org/all/ -o $MAIL_FOLDER/llvm --dedupe=mid "($lists_query) AND NOT ($llvm_exclusions) AND ($llvm_inclusions) AND rt:1.week.ago.."

    lei q -I https://lore.kernel.org/all/ -o $MAIL_FOLDER/kvmarm --dedupe=mid "(l:kvmarm@lists.cs.columbia.edu OR l:kvmarm@lists.linux.dev) AND rt:1.week.ago.."
end

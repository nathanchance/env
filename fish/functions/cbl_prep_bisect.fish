#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function cbl_prep_bisect -d "Prepare for an automated bisect"
    if test (count $argv) -ne 1
        print_error (status function)" <bisect_type>"
        return 1
    end

    set -g bisect_script (mktemp --suffix=.fish -p $CBL_MISC/repro-scripts)
    chmod +x $bisect_script

    switch $argv[1]
        case llvm
            echo '#!/usr/bin/env fish

in_tree llvm
or return 128

set llvm_bld (tbf)-testing

cbl_bld_llvm_fast \
    --build-folder $llvm_bld
or return 125

set lnx_src $CBL_SRC_C/linux
set lnx_bld (tbf $lnx_src)-testing

kmake \
    -C $lnx_src \
    LLVM=$llvm_bld/final/bin/ \
    O=$lnx_bld \
    mrproper &| string match -er \'\'
switch "$pipestatus"
    case \'0 1\'
        return 0
    case \'1 0\'
        return 1
end
return 125' >$bisect_script
    end

    vim $bisect_script
end

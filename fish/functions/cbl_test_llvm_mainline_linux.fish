#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_test_llvm_mainline_linux -d "Test mainline Linux with all supported versions of LLVM"
    in_container_msg -h; or return

    set linux_folder $CBL_BLD_C/linux
    if not test -d $linux_folder
        mkdir -p (dirname $linux_folder)
        git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/ $linux_folder
    end
    git -C $linux_folder pull --rebase

    set env_dbx $ENV_FOLDER/.distrobox
    mkdir -p $env_dbx
    for image in llvm-$LLVM_VERSIONS_KERNEL
        set script (mktemp -p $env_dbx --suffix=.fish)
        echo "#!/usr/bin/env fish

upd -y
cbl_lkt \
    --linux-folder $linux_folder \
    --system-binaries" >$script
        chmod +x $script

        if not dbxeph $image -- $script
            rm -f $script
            return 1
        end
        rm -f $script
    end
end

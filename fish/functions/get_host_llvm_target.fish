#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function get_host_llvm_target -d "Get the current host architecture as an LLVM target"
    switch (uname -m)
        case aarch64
            echo AArch64
        case x86_64
            echo X86
        case '*'
            echo Unknown
    end
end

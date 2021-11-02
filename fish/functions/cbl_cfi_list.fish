#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# drm/i915: Avoid bitwise vs logical OR warning in snb_wm_latency_quirk()
x fish -c \"curl -LSs 'https://cgit.freedesktop.org/drm/drm-intel/patch/?id=2e70570656adfe1c5d9a29940faa348d5f132199' | git am\"

x fish -c 'git ru; and git ml --no-edit sami/clang-cfi^'
"
end

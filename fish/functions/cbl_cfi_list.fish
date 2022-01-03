#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# drm/i915: Avoid bitwise vs logical OR warning in snb_wm_latency_quirk()
x fish -c \"curl -LSs 'https://cgit.freedesktop.org/drm/drm-intel/patch/?id=2e70570656adfe1c5d9a29940faa348d5f132199' | git am\"

# [PATCH v2] usb: dwc2: hcd_queue: Fix use of floating point literal
x b4 -q shazam -l -s https://lore.kernel.org/r/20211105145802.2520658-1-nathan@kernel.org/

x git ml --no-edit sami/clang-cfi
"
end

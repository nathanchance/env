#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function updbin -d "Build certain pieces of software from source and install them to ~/usr"
    bccache; or return
    bcmake; or return
    bcvise; or return
    bgit; or return
    bmake; or return
    bninja; or return
    btmux; or return

    biexa; or return
    birg; or return
    bisharkdp all; or return

    iduf; or return
    ishellcheck; or return
    ishfmt; or return
end

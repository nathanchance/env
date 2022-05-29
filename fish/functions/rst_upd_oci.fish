#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function rst_upd_oci -d "Reset container storage, download new images, and start new containers"
    podman system reset --force; or return

    if test "$LOCATION" = pi; and test "$MAIN_FOLDER" != "$HOME"
        upd_strg_cfg; or return
    end

    dbxc --yes; or return
    dbxe -- 'fish -c "upd -y"'

    if test "$LOCATION" = workstation
        podman pull $GHCR/dev/fedora
    end
end

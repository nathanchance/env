#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function oci_rst_upd -d "Reset container storage, download new images, and start new containers"
    if command -q docker
        docker stop (docker ps -aq)
        docker rm (docker ps -aq)
        docker rmi (docker images -aq)
    end

    if command -q podman
        podman system reset --force; or return

        if test "$LOCATION" = pi; and test "$MAIN_FOLDER" != "$HOME"
            upd_strg_cfg; or return
        end
    end

    dbxc --yes; or return
    dbxe -- 'fish -c "upd -y"'

    if test "$LOCATION" = workstation
        podman pull $GHCR/dev/fedora
    end
end

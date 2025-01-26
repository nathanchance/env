#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function upd_strg_cfg -d "Updates storage.conf for podman (primarily useful for Raspberry Pi)"
    set cur_strg_loc (podman system info -f json | jq -r '.store.graphRoot')
    set new_strg_loc (string replace $HOME/.local/share $MAIN_FOLDER $cur_strg_loc)
    set strg_cfg $HOME/.config/containers/storage.conf

    mkdir -p (path dirname $strg_cfg)
    printf '[storage]\n\ndriver = "overlay"\n\ngraphroot = "%s"\n' $new_strg_loc >$strg_cfg
end

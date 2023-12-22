#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function get_dev_img_esc -d "Replace '/' in value from get_dev_img() with '-'"
    string replace / - (get_dev_img)
end

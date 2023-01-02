#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function hwvulns -d "Displays the hardware vulnerability sysfs values"
    grep --color=always . /sys/devices/system/cpu/vulnerabilities/*
end

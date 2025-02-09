#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function sch_tz_chg -d "Schedule a timezone change"
    if test (count $argv) -ne 2
        print_error (status function)" <date> <timezone>"
        return 1
    end

    set date_str $argv[1]
    set timezone $argv[2]
    set dev_img (dev_img)

    # Validate provided date string
    if not set out (systemd-analyze calendar $date_str)
        return 1
    end

    if not test -e /usr/share/zoneinfo/$timezone
        print_error "$timezone does not exist within /usr/share/zoneinfo?"
        return 1
    end

    if not systemctl is-active -q systemd-nspawn@$dev_img.service
        print_error "$dev_img not running?"
        return 1
    end

    set sd_run_args \
        --collect \
        --on-calendar=$date_str
    set sd_run_cmd \
        /usr/bin/timedatectl \
        set-timezone \
        $timezone

    sudo systemd-run $sd_run_args $sd_run_cmd
    or return

    sudo systemd-run $sd_run_args --machine=$dev_img $sd_run_cmd
end

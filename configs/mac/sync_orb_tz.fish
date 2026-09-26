#!/opt/homebrew/bin/fish

set log_date '['(date +"%Y-%m-%d %H:%M:%S %z")']'

if not set current_tz (readlink /etc/localtime | string replace /var/db/timezone/zoneinfo/ '')
    echo >&2 "$log_date timezone location changed? current_tz: '$current_tz'"
    return 1
end

set last_tz_file /Users/nathan/.local/state/dev.nathanchance.orbtzsync.last_tz.txt
if test -e $last_tz_file
    set last_tz (cat $last_tz_file)
    if test $current_tz = $last_tz
        return 0
    else
        echo "$log_date macOS timezone updated: $last_tz -> $current_tz"
    end
else
    echo "$log_date initial run"
    mkdir -p (path dirname $last_tz_file)
end

set orb /usr/local/bin/orb
if not test -e $orb
    echo >&2 "$log_date orbctl is not present at $orb?"
    return 1
end

set set_tz_cmd timedatectl set-timezone $current_tz

if $orb run -u root $set_tz_cmd
    echo "$log_date successfully updated OrbStack host timezone to $current_tz"
else
    echo >&2 "$log_date failed to set host timezone in OrbStack to $current_tz!"
    return 1
end

if $orb run sd_nspawn -r "run0 $set_tz_cmd"
    echo "$log_date successfully updated OrbStack systemd-nspawn container timezone to $current_tz"
else
    echo >&2 "$log_date failed to set systemd-nspawn container timezone in OrbStack to $current_tz!"
    return 1
end

echo $current_tz >$last_tz_file

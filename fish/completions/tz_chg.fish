set -l subcommands \
    clean \
    cancel \
    list \
    sch \
    sync
complete -c tz_chg -n "not __fish_seen_subcommand_from $subcommands" -x -a "
    clean\t'Clean up stale timer files'
    cancel\t'Cancel active timers'
    list\t'List scheduled timers'
    sch\t'Schedule a timezone change'
    sync\t'Sync host timezone changes to container'"

complete -c tz_chg -f
complete -c tz_chg -f -s h -l help -d "Show help message and exit"
complete -c tz_chg -n "__fish_seen_subcommand_from sch; and test (commandline -xpc | count) -eq 4" -f -d Timezone -a '(timedatectl list-timezones)'

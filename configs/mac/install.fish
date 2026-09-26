#!/usr/bin/env fish

set mac_configs (status dirname | path resolve)
set uid (id -u)

for plist in $mac_configs/*.plist
    cp -v $plist $HOME/Library/LaunchAgents
    or return

    set service_name (path basename $plist | string replace .plist '')

    launchctl enable gui/$uid/$service_name
    or return
end

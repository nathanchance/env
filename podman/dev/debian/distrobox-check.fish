#!/usr/bin/env fish
# Check distrobox dependencies
# https://github.com/89luca89/distrobox/blob/main/docs/distrobox_custom.md

# Keep this in sync with distrobox-init
set distrobox_dependencies \
    bc \
    curl \
    diff \
    find \
    fish \
    less \
    lsof \
    mount \
    passwd \
    pinentry \
    sudo \
    time \
    useradd \
    wget

set ret 0
for distrobox_dependency in $distrobox_dependencies
    if not command -q $distrobox_dependency
        echo "$distrobox_dependency could not be found!"
        set ret 1
    end
end

return $ret

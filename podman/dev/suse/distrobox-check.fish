#!/usr/bin/env fish
# Check distrobox dependencies
# https://github.com/89luca89/distrobox/blob/main/docs/distrobox_custom.md

# Keep this in sync with distrobox-init
set distrobox_dependencies \
    bc \
    bzip2 \
    chpasswd \
    curl \
    diff \
    find \
    findmnt \
    fish \
    gpg \
    hostname \
    less \
    lsof \
    man \
    mount \
    passwd \
    pigz \
    pinentry \
    ping \
    ps \
    rsync \
    script \
    ssh \
    sudo \
    time \
    tree \
    umount \
    unzip \
    useradd \
    wc \
    wget \
    xauth \
    zip

set ret 0
for distrobox_dependency in $distrobox_dependencies
    if not command -q $distrobox_dependency
        echo "$distrobox_dependency could not be found!"
        set ret 1
    end
end
if not test -e /usr/share/zoneinfo/UTC
    echo "UTC zoneinfo file not found, install tzdata?"
    set ret 1
end

return $ret

#!/usr/bin/env bash

set -euxo pipefail

if ! command -v patch &>/dev/null; then
    pacman -Sy --noconfirm patch
fi

pacman -Sy --noconfirm archinstall

# Double the size of the boot partition
site_packages=$(python3 -c "import site; print(site.getsitepackages()[0])")
if ! grep -q "1025MiB" "$site_packages"/archinstall/lib/disk/user_guides.py; then
    curl -LSs https://raw.githubusercontent.com/nathanchance/patches/main/archinstall/uefi-boot-size.patch | patch -d "$site_packages" -N -p1
fi

archinstall "$@"

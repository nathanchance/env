#!/usr/bin/env bash

set -ex

# Source files should never be altered
sudo cp -r /pkg /tmp/pkg
user=$(id -un)
sudo chown -R "$user:$user" /tmp/pkg
cd /tmp/pkg

# Download all dependencies from PKGBUILD (in a subshell to avoid messing things up)
(
    # shellcheck disable=SC1091
    source PKGBUILD
    yay -Syyu --noconfirm
    # shellcheck disable=SC2154
    yay -S --asdeps --noconfirm "${depends[@]}" "${makedepends[@]}" "${checkdepends[@]}"
)

# Build the package
makepkg -Ccf

# Copy the package back
for package in *.pkg.tar*; do
    sudo chown "$(stat -c '%u:%g' /pkg/PKGBUILD)" "$package"
    sudo mv -v "$package" /pkg
done

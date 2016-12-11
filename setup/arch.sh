#!/bin/bash
#
# Copyright (C) 2015-2016, Akhil Narang, Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


# Uncomment multilib


# ECHO PREREQUISITES TO USER
echo "Before proceeding, you must have enabled the multilib and archlinuxfr repos in /etc/pacman.conf! If you have not done so, please cancel the script and do this now!"
sleep 10


# Start the script!
clear
echo "Installing Dependencies!"


# Update pacman lists
sudo pacman -Syu


# Install additional packages
sudo pacman -S git gnupg gperf sdl wxgtk bash-completion subversion \
squashfs-tools curl ncurses zlib schedtool perl-switch ca-certificates-mozilla \
zip unzip libxslt maven tmux screen w3m python2-virtualenv bc rsync ncftp expac yajl


# Comment out the next section if you installed base-devel from pacstrap
sudo pacman -S autoconf automake binutils bison fakeroot findutils flex gcc \
groff libtool m4 make patch pkg-config


# Installing 64 bit needed packages
sudo pacman -S gcc-multilib lib32-zlib lib32-ncurses lib32-readline


# Install pacaur
echo "Installing pacaur"
curl -o PKGBUILD https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=cower && makepkg PKGBUILD --skippgpcheck && sudo pacman -U cower*.tar.xz --noconfirm && rm -rf *.tar.xz PKGBUILD
curl -o PKGBUILD https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=pacaur && makepkg PKGBUILD && sudo pacman -U pacaur*.tar.xz --noconfirm &&  && rm -rf *.tar.xz PKGBUILD


# Disable pgp checking when installing stuff from AUR
export MAKEPKG="makepkg --skippgpcheck"


# Install AUR packages
pacaur -S libtinfo
pacaur -S lib32-ncurses5-compat-libs
pacaur -S ncurses5-compat-libs
pacaur -S phablet-tools
pacaur -S make-3.81


# Print commands that user needs to run before building
echo "All Done :'D"
echo "Don't forget to run these command before building!"
echo "
virtualenv2 venv
source venv/bin/activate
export LC_ALL=C"


# Symlink make-3.81 to /usr/bin/make
sudo pacman -R make
sudo ln -s /usr/bin/make-3.81 /usr/bin/make


# Change git editor section
echo "If you wanna use nano as your git editor (for commit messages, interactive rebase, etc, enter nano."
echo "Anything else will result in the default i.e. vim being used"
echo "Your current editor is $(git config core.editor)"

read -p "Your selection: " giteditor

if [ "$giteditor" == "nano" ];
then
git config --global core.editor nano
else
git config --global core.editor vi
fi

echo "Your git editor is now $(git config core.editor)"

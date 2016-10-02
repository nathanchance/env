#!/bin/bash
#
# Copyright (C) 2015-2016, Akhil Narang "akhilnarang" <akhilnarang.1999@gmail.com>, Nathan Chancellor
#
# This software is licensed under the terms of the GNU General Public
# License version 2, as published by the Free Software Foundation, and
# may be copied, distributed, and modified under those terms.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Please maintain this if you use this script or any part of it
#


# Start the script!
clear
echo Installing Dependencies!


# Update pacman lists
sudo pacman -Syu


# Install needed packages
sudo pacman -S gcc git gnupg flex bison gperf sdl wxgtk bash-completion subversion \
squashfs-tools curl ncurses zlib schedtool perl-switch zip autoconf gawk \
unzip libxslt maven tmux screen w3m python2-virtualenv bc rsync ncftp \
ca-certificates-mozilla fakeroot make pkg-config texinfo patch automake libtool


# Enable multilib section in /etc/pacman.conf
echo "Enabling multilib if not already enabled!"
if [ $(grep "\#\[multilib\]" /etc/pacman.conf) ]; then
   if [ ! $(grep "\#AkhilsScriptWasHere" /etc/pacman.conf) ]; then
      sudo echo "
      [multilib]
      Include = /etc/pacman.d/mirrorlist
      " >> /etc/pacman.conf
   fi
fi
# Update pacman list
sudo pacman -Syu


# Installing 64 bit needed packages
sudo pacman -S gcc-multilib lib32-zlib lib32-ncurses lib32-readline


# yaourt for easy installing from AUR
echo "Installing yaourt!"
if [ ! $(grep "\#AkhilsScriptWasHere" /etc/pacman.conf) ]; then
   sudo echo "# Added for yaourt
   [archlinuxfr]
   SigLevel = Never
   Server = http://repo.archlinux.fr/\$arch" >> /etc/pacman.conf
fi
sudo pacman -Sy yaourt


# Disable pgp checking when installing stuff from AUR
export MAKEPKG="makepkg --skippgpcheck"


# Install AUR packages
yaourt -S libtinfo
yaourt -S lib32-ncurses5-compat-libs
yaourt -S ncurses5-compat-libs
yaourt -S phablet-tools
yaourt -S make-3.81


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

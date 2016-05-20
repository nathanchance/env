#!/bin/bash

# Clear the terminal
clear

# Remove the DU folder
rm -rf ~/ROMs/DU

# Remake the DU folder and move into it
mkdir ~/ROMs/DU
cd ~/ROMs/DU

# init the repo and sync it
repo init -u https://github.com/DirtyUnicorns/android_manifest.git -b m
repo sync --force-sync

# Download dependencies
. build/envsetup.sh
breakfast angler
breakfast bullhead
breakfast hammerhead
breakfast shamu

# Ring a bell once at home
cd ~/
echo -e "\a"

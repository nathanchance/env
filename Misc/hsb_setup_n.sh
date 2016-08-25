#!/bin/bash


#################
##  FUNCTIONS  ##
#################

# Remove, make, and move into function
# Parameter 1: the location of the folder you want to remake
function rm_mk_cd() {
   rm -rf ${1}
   mkdir -p ${1}
   cd ${1}
}

# Repo init and repo sync function
# Parameter 1: URL of the manifest
# Parameter 2: Branch of the manifest
function init_sync() {
   repo init -u ${1} -b ${2}

   time repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)
}

# Repo init with reference and repo sync function
# Parameter 1: Abbreviation of thing being synced (possible options are: pn, pn-mod, rr, aosip, du, beltz, or TWRP)
# Parameter 2: URL of the manifest
# Parameter 3: Branch of the manifest
function init_sync_ref() {
   repo init -u ${2} -b ${3} --reference=${HOME}/ROMs/PN

   time repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)
}

# Dependencies function
# Parameter 1: Abbreviation of thing we are syncing dependencies for (possible options are: pn, pn-mod, rr, aosip, du, beltz, or TWRP)
# Parameter 2: Devices to sync dependencies for
function dependencies() {
   DEVICES="angler shamu bullhead hammerhead" ;;

   . build/envsetup.sh

   for DEVICE in ${DEVICES}; do
      breakfast ${DEVICE}
   done
}


#############
##  GApps  ##
#############
# Remove all previous GApps
rm_mk_cd ${HOME}/GApps
# OpenGApps
git clone git@github.com:opengapps/opengapps.git Open


###############
##  Kernels  ##
###############
# Remove all previous kernels
rm_mk_cd ${HOME}/Kernels
# Ninja
git clone https://github.com/nathanchance/Ninja-Kernel.git Ninja
# Toolchains
source sync_toolchains.sh


############
##  ROMs  ##
############
# Remove all previous ROMs
rm_mk_cd ${HOME}/ROMs

# Sync PN N
rm_mk_cd ${HOME}/ROMs/PN
echo -e "Enter URL of manifest:"
read MANIFEST_URL
echo -e "Enter the branch of manifest:"
read MANIFEST_BRANCH
init_sync ${MANIFEST_URL} ${MANIFEST_BRANCH}


############
##  TWRP  ##
############
# reference sync - angler, shamu, bullhead, hammmerhead, and mako
rm_mk_cd ${HOME}/TWRP
init_sync twrp git://github.com/lj50036/platform_manifest_twrp_omni.git twrp-6.0
dependencies twrp mako

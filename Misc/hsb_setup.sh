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

   if [[ "${1}" == "rr" || "${1}" == "pn-mod" ]]; then
      case "${1}" in
         "rr")
            LM_URL=https://raw.githubusercontent.com/nathanchance/local_manifests/master/rr_shamu.xml ;;
         "pn-mod")
            LM_URL=https://raw.githubusercontent.com/nathanchance/local_manifests/master/pn-mod.xml ;;
      esac

      rm_mk_cd .repo/local_manifests
      wget ${LM_URL}
      cd ../..
   fi

   time repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)
}

# Dependencies function
# Parameter 1: Abbreviation of thing we are syncing dependencies for (possible options are: pn, pn-mod, rr, aosip, du, beltz, or TWRP)
# Parameter 2: Devices to sync dependencies for
function dependencies() {
   case "${2}" in
      "mako")
         DEVICES="angler shamu bullhead hammerhead mako" ;;
      "no-mako")
         DEVICES="angler shamu bullhead hammerhead" ;;
      "shamu")
         DEVICES="shamu" ;;
   esac

   . build/envsetup.sh

   for DEVICE in ${DEVICES}; do
      case "${1}" in
         "twrp")
            lunch omni_${DEVICE}-eng ;;
         "beltz")
            lunch androidx_${DEVICE}-userdebug ;;
         *)
            breakfast ${DEVICE} ;;
      esac
   done
}


#############
##  GApps  ##
#############
# Remove all previous GApps
rm_mk_cd ${HOME}/GApps
# Banks
git clone https://github.com/MrBaNkS/banks_dynamic_gapps.git Banks
# OpenGApps
git clone git@github.com:opengapps/opengapps.git Open


###############
##  Kernels  ##
###############
# Remove all previous kernels
rm_mk_cd ${HOME}/Kernels
# Ninja
git clone https://github.com/nathanchance/Ninja-Kernel.git Ninja
# AK
rm_mk_cd ${HOME}/Kernels/AK
git clone https://github.com/nathanchance/AK-Angler.git Kernel
git clone https://github.com/anarkia1976/AK-Angler-AnyKernel2.git AK2
# Toolchains
source sync_toolchains.sh


############
##  ROMs  ##
############
# Remove all previous ROMs
rm_mk_cd ${HOME}/ROMs
# PureNexus - full sync - angler, shamu, bullhead, and hammmerhead
# rm_mk_cd ${HOME}/ROMs/PN
# init_sync https://github.com/PureNexusProject-Legacy/manifest.git mm2
# dependencies pn no-mako
# PureNexus Mod - reference sync - angler, shamu, bullhead, and hammmerhead
# rm_mk_cd ${HOME}/ROMs/PN-Mod
# init_sync_ref pn-mod https://github.com/ezio84/pnmod-manifest.git mm2oms
# dependencies pn-mod no-mako
# Dirty Unicorns - reference sync - angler, shamu, bullhead, hammmerhead, and mako
rm_mk_cd ${HOME}/ROMs/DU
init_sync du https://github.com/DirtyUnicorns/android_manifest.git m
dependencies du mako
# AOSiP - reference sync - angler, shamu, bullhead, hammmerhead, and mako
# rm_mk_cd ${HOME}/ROMs/AOSiP
# init_sync_ref aosip git://github.com/AOSIP/platform_manifest.git oms
# dependencies aosip mako
# Beltz - reference sync - angler, shamu, bullhead, and hammmerhead
# rm_mk_cd ${HOME}/ROMs/Beltz
# init_sync_ref beltz git://github.com/beltz/platform_manifest.git beltz
# dependencies beltz no-mako
# ResurrectionRemix - reference sync - shamu
# rm_mk_cd ${HOME}/ROMs/RR
# init_sync_ref rr https://github.com/ResurrectionRemix/platform_manifest.git marshmallow
# dependencies rr shamu


############
##  TWRP  ##
############
# reference sync - angler, shamu, bullhead, hammmerhead, and mako
rm_mk_cd ${HOME}/TWRP
init_sync twrp git://github.com/lj50036/platform_manifest_twrp_omni.git twrp-6.0
dependencies twrp mako

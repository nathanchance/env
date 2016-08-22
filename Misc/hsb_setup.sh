#!/bin/bash

# Remove, make, and move into function
function rm_mk_cd() {
   rm -rf ${1}
   mkdir -p ${1}
   cd ${1}
}

# Repo init and repo sync function
function init_sync() {
   repo init -u ${1} -b ${2}
   time repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)
}

# Repo init with reference and repo sync function
function init_sync_ref() {
   repo init -u ${2} -b ${3} --reference=${HOME}/ROMs/PN
   if [[ "${1}" == "rr" ]]; then
      rm_mk_cd .repo/local_manifests
      wget https://raw.githubusercontent.com/nathanchance/local_manifests/master/rr_shamu.xml
   elif [[ "${1}" == "pn-mod" ]]; then
      rm_mk_cd .repo/local_manifests
      wget https://raw.githubusercontent.com/nathanchance/local_manifests/master/pn-mod.xml
   fi
   time repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)
}

# Dependencies function
function dependencies() {
   case ${1} in
      "mako")
         DEVICES="angler shamu bullhead hammerhead mako" ;;
      "no-mako")
         DEVICES="angler shamu bullhead hammerhead" ;;
      "shamu")
         DEVICES="shamu" ;;
   esac

   . build/envsetup.sh

   for DEVICE in ${DEVICES}; do
      case ${2} in
         "twrp")
            lunch omni_${DEVICE}-eng
            if [[ ${DEVICE} == "shamu" ]]; then
               cd device/moto/shamu
               git fetch ssh://nathanchance@gerrit.omnirom.org:29418/android_device_moto_shamu refs/changes/74/18874/1 && git cherry-pick FETCH_HEAD
               cd ../../..
               lunch omni_${DEVICE}-eng
            fi ;;
         "beltz")
            lunch androidx_${DEVICE}-userdebug ;;
         *)
            breakfast ${DEVICE} ;;
      esac
   done
}


# GApps
rm_mk_cd ${HOME}/GApps
git clone https://github.com/MrBaNkS/banks_dynamic_gapps.git Banks
git clone https://github.com/beanstown106/purenexus_dynamic_gapps.git PN


# Kernels
rm_mk_cd ${HOME}/Kernels
git clone https://github.com/nathanchance/Ninja-Kernel.git Ninja
rm_mk_cd ${HOME}/Kernels/AK
git clone https://github.com/nathanchance/AK-Angler.git Kernel
git clone https://github.com/anarkia1976/AK-Angler-AnyKernel2.git AK2
source sync_toolchains.sh


# ROMs
rm_mk_cd ${HOME}/ROMs

rm_mk_cd ${HOME}/ROMs/PN
init_sync https://github.com/PureNexusProject-Legacy/manifest.git mm2
dependencies no-mako pn

rm_mk_cd ${HOME}/ROMs/PN-Mod
init_sync_ref pn-mod https://github.com/ezio84/pnmod-manifest.git mm2oms
dependencies no-mako pn-mod

rm_mk_cd ${HOME}/ROMs/DU
init_sync_ref du https://github.com/DirtyUnicorns/android_manifest.git m
dependencies mako du

rm_mk_cd ${HOME}/ROMs/AOSiP
init_sync_ref aosip git://github.com/AOSIP/platform_manifest.git oms
dependencies mako aosip

rm_mk_cd ${HOME}/ROMs/Beltz
init_sync_ref beltz git://github.com/beltz/platform_manifest.git beltz
dependencies no-mako beltz

rm_mk_cd ${HOME}/ROMs/RR
init_sync_ref rr https://github.com/ResurrectionRemix/platform_manifest.git marshmallow
dependencies shamu rr


# TWRP
rm_mk_cd ${HOME}/TWRP
init_sync_ref twrp git://github.com/lj50036/platform_manifest_twrp_omni.git twrp-6.0
dependencies mako twrp

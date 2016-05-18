#!/bin/bash

# Usage: $ . source_setup.sh <existing|new>

# Parameters
STARTOVER=$1

# Variables
ANDROIDDIR=~/
ROMDIR=${ANDROIDDIR}/ROMs
GAPPSDIR=${ANDROIDDIR}/GApps
KERNELSDIR=${ANDROIDDIR}/Kernels

if [ "${STARTOVER}" == "existing" ]
then
   rm -rf ${ANDROIDDIR}
else
   sudo apt-get install curl
   curl https://raw.githubusercontent.com/akhilnarang/scripts/master/build-environment-setup.sh | bash
   mkdir ~/bin
   PATH=~/bin:$PATH
   curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
   chmod a+x ~/bin/repo
   git config --global user.name "Nathan Chancellor"
   git config --global user.email "natechancellor@gmail.com"
fi

# Make head directories
mkdir ${ANDROIDDIR}
mkdir ${ROMDIR}
mkdir ${GAPPSDIR}
mkdir ${KERNELSDIR}

# Sync in scripts
cd ${ANDROIDDIR}
git clone https://github.com/nathanchance/scripts.git

# Sync DU
mkdir ${ROMDIR}/DU
cd ${ROMDIR}/DU
repo init -u https://github.com/DirtyUnicorns/android_manifest.git -b m
repo sync --force-sync
. build/envsetup.sh
breakfast angler
breakfast bullhead
breakfast hammerhead
breakfast shamu

# Sync PN-CMTE
mkdir ${ROMDIR}/PN-CMTE
cd ${ROMDIR}/PN-CMTE
repo init -u https://github.com/PureNexusProject/manifest.git -b mm
repo sync --force-sync
. build/envsetup.sh
breakfast angler
breakfast bullhead
breakfast hammerhead
breakfast shamu

# Sync PN-Layers
mkdir ${ROMDIR}/PN-Layers
cd ${ROMDIR}/PN-Layers
repo init -u https://github.com/PureNexusProject/manifest.git -b mm-cmte
repo sync --force-sync
. build/envsetup.sh
breakfast angler
breakfast bullhead
breakfast hammerhead
breakfast shamu

# Sync PN-Mod
mkdir ${ROMDIR}/PN-Mod
cd ${ROMDIR}/PN-Mod
repo init -u https://github.com/ezio84/pnmod-manifest.git -b mm
repo sync --force-sync
. build/envsetup.sh
breakfast angler

# Sync GApps
cd ${GAPPSDIR}
git clone https://github.com/DirtyUnicorns/banks_dynamic_gapps.git Banks
git clone https://github.com/PureNexusProject/purenexus_dynamic_gapps.git PN

# Sync Elite
cd ${KERNELSDIR}
git clone https://github.com/nathanchance/elite_angler.git
git clone https://github.com/Elite-Kernels/Linaro-4.9_aarch64.git

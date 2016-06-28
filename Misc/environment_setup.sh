#!/bin/bash

# -----
# Usage
# -----
# $ . source_setup.sh <existing|new>



# ----------
# Parameters
# ----------
STARTOVER=${1}



# ---------
# Variables
# ---------
ANDROIDDIR=${HOME}
ROMDIR=${ANDROIDDIR}/ROMs
GAPPSDIR=${ANDROIDDIR}/GApps
KERNELSDIR=${ANDROIDDIR}/Kernels
SCRIPTSDIR=${ANDROIDDIR}/Scripts
LOGSDIR=${ANDROIDDIR}/Logs



# Clear the terminal
clear



# If the startover flag says existing, it means the build environment has been established already and the resources directory needs to be cleaned
if [ "${STARTOVER}" == "existing" ]
then
   rm -rf ${ROMDIR}
   rm -rf ${GAPPSDIR}
   rm -rf ${KERNELSDIR}
   rm -rf ${SCRIPTSDIR}
   rm -rf ${LOGSDIR}
else
   sudo apt-get install curl
   curl https://raw.githubusercontent.com/akhilnarang/scripts/master/build-environment-setup.sh | bash
   mkdir ${HOME}/bin
   PATH=${HOME}/bin:$PATH
   curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
   chmod a+x ${HOME}/bin/repo
   git config --global user.name "Nathan Chancellor"
   git config --global user.email "natechancellor@gmail.com"
fi



# Make head directories
mkdir ${ANDROIDDIR}
mkdir ${ROMDIR}
mkdir ${GAPPSDIR}
mkdir ${KERNELSDIR}
mkdir ${LOGSDIR}



# Sync in scripts
cd ${ANDROIDDIR}
git clone https://github.com/nathanchance/scripts.git Scripts



# Sync local Manifests
cd ${ROMDIR}
git clone https://github.com/nathanchance/local_manifests.git Manifests



# Sync AICP
. ${ANDROIDDIR}/Scripts/rom_folder.sh aicp nosync
# Sync AOSIP
. ${ANDROIDDIR}/Scripts/rom_folder.sh aosip nosync
# Sync DU
. ${ANDROIDDIR}/Scripts/rom_folder.sh du sync
# Sync PN
. ${ANDROIDDIR}/Scripts/rom_folder.sh pn sync
# Sync PN Mod
. ${ANDROIDDIR}/Scripts/rom_folder.sh pnmod sync
# Sync RR
. ${ANDROIDDIR}/Scripts/rom_folder.sh rr sync
# Sync Screwd
. ${ANDROIDDIR}/scripts/rom_folder.sh screwd nosync
# Sync Temasek
. ${ANDROIDDIR}/scripts/rom_folder.sh temasek nosync



# Sync GApps
cd ${GAPPSDIR}
git clone https://github.com/DirtyUnicorns/banks_dynamic_gapps.git Banks
git clone https://github.com/PureNexusProject/purenexus_dynamic_gapps.git PN



# Sync Elite
cd ${KERNELSDIR}
git clone https://github.com/nathanchance/elite_angler.git Elite



# Sync AK
cd ${KERNELSDIR}
git clone https://github.com/nathanchance/AK-Angler.git AK
git clone https://github.com/nathanchance/AK-Angler-AnyKernel2.git AK-AK2
cd AK-AK2
git checkout ak-angler-anykernel
cd ../AK
git checkout ak-mm-staging



# Sync Kylo
cd ${KERNELSDIR}
git clone https://github.com/DespairFactor/angler.git Kylo



# Sync toolchains
mkdir ${KERNELSDIR}/Toolchains

. sync_toolchains.sh

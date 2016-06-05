#!/bin/bash

# -----
# Usage
# -----
# $ . source_setup.sh <existing|new>



# ----------
# Parameters
# ----------
STARTOVER=$1



# ---------
# Variables
# ---------
ANDROIDDIR=${HOME}/
ROMDIR=${ANDROIDDIR}/ROMs
GAPPSDIR=${ANDROIDDIR}/GApps
KERNELSDIR=${ANDROIDDIR}/Kernels



# Clear the terminal
clear



if [ "${STARTOVER}" == "existing" ]
then
   rm -rf ${ANDROIDDIR}
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



# Sync in scripts
cd ${ANDROIDDIR}
git clone https://github.com/nathanchance/scripts.git



# Sync AICP
. ${ANDROIDDIR}/scripts/rom_folder.sh aicp nosync



# Sync AOSIP
. ${ANDROIDDIR}/scripts/rom_folder.sh aosip nosync



# Sync DU
. ${ANDROIDDIR}/scripts/rom_folder.sh du sync



# Sync PN-CMTE
. ${ANDROIDDIR}/scripts/rom_folder.sh pncmte nosync



# Sync PN-Layers
. ${ANDROIDDIR}/scripts/rom_folder.sh pnlayers nosync



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
git clone https://github.com/nathanchance/elite_angler.git
git clone https://github.com/Elite-Kernels/Linaro-4.9_aarch64.git



# Sync AK
cd ${KERNELSDIR}
git clone https://github.com/nathanchance/AK-Angler.git
git clone https://github.com/anarkia1976/AK-Angler-AnyKernel2.git
git clone https://bitbucket.org/UBERTC/aarch64-linux-android-5.3-kernel.git
cd AK-Angler-AnyKernel2
git checkout ak-angler-anykernel
cd ../AK-Angler
git checkout ak-mm-staging

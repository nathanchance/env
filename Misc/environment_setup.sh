#!/bin/bash

# -----
# Usage
# -----
# $ . source_setup.sh <existing|new>
# Must be run as sudo



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



# ------
# Colors
# ------
BLDRED="\033[1m""\033[31m"
BLDBLUE="\033[1m""\033[36m"
RST="\033[0m"



# Clear the terminal
clear



# Start tracking time
echo -e ${BLDRED}
echo -e "---------------------------------------"
echo -e "SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------"
echo -e ${RST}

START=$(date +%s)



# If the startover flag says existing, it means the build environment has been established already and the resources directory needs to be cleaned
if [ "${STARTOVER}" == "existing" ]
then
   rm -rf ${ROMDIR}
   rm -rf ${GAPPSDIR}
   rm -rf ${KERNELSDIR}
   rm -rf ${SCRIPTSDIR}
   rm -rf ${LOGSDIR}
else
   sudo apt-get install git-core
   git clone git://github.com/akhilnarang/scripts setup-scripts
   cd setup-scripts
   . ubuntu1404-linuxmint17x.sh
   cd .. && rm -rf setup-scripts
   git config --global user.name "Nathan Chancellor"
   git config --global user.email "natechancellor@gmail.com"
   echo "Don't forget to add ccache and the Scripts info to .bashrc"
   nano ${HOME}/.bashrc
fi



# Make head directories
mkdir -p ${ROMDIR}
mkdir -p ${GAPPSDIR}
mkdir -p ${KERNELSDIR}
mkdir -p ${LOGSDIR}



# Sync in scripts
cd ${ANDROIDDIR}
git clone https://github.com/nathanchance/scripts.git Scripts



# Sync local Manifests
cd ${ROMDIR}
git clone https://github.com/nathanchance/local_manifests.git Manifests



# Sync PN (will serve as our reference)
. ${ANDROIDDIR}/Scripts/rom_folder.sh pn sync
# Sync PN Mod
. ${ANDROIDDIR}/Scripts/rom_folder.sh pnmod sync
# Sync DU
. ${ANDROIDDIR}/Scripts/rom_folder.sh du sync
# Sync RR
. ${ANDROIDDIR}/Scripts/rom_folder.sh rr sync
# Sync AOSIP
. ${ANDROIDDIR}/Scripts/rom_folder.sh aosip sync



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



echo -e ${BLDRED}
echo -e "-------------------------------------"
echo -e "SCRIPT ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "TIME: $(echo $(($END-$START)) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"
echo -e "-------------------------------------"
echo -e ${RST}
echo -e "\a"

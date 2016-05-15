# Parameters
STARTOVER=$1

# Variables
ANDROIDDIR=~/
ROMDIR=${ANDROIDDIR}/ROMs
GAPPSDIR=${ANDROIDDIR}/GApps
KERNELSDIR=${ANDROIDDIR}/Kernels


if [ "${STARTOVER}" == "restart" ]
then
   # remove any previous directories
   rm -rf ${ROMDIR}
   rm -rf ${GAPPSDIR}
   rm -rf ${KERNELSDIR}
fi

# Make head directories
mkdir ${ANDROIDDIR}
mkdir ${ROMDIR}
mkdir ${GAPPSDIR}
mkdir ${KERNELSDIR}

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

# Sync GApps
cd ${GAPPSDIR}
git clone https://github.com/DirtyUnicorns/banks_dynamic_gapps.git Banks
git clone https://github.com/PureNexusProject/purenexus_dynamic_gapps.git PN

# Sync Elite
cd ${KERNELSDIR}
git clone https://github.com/nathanchance/elite_angler.git
git clone https://github.com/Elite-Kernels/Linaro-4.9_aarch64.git

# rm -rf ~/GApps && mkdir ~/GApps && cd ~/GApps && git clone https://github.com/DirtyUnicorns/banks_dynamic_gapps.git Banks && git clone https://github.com/PureNexusProject/purenexus_dynamic_gapps.git PN

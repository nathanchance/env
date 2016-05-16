#!/bin/bash

# Path to build your kernel
SOURCEDIR=~/Kernels/elite_angler

# Directory for the AnyKernel updater
AKDIR=${SOURCEDIR}/packagesm

# Upload directory
UPLOADDIR=~/shared/Elite

# Date to add to zip
today=$(date +"%m_%d_%Y")

# Start tracking time
START=$(date +%s)

# Change to source directory to start
cd ${SOURCEDIR}

echo "    ____   _      _   _____   ____    "
echo "   |  __| | |    | | |_   _| |  __|   "
echo "   | |__  | |    | |   | |   | |__    "
echo "   |  __| | |    | |   | |   |  __|   "
echo "   | |__  | |__  | |   | |   | |__    "
echo "   |____| |____| |_|   |_|   |____|   "
echo "      __       ________       __      "
echo "      \ ~~~___|   __   |___~~~ /      "
echo "       _----__|__|  |__|__----_       "
echo "       \~~~~~~|__    __|~~~~~~/       "
echo "        ------\  |  |  /------        "
echo "         \_____\ |__| /_____/         "
echo "                \____/                "

# Clean out everything
git reset --hard
git clean -f -d
make clean
make mrproper

# Setup the build
cd ${SOURCEDIR}/arch/arm64/configs/BBKconfigsM
for KERNELNAME in *
 do
  cd ${SOURCEDIR}

# Setup output directory
mkdir -p "out/${KERNELNAME}"
cp -R "${AKDIR}/system" out/${KERNELNAME}
cp -R "${AKDIR}/META-INF" out/${KERNELNAME}
cp -R "${AKDIR}/patch" out/${KERNELNAME}
cp -R "${AKDIR}/ramdisk" out/${KERNELNAME}
cp -R "${AKDIR}/tools" out/${KERNELNAME}
cp -R "${AKDIR}/anykernel.sh" out/${KERNELNAME}

# Flashable zip name
ZIPNAME=${KERNELNAME}-${today}

# Toolchain location and info
TOOLCHAIN=~/Kernels/Linaro-4.9_aarch64/bin/aarch64-linux-android-
export ARCH=arm64
export SUBARCH=arm64

# remove backup files
find ./ -name '*~' | xargs rm

# make kernel
make 'angler_defconfig'
make -j`grep 'processor' /proc/cpuinfo | wc -l` CROSS_COMPILE=${TOOLCHAIN}

# Grab zImage-dtb
echo ""
echo "<<>><<>>  Collecting Image.gz-dtb <<>><<>>"
echo ""
cp ${SOURCEDIR}/arch/arm64/boot/Image.gz-dtb out/${KERNELNAME}/Image.gz-dtb
done

# Build Zip
echo "Creating ${ZIPNAME}.zip"
cd ${SOURCEDIR}/out/${KERNELNAME}/
7z a -tzip -mx5 "${ZIPNAME}.zip"

# Remove previous kernel zip in the upload directory
rm ${UPLOADDIR}/*.zip

# Move the new one into the upload directory
mv ${ZIPNAME}.zip ${UPLOADDIR}

# Upload it
. ~/upload.sh

# Remove the out directory
rm -rf ${SOURCEDIR}/out

# Go to the home directory
cd ~/

# Success! Stop tracking time
END=$(date +%s)
echo "====================================="
echo "Compilation and upload successful!"
echo "Total time elapsed: $(echo $(($END-$START)) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"
echo "====================================="
echo -e "\a"

# Variables
SOURCEDIR=~/ROMs/DU
OUTDIR=${SOURCEDIR}/out/target/product
UPLOADDIR=~/shared/.special/.jdizzle
DEVICE=shamu
# Make it show nathan@chancellor in the kernel version
export KBUILD_BUILD_USER=nathan
export KBUILD_BUILD_HOST=chancellor
# Special build type
export DU_BUILD_TYPE=NINJA
# Start tracking time
START=$(date +%s)
# Change to the source directory
cd ${SOURCEDIR}
# Sync source
repo sync
# Initialize build environment
. build/envsetup.sh
# Clean out directory
make clean
make clobber
# Make shamu
brunch ${DEVICE}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE}_*.zip
rm ${UPLOADDIR}/*_${DEVICE}_*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE}/DU_${DEVICE}_*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE}/DU_${DEVICE}_*.zip.md5sum ${UPLOADDIR}
# Upload files
. ~/upload.sh
# Clean out directory
make clean
make clobber
# Go back home
cd ~/
# Set build type back to what it was
export DU_BUILD_TYPE=CHANCELLOR
# Success! Stop tracking time
END=$(date +%s)
echo "====================================="
echo "Compilation and upload successful!"
echo "Total time elapsed: $(echo $(($END-$START)) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"
echo "====================================="

# Variables
SOURCEDIR=~/DU
OUTDIR=~/DU/out/target/product
UPLOADDIR=~/shared/DU
DEVICE=bullhead
# Make it show nathan@chancellor in the kernel version
export KBUILD_BUILD_USER=nathan
export KBUILD_BUILD_HOST=chancellor
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
# Make bullhead
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
# Success! Stop tracking time
END=$(date +%s)
echo "====================================="
echo "Compilation and upload successful!"
echo "Total time elapsed: $(echo $(($END-$START)) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"
echo "====================================="

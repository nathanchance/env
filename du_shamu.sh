# Variables
SOURCEDIR=~/DU
OUTDIR=~/DU/out/target/product
UPLOADDIR=~/shared/DU
DEVICE=shamu
# Change to the source directory
cd ${SOURCEDIR}
# Sync source
repo sync
# Initialize build environment
. build/envsetup.sh
# Clean out directory
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
make clobber
# Go back home
cd ~/
# Success!
echo "==================================="
echo "Compilation and upload successful!"
echo "==================================="

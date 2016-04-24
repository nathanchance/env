# Variables
SOURCEDIR=~/PN-Layers
OUTDIR=~/PN-Layers/out/target/product
UPLOADDIR=~/shared/PN/Layers
DEVICE=angler
# Change to the source directory
cd ${SOURCEDIR}
# Sync source
repo sync
# Initialize build environment
. build/envsetup.sh
# Clean out directory
make clobber
# Make angler
brunch ${DEVICE}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE}-*.zip
rm ${UPLOADDIR}/*_${DEVICE}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE}/pure_nexus_${DEVICE}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE}/pure_nexus_${DEVICE}-*.zip.md5sum ${UPLOADDIR}
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

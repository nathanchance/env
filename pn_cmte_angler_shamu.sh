# Variables
SOURCEDIR=~/PN-CMTE
OUTDIR=~/PN-CMTE/out/target/product
UPLOADDIR=~/shared/PN/CMTE
DEVICE1=angler
DEVICE2=shamu
# Change to the source directory
cd ${SOURCEDIR}
# Sync source
repo sync
# Initialize build environment
. build/envsetup.sh
# Clean out directory
make clobber
# Make angler
brunch ${DEVICE1}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE1}-*.zip
rm ${UPLOADDIR}/*_${DEVICE1}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE1}/pure_nexus_${DEVICE1}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE1}/pure_nexus_${DEVICE1}-*.zip.md5sum ${UPLOADDIR}
# Upload files
. ~/upload.sh
# Clean out directory
make clobber
# Make shamu
brunch ${DEVICE2}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE2}-*.zip
rm ${UPLOADDIR}/*_${DEVICE2}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE2}/pure_nexus_${DEVICE2}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE2}/pure_nexus_${DEVICE2}-*.zip.md5sum ${UPLOADDIR}
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

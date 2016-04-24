# Variables
SOURCEDIR=~/AOSiP
OUTDIR=~/AOSiP/out/target/product
UPLOADDIR=~/shared/AOSiP
DEVICE=shamu
# Start tracking time
START=$(date +%s)
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
rm ${UPLOADDIR}/*-${DEVICE}-*.zip
rm ${UPLOADDIR}/*-${DEVICE}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE}/AOSiP-*-${DEVICE}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE}/AOSiP-*-${DEVICE}-*.zip.md5sum ${UPLOADDIR}
# Upload files
. ~/upload.sh
# Clean out directory
make clobber
# Go back home
cd ~/
# Success! Stop tracking time
END=$(date +%s)
echo "====================================="
echo "Compilation and upload successful!"
echo "Total time elapsed: $(echo $(($END-$START)) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"
echo "====================================="

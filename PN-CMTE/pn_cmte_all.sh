# Variables
SOURCEDIR=~/ROMs/PN-CMTE
OUTDIR=${SOURCEDIR}/out/target/product
UPLOADDIR=~/shared/.special/.pn-release
DEVICE1=angler
DEVICE2=bullhead
DEVICE3=deb
DEVICE4=flo
DEVICE5=flounder
DEVICE6=hammerhead
DEVICE7=shamu
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
make clean
make clobber
# Make bullhead
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
make clean
make clobber
# Make deb
brunch ${DEVICE3}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE3}-*.zip
rm ${UPLOADDIR}/*_${DEVICE3}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE3}/pure_nexus_${DEVICE3}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE3}/pure_nexus_${DEVICE3}-*.zip.md5sum ${UPLOADDIR}
# Upload files
. ~/upload.sh
# Clean out directory
make clean
make clobber
# Make flo
brunch ${DEVICE4}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE4}-*.zip
rm ${UPLOADDIR}/*_${DEVICE4}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE4}/pure_nexus_${DEVICE4}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE4}/pure_nexus_${DEVICE4}-*.zip.md5sum ${UPLOADDIR}
# Upload files
. ~/upload.sh
# Clean out directory
make clean
make clobber
# Make flounder
brunch ${DEVICE5}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE5}-*.zip
rm ${UPLOADDIR}/*_${DEVICE5}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE5}/pure_nexus_${DEVICE5}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE5}/pure_nexus_${DEVICE5}-*.zip.md5sum ${UPLOADDIR}
# Upload files
. ~/upload.sh
# Clean out directory
make clean
make clobber
# Make hammerhead
brunch ${DEVICE6}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE6}-*.zip
rm ${UPLOADDIR}/*_${DEVICE6}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE6}/pure_nexus_${DEVICE6}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE6}/pure_nexus_${DEVICE6}-*.zip.md5sum ${UPLOADDIR}
# Upload files
. ~/upload.sh
# Clean out directory
make clean
make clobber
# Make shamu
brunch ${DEVICE7}
# Remove exisiting files
rm ${UPLOADDIR}/*_${DEVICE7}-*.zip
rm ${UPLOADDIR}/*_${DEVICE7}-*.zip.md5sum
# Copy new files
mv ${OUTDIR}/${DEVICE7}/pure_nexus_${DEVICE7}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE7}/pure_nexus_${DEVICE7}-*.zip.md5sum ${UPLOADDIR}
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

# Usage: . gapps.sh <banks|pn>

# Parameters
TYPE=$1

# Variables
if [ "${TYPE}" == "banks" ]
then
    SOURCEDIR=~/GApps/Banks
    ZIPBEG=BaNkS
elif [ "${TYPE}" == "pn" ]
then
    SOURCEDIR=~/GApps/PN
    ZIPBEG=PureNexus
fi
UPLOADDIR=~/shared/GApps

# Go into repo folder
cd ${SOURCEDIR}

# Clean unsaved changed
git reset --hard
git clean -f -d

# Get new changes
git pull

# Make GApps
. mkgapps.sh

# Remove current GApps and move the new ones in their place
rm ${UPLOADDIR}/${ZIPBEG}*.zip
mv ${SOURCEDIR}/out/${ZIPBEG}*.zip ${UPLOADDIR}

# Upload them
. ~/upload.sh

# Go home and we're done!
cd ~/
echo "==================================="
echo "Compilation and upload successful!"
echo "==================================="
echo -e "\a"

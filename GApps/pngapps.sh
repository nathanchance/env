# Change to GApps directory
cd ~/GApps/purenexus_dynamic_gapps
# Clean unsaved changed
git reset --hard
git clean -f -d
# Get new changes
git pull
# Make GApps
. mkgapps.sh
# Remove current GApps and move the new ones in their place
rm ~/shared/GApps/PureNexus_*.zip
mv ~/GApps/purenexus_dynamic_gapps/out/PureNexus_*.zip ~/shared/GApps
# Upload them
. ~/upload.sh
# Go home and we're done!
cd ~/
echo "==================================="
echo "Compilation and upload successful!"
echo "==================================="

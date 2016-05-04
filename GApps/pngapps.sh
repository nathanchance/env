cd ~/GApps/purenexus_dynamic_gapps
git pull
. mkgapps.sh
rm ~/shared/GApps/PureNexus_*.zip
mv ~/GApps/purenexus_dynamic_gapps/out/PureNexus_*.zip ~/shared/GApps
. ~/upload.sh
cd ~/
echo "==============================="
echo "Compilation and upload successful!"
echo "==============================="

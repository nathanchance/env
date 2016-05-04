cd ~/GApps/banks_dynamic_gapps
git pull
. mkgapps.sh
rm ~/shared/GApps/BaNkS_Dynamic_*.zip
mv ~/GApps/banks_dynamic_gapps/out/BaNkS_Dynamic_*.zip ~/shared/GApps
. ~/upload.sh
cd ~/
echo "==============================="
echo "Compilation and upload successful!"
echo "==============================="

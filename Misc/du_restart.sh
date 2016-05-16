rm -rf ~/ROMs/DU
mkdir ~/ROMs/DU
cd ~/ROMs/DU
repo init -u https://github.com/DirtyUnicorns/android_manifest.git -b m
repo sync --force-sync
. build/envsetup.sh
breakfast angler
breakfast bullhead
breakfast hammerhead
breakfast shamu

#!/bin/ash

# Setup variables
binary=$1
package=$binary
case $binary in
    diskus) echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >>/etc/apk/repositories ;;
    strip) package=binutils ;;
esac

# Install package
apk -U upgrade -a || exit
apk add --no-cache "$package" || exit

# Setup entrypoint
echo '#!/bin/ash

'"$binary"' "$@"' >/entrypoint.sh
chmod +x /entrypoint.sh

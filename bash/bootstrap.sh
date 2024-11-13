#!/bin/sh

set -eux

tmp_dir=$(mktemp -d)

is_available() {
    command -v "$1" >/dev/null 2>&1
}

for file in /etc/os-release /usr/lib/os-release; do
    # We don't care if this fails, we will fail on the next command
    if . $file >/dev/null 2>&1; then
        break
    fi
done

if ! is_available python3; then
    if is_available apk; then
        apk add python3
    elif is_available dnf; then
        dnf install -y python3
    else
        echo "[-] No suitable command could be found to install python3" >&2
    fi
fi

if is_available curl; then
    dwnld_cmd="curl -LSs"
elif is_available wget; then
    dwnld_cmd="wget -q -O-"
else
    echo "[-] No suitable download command could be found!" >&2
    exit 1
fi

$dwnld_cmd https://github.com/nathanchance/env/tarball/main | tar -C "$tmp_dir" -xvzf - --strip-components=1

python_setup=$tmp_dir/python/setup
if [ ! -d "$python_setup" ]; then
    echo "[-] $python_setup could not be found, did download command fail?" >&2
    exit 1
fi

"$python_setup"/"${ID_LIKE-$ID}".py "$@"

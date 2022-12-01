#!/usr/bin/env bash

set -euxo pipefail

tmp_dir=$(mktemp -d)

curl -LSs https://github.com/nathanchance/env/tarball/main | tar -C "$tmp_dir" -xvzf - --strip-components=1

"$tmp_dir"/python/root/"$(grep ^ID= /usr/lib/os-release | cut -d= -f2 | sed 's/"//g')".py "$@"

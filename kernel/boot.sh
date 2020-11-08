#!/usr/bin/env bash

ROOT=$(dirname "$(readlink -f "${0}")")
BOOT_UTILS=${ROOT}/boot-utils

# Update/download boot-utils
[[ -d ${BOOT_UTILS} ]] || git clone https://github.com/ClangBuiltLinux/boot-utils "${BOOT_UTILS}"
git -C "${BOOT_UTILS}" pull || exit ${?}

# Run boot-qemu.sh
"${BOOT_UTILS}"/boot-qemu.sh "${@}"

#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Copyright (C) 2021 Nathan Chancellor

ACTIONS=()
while ((${#})); do
    case ${1} in
        fish_indent | shellcheck | shfmt) ACTIONS=("${1}") ;;
    esac
    shift
done
[[ -z ${ACTIONS[*]} ]] && ACTIONS=(fish_indent shellcheck shfmt)

set -x

for ACTION in "${ACTIONS[@]}"; do
    case ${ACTION} in
        fish_indent) fd -e fish . fish/ -x fish_indent -c ;;
        shellcheck) fd -t x . bash/ configs/ -x shellcheck ;;
        shfmt) fd -t x . bash/ configs/ -x shfmt -ci -d -i 4 ;;
    esac
done

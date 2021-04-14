#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Copyright (C) 2021 Nathan Chancellor

ACTIONS=()
while ((${#})); do
    case ${1} in
        shellcheck | shfmt) ACTIONS=("${1}") ;;
    esac
    shift
done
[[ -z ${ACTIONS[*]} ]] && ACTIONS=(shellcheck shfmt)

for ACTION in "${ACTIONS[@]}"; do
    case ${ACTION} in
        shellcheck) fd -t x -E windows -x shellcheck ;;
        shfmt) fd -t x -E windows -x shfmt -ci -d -i 4 ;;
    esac
done

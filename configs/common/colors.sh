#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Copyright (C) 2021 Nathan Chancellor

RESET="\033[0m"
BRIGHT_FOREGROUND="\033[1m"

BLACK="\033[30m"
BRIGHT_BLACK="\033[01;30m"

RED="\033[31m"
BRIGHT_RED="\033[01;31m"

GREEN="\033[32m"
BRIGHT_GREEN="\033[01;32m"

YELLOW="\033[33m"
BRIGHT_YELLOW="\033[01;33m"

BLUE="\033[34m"
BRIGHT_BLUE="\033[01;34m"

MAGENTA="\033[35m"
BRIGHT_MAGENTA="\033[01;35m"

CYAN="\033[36m"
BRIGHT_CYAN="\033[01;36m"

GRAY="\033[37m"
WHITE="\033[01;37m"

printf '\nThis is a test of FOREGROUND\n'
printf '%bThis is a test of BRIGHT_FOREGROUND%b\n\n' "${BRIGHT_FOREGROUND}" "${RESET}"

printf '%bThis is a test of BLACK%b\n' "${BLACK}" "${RESET}"
printf '%bThis is a test of BRIGHT_BLACK%b\n\n' "${BRIGHT_BLACK}" "${RESET}"

printf '%bThis is a test of RED%b\n' "${RED}" "${RESET}"
printf '%bThis is a test of BRIGHT_RED%b\n\n' "${BRIGHT_RED}" "${RESET}"

printf '%bThis is a test of GREEN%b\n' "${GREEN}" "${RESET}"
printf '%bThis is a test of BRIGHT_GREEN%b\n\n' "${BRIGHT_GREEN}" "${RESET}"

printf '%bThis is a test of YELLOW%b\n' "${YELLOW}" "${RESET}"
printf '%bThis is a test of BRIGHT_YELLOW%b\n\n' "${BRIGHT_YELLOW}" "${RESET}"

printf '%bThis is a test of BLUE%b\n' "${BLUE}" "${RESET}"
printf '%bThis is a test of BRIGHT_BLUE%b\n\n' "${BRIGHT_BLUE}" "${RESET}"

printf '%bThis is a test of MAGENTA%b\n' "${MAGENTA}" "${RESET}"
printf '%bThis is a test of BRIGHT_MAGENTA%b\n\n' "${BRIGHT_MAGENTA}" "${RESET}"

printf '%bThis is a test of CYAN%b\n' "${CYAN}" "${RESET}"
printf '%bThis is a test of BRIGHT_CYAN%b\n\n' "${BRIGHT_CYAN}" "${RESET}"

printf '%bThis is a test of GRAY%b\n' "${GRAY}" "${RESET}"
printf '%bThis is a test of WHIE%b\n\n' "${WHITE}" "${RESET}"

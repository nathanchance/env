#!/usr/bin/env bash

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

printf "This is a test of \${FOREGROUND}\n"
printf "${BRIGHT_FOREGROUND}This is a test of \${BRIGHT_FOREGROUND}${RESET}\n\n"

printf "${BLACK}This is a test of \${BLACK}${RESET}\n"
printf "${BRIGHT_BLACK}This is a test of \${BRIGHT_BLACK}${RESET}\n\n"

printf "${RED}This is a test of \${RED}${RESET}\n"
printf "${BRIGHT_RED}This is a test of \${BRIGHT_RED}${RESET}\n\n"

printf "${GREEN}This is a test of \${GREEN}${RESET}\n"
printf "${BRIGHT_GREEN}This is a test of \${BRIGHT_GREEN}${RESET}\n\n"

printf "${YELLOW}This is a test of \${YELLOW}${RESET}\n"
printf "${BRIGHT_YELLOW}This is a test of \${BRIGHT_YELLOW}${RESET}\n\n"

printf "${BLUE}This is a test of \${BLUE}${RESET}\n"
printf "${BRIGHT_BLUE}This is a test of \${BRIGHT_BLUE}${RESET}\n\n"

printf "${MAGENTA}This is a test of \${MAGENTA}${RESET}\n"
printf "${BRIGHT_MAGENTA}This is a test of \${BRIGHT_MAGENTA}${RESET}\n\n"

printf "${CYAN}This is a test of \${CYAN}${RESET}\n"
printf "${BRIGHT_CYAN}This is a test of \${BRIGHT_CYAN}${RESET}\n\n"

printf "${GRAY}This is a test of \${GRAY}${RESET}\n"
printf "${WHITE}This is a test of \${WHITE}${RESET}\n\n"

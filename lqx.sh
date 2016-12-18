#!/bin/bash
#
# Compilation script for Liquorix Kernel for Arch Linux
#
# Copyright (C) 2016 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


###########
#         #
#  USAGE  #
#         #
###########

# $ bash lqx.sh <build|install|both>


################
#              #
#  PARAMETERS  #
#              #
################

while [[ $# -ge 1 ]]; do
   case "${1}" in
      "build"|"install"|"both")
         MODE=${1} ;;
      *)
         echo "Invalid parameter" && exit ;;
   esac

   shift
done

if [[ -z ${MODE} ]]; then
   echo "You did not specify a necessary parameter. Falling back to building only"
   MODE=build
fi


################
#              #
# SCRIPT START #
#              #
################

if [[ ${MODE} == "build" || ${MODE} == "both" ]]; then

   # GRAB SOURCE FROM AUR
   cd ${HOME}/Misc/Liquorix
   rm -rf *
   wget https://aur.archlinux.org/cgit/aur.git/snapshot/linux-lqx.tar.gz

   # UNZIP SOURCE
   tar -xvf linux-lqx.tar.gz
   rm -rf linux-lqx.tar.gz

   # MAKE THE KERNEL
   cd linux-lqx
   time makepkg -s

fi

if [[ ${MODE} == "install" || ${MODE} == "both" ]]; then

   # MOVE INTO THE FOLDER (IN CASE THIS SCRIPT IS RAN SOME TIME AFTER BUILD)
   cd ${HOME}/Misc/Liquorix/linux-lqx

   # INSTALL PACKAGE
   makepkg -i

   # MAKE SURE GRUB IS UP TO DATE
   sudo grub-mkconfig -o /boot/grub/grub.cfg

fi

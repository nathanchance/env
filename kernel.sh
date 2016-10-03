#!/bin/bash
#
# Ninja compilation script for the Nexus 6P
#
# Copyright (C) 2016 Nathan Chancellor
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.



# -----
# Usage
# -----
# $ . kernel.sh <release|staging> <angler|bullhead <tcupdate|notcupdate>
# $ . kernel.sh me <tcupdate|notcupdate>
# $ . kernel.sh both <tcupdate|notcupdate>


# Prints a formatted header; used for outlining what the script is doing to the user
function echoText() {
   RED="\033[01;31m"
   RST="\033[0m"

   echo -e ${RED}
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e "==  ${1}  =="
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e ${RST}
}


# Creates a new line
function newLine() {
   echo -e ""
}


# Compilation function
function compile() {
   # ----------
   # Parameters
   # ----------
   # PERSONAL: Whether or not it is a build just for me
   # TEST: Whether or not we are running a test build
   # VERSION: m or n

   # Free flags
   PERSONAL=false
   TEST=false
   SUCCESS=false
   UPDATE_TC=false
   VERSION=

   # Set flags/variables based on parameter
   case "${1}" in
      "me")
         PERSONAL=true ;;
      "test")
         TEST=true ;;
      *)
         VERSION=${1} ;;
   esac



   # ------
   # Colors
   # ------
   RED="\033[01;31m"
   BLINK_RED="\033[05;31m"
   RESTORE="\033[0m"



   # ---------
   # Variables
   # ---------
   # THREAD: Number of available threads on computer
   THREAD=-j$(grep -c ^processor /proc/cpuinfo)
   # KERNEL: File name of completed image
   KERNEL=Image.gz-dtb
   # DEFCONFIG: Name of defconfig file
   DEFCONFIG=ninja_defconfig
   # DEVICE: device we are compiling for
   DEVICE=angler



   # -----------
   # Directories
   # -----------
   # ANDROID_DIR: Directory that holds all Android related files
   ANDROID_DIR=${HOME}
   # RESOURCE_DIR: Directory that holds all kernel related files
   RESOURCE_DIR=${ANDROID_DIR}/Kernels
   # ZIP_MOVE_PARENT: The parent to the directory that holds all of the completed kernel files
   ZIP_MOVE_PARENT=${HOME}/Web
   # If we are running a personal build, use different branches
   if [[ ${PERSONAL} = true ]]; then
      # SOURCE_DIR: Folder that holds the source
      SOURCE_DIR=${RESOURCE_DIR}/Ninja
      # KER_BRANCH: Branch of kernel to compile
      KER_BRANCH=personal
      # ZIP_MOVE: Folder that holds completed zips
      ZIP_MOVE=${ZIP_MOVE_PARENT}/.hidden/Kernels
   else
      case "${VERSION}" in
         "n-release")
            # SOURCE_DIR: Folder that holds the source
            SOURCE_DIR=${RESOURCE_DIR}/Ninja
            # KER_BRANCH: Branch of kernel to compile
            KER_BRANCH=release
            # ZIP_MOVE: Folder that holds completed zips
            ZIP_MOVE=${ZIP_MOVE_PARENT}/Kernels/${DEVICE}/N-Release ;;
         "n-staging")
            # SOURCE_DIR: Folder that holds the source
            SOURCE_DIR=${RESOURCE_DIR}/Ninja
            # KER_BRANCH: Branch of kernel to compile
            KER_BRANCH=staging
            # ZIP_MOVE: Folder that holds completed zips
            ZIP_MOVE=${ZIP_MOVE_PARENT}/Kernels/${DEVICE}/N-Staging ;;
         "m-release")
            # SOURCE_DIR: Folder that holds the source
            SOURCE_DIR=${RESOURCE_DIR}/Ninja-Legacy
            # KER_BRANCH: Branch of kernel to compile
            KER_BRANCH=m-release
            # ZIP_MOVE: Folder that holds completed zips
            ZIP_MOVE=${ZIP_MOVE_PARENT}/Kernels/${DEVICE}/M-Release ;;
         "m-staging")
            # Different source directory
            SOURCE_DIR=${RESOURCE_DIR}/Ninja-Legacy
            # KER_BRANCH: Branch of kernel to compile
            KER_BRANCH=m-staging
            # ZIP_MOVE: Folder that holds completed zips
            ZIP_MOVE=${ZIP_MOVE_PARENT}/Kernels/${DEVICE}/M-Staging ;;
      esac
   fi
   # SOURCE_DIR: Directory that holds kernel source
   # case ${2} in
   #    "angler")
   #       DEVICE=${2}
   #       SOURCE_DIR=${RESOURCE_DIR}/Ninja-Angler ;;
   #    "bullhead")
   #       DEVICE=${2}
   #       SOURCE_DIR=${RESOURCE_DIR}/Ninja-Bullhead ;;
   # esac
   # TOOLCHAIN_SOURCE_DIR: Directory that holds toolchain
   case ${PERSONAL} in
      "true")
         DEVICE=angler
         SOURCE_DIR=${RESOURCE_DIR}/Ninja
         TOOLCHAIN_SOURCE_DIR=${RESOURCE_DIR}/Toolchains/Linaro
         TOOLCHAIN_NAME=aarch64-linux-android-6.x-kernel
         TOOCHAIN_COMPILED_DIR=${TOOLCHAIN_SOURCE_DIR}/out/${TOOLCHAIN_NAME} ;;
      "false")
         case ${DEVICE} in
            "angler")
               TOOLCHAIN_SOURCE_DIR=${RESOURCE_DIR}/Toolchains/Linaro
               TOOLCHAIN_NAME=aarch64-linux-android-6.x-kernel
               TOOCHAIN_COMPILED_DIR=${TOOLCHAIN_SOURCE_DIR}/out/${TOOLCHAIN_NAME} ;;
            "bullhead")
               TOOLCHAIN_SOURCE_DIR=${RESOURCE_DIR}/Toolchains/Linaro
               TOOLCHAIN_NAME=aarch64-linux-android-4.9-kernel
               TOOCHAIN_COMPILED_DIR=${TOOLCHAIN_SOURCE_DIR}/out/${TOOLCHAIN_NAME} ;;
         esac
   esac
   # ZIMAGE_DIR: Directory that holds completed Image.gz
   ZIMAGE_DIR=${SOURCE_DIR}/arch/arm64/boot
   # ANYKERNEL_DIR: Directory that holds AnyKernel source
   ANYKERNEL_DIR=${SOURCE_DIR}/anykernel



   # -------
   # Exports
   # -------
   # CROSS_COMPILE: Location of toolchain
   export CROSS_COMPILE="${TOOCHAIN_COMPILED_DIR}/bin/aarch64-linux-android-"
   # ARCH and SUBARCH: Architecture we want to compile for
   export ARCH=arm64
   export SUBARCH=arm64

   # Export the LOG variable for other files to use (I currently handle this via .bashrc)
   # export LOG_DIR=${ANDROID_DIR}/Logs
   # export LOG=${LOG_DIR}/compile_log_$( TZ=MST  date +%m_%d_%y ).log



   # ---------
   # Functions
   # ---------
   # Clean the out and AnyKernel dirs and make clean
   function clean_all {
      # Cleaning of AnyKernel directory
      cd "${ANYKERNEL_DIR}"
      rm -rf ${KERNEL} > /dev/null 2>&1

      echo

      # Cleaning of kernel directory
      cd "${SOURCE_DIR}"
      if [[ ${TEST} = false ]]; then
         git reset --hard origin/${KER_BRANCH}
         git clean -f -d -x > /dev/null 2>&1; newLine
         git pull
      else
         git clean -f -d -x > /dev/null 2>&1
      fi

      # Clean .config
      make clean
      make mrproper
   }


   # Update toolchain
   function update_tc {
      # Move into the toolchain directory
      cd "${TOOLCHAIN_SOURCE_DIR}"
      # Repo sync
      time repo sync --force-sync ${THREAD}
      # Run the toolchain script
      cd scripts
      source ${TOOLCHAIN_NAME}
   }


   # Make the kernel
   function make_kernel {
      echo
      cd "${SOURCE_DIR}"

      # If this is a personal build, set the version to 21
      if [[ ${PERSONAL} = true ]]; then
         rm -rf .version
         touch .version
         echo 20 >> .version
      fi

      # Make the DEFCONFIG and the kernel with the right number of threads
      make ${DEFCONFIG}
      time make ${THREAD}
   }


   # Make the zip file, remove the previous version and upload it
   function make_zip {
      # Copy Image.gz
      echoText "MOVING $( echo ${KERNEL} | awk '{print toupper($0)}' ) ($( du -h "${ZIMAGE_DIR}"/${KERNEL} | awk '{print $1}' ))"
      cp -vr "${ZIMAGE_DIR}"/${KERNEL} "${ANYKERNEL_DIR}"/zImage > /dev/null 2>&1

      # Make zip format variable
      ZIP_FORMAT=N*.zip

      # If ZIPMOVE doesn't exist, make it; otherwise, clean it
      if [[ ! -d "${ZIP_MOVE}" ]]; then
         mkdir -p "${ZIP_MOVE}"
      else
         # Remove the old zip file
         rm -rf "${ZIP_MOVE}"/${ZIP_FORMAT}
      fi

      # Move to AnyKernel directory
      cd "${ANYKERNEL_DIR}"

      # Make zip file
      echoText "MAKING FLASHABLE ZIP"
      zip -r9 ${ZIP_NAME}.zip * -x README ${ZIP_NAME}.zip > /dev/null 2>&1

      # Move the new zip to ZIP_MOVE
      echoText "MOVING FLASHABLE ZIP"
      mv ${ZIP_NAME}.zip "${ZIP_MOVE}"

      # Go to the kernel directory
      cd "${SOURCE_DIR}"

      # If it isn't a test build, clean it
      if [[ ${TEST} = false ]]; then
         git reset --hard origin/${KER_BRANCH} > /dev/null 2>&1
         git clean -f -d -x > /dev/null 2>&1
         cd ${HOME}
      fi
   }



   # Clear the terminal
   clear



   # Time the start of the script
   DATE_START=$( TZ=MST date +"%s" )



   # Silently shift to correct branches
   cd "${SOURCE_DIR}" && git checkout ${KER_BRANCH} > /dev/null 2>&1


   # Set the kernel version
   KERNEL_VERSION=$( grep -r "EXTRAVERSION = -" ${SOURCE_DIR}/Makefile | sed 's/EXTRAVERSION = -//' )
   ZIP_NAME=${KERNEL_VERSION}-${DEVICE}


   # Show the version of the kernel compiling
   echo -e ${RED}; newLine
   echo -e "======================================================================="; newLine; newLine
   case ${PERSONAL} in
      "true")
         echo -e "    ________    ___   _____ __  __    __ __ __________  _   __________ "
         echo -e "   / ____/ /   /   | / ___// / / /   / //_// ____/ __ \/ | / / ____/ / "
         echo -e "  / /_  / /   / /| | \__ \/ /_/ /   / ,<  / __/ / /_/ /  |/ / __/ / /  "
         echo -e " / __/ / /___/ ___ |___/ / __  /   / /| |/ /___/ _, _/ /|  / /___/ /___"
         echo -e "/_/   /_____/_/  |_/____/_/ /_/   /_/ |_/_____/_/ |_/_/ |_/_____/_____/"; newLine; newLine; newLine ;;
      "false")
         echo -e "    _   _______   __    _____       __ __ __________  _   __________ "
         echo -e "   / | / /  _/ | / /   / /   |     / //_// ____/ __ \/ | / / ____/ / "
         echo -e "  /  |/ // //  |/ /_  / / /| |    / ,<  / __/ / /_/ /  |/ / __/ / /  "
         echo -e " / /|  // // /|  / /_/ / ___ |   / /| |/ /___/ _, _/ /|  / /___/ /___"
         echo -e "/_/ |_/___/_/ |_/\____/_/  |_|  /_/ |_/_____/_/ |_/_/ |_/_____/_____/"; newLine; newLine; newLine ;;
   esac
   echo -e "======================================================================="; newLine; newLine







   echoText "KERNEL VERSION"; newLine

   echo -e ${RED}${BLINK_RED}${ZIP_NAME}${RESTORE}; newLine


   echoText "BUILD SCRIPT STARTING AT $( TZ=MST date +%D\ %r )"


   # Update toolchain if requested
   if [[ "${2}" == "tcupdate" || "${3}" == "tcupdate" ]]; then
      echoText "UPDATING TOOLCHAIN"; newLine

      update_tc
   fi


   # Clean up
   echoText "CLEANING UP"

   clean_all


   # Make the kernel
   echoText "MAKING KERNEL"

   make_kernel


   # If the above was successful
   if [[ `ls ${ZIMAGE_DIR}/${KERNEL} 2>/dev/null | wc -l` != "0" ]]; then
      BUILD_RESULT_STRING="BUILD SUCCESSFUL"
      SUCCESS=true

      make_zip


      # Upload
      # echoText "UPLOADING ZIP FILE"; newLine

   else
      BUILD_RESULT_STRING="BUILD FAILED"
      SUCCESS=false
   fi



   # End the script
   newLine; echoText "${BUILD_RESULT_STRING}!"

   DATE_END=$( TZ=MST  date +"%s" )
   DIFF=$((${DATE_END} - ${DATE_START}))

   # Print the zip location and its size if the script was successful
   if [[ ${SUCCESS} = true ]]; then
      echo -e ${RED}"ZIP: ${ZIP_MOVE}/${ZIP_NAME}.zip"
      echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_NAME}.zip | awk '{print $1}' )"${RESTORE}
   fi

   # Print the time the script finished and how long the script ran for regardless of success
   echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
   echo -e "DURATION: $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS"${RESTORE}; newLine



   # Add line to compile log in the following format:
   # DATE: BASH_SOURCE (PARAMETERS)
   echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${1}" >> ${LOG}

   # BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
   echo -e "${BUILD_RESULT_STRING} IN $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS" >> ${LOG}

   # Only add a line about file location if script completed succesfully
   if [[ ${SUCCESS} = true ]]; then
      # FILE LOCATION: PATH
      echo -e "FILE LOCATION: ${ZIP_MOVE}/${ZIP_NAME}.zip" >> ${LOG}
   fi

   # Alert the user that the script is done
   echo -e "\a"
}

case ${1} in
   "both-staging")
      # Run the two kernel builds
      compile n-staging ${2}
      compile m-staging ;;
   "both-release")
      # Run the two kernel builds
      compile n-release ${2}
      compile m-release ;;
   "both-n")
      # Run the two kernel builds
      compile n-release ${2}
      compile n-staging ;;
   "both-m")
      # Run the two kernel builds
      compile m-release ${2}
      compile m-staging ;;
   "all")
      # Run all four kernel builds
      compile n-release ${2}
      compile m-release
      compile n-staging
      compile m-staging ;;
   *)
      compile ${1} ${2} ;;
esac

cd ${HOME}

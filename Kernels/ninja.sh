#!/bin/bash

# -----
# Usage
# -----
# $ . ninja.sh <m|n|me>



function compile {
   # ----------
   # Parameters
   # ----------
   # PERSONAL: Whether or not it is a build just for me

   # Free flags
   PERSONAL=false
   TEST=false

   # Set USER and HOST variables back to what they are in .bashrc
   export KBUILD_BUILD_USER=nathan
   export KBUILD_BUILD_HOST=phoenix

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



   # ----------
   # Directories
   # ----------
   ANDROID_DIR=${HOME}
   RESOURCE_DIR=${ANDROID_DIR}/Kernels
   KERNEL_DIR=${RESOURCE_DIR}/Ninja/Kernel
   ANYKERNEL_DIR=${RESOURCE_DIR}/Ninja/AK2
   TOOLCHAIN_DIR=${RESOURCE_DIR}/Toolchains/Linaro/DF-6.1
   PATCH_DIR="${ANYKERNEL_DIR}/patch"
   MODULES_DIR="${ANYKERNEL_DIR}/modules"
   ZIMAGE_DIR="${KERNEL_DIR}/arch/arm64/boot"


   # ---------
   # Variables
   # ---------
   THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
   KERNEL="Image.gz"
   DTBIMAGE="dtb"
   DEFCONFIG="ninja_defconfig"
   AK_BRANCH=ninja
   KERNEL_VERSION=$( grep -r "EXTRAVERSION = -" ${KERNEL_DIR}/Makefile | sed 's/EXTRAVERSION = -//' )

   if [[ ${PERSONAL} = true || ${TEST} = true ]]; then
      KER_BRANCH=personal
      AK_BRANCH=personal
      TOOLCHAIN_DIR=Toolchains/Linaro/DF-6.1
      ZIP_MOVE=${HOME}/shared/.me
      export KBUILD_BUILD_USER=nathan
      export KBUILD_BUILD_HOST=phoenix
   else
      case "${VERSION}" in
         "m")
            KER_BRANCH=m
            ZIP_MOVE=${HOME}/shared/Kernels/angler/Ninja/M ;;
         "n")
            KER_BRANCH=n
            VER=".N.005."
            ZIP_MOVE=${HOME}/shared/Kernels/angler/Ninja/N ;;
      esac
   fi



   # -------
   # Exports
   # -------
   export CROSS_COMPILE="${TOOLCHAIN_DIR}/bin/aarch64-linux-android-"
   export ARCH=arm64
   export SUBARCH=arm64
   # Export the LOG variable for other files to use (I currently handle this via .bashrc)
   # export LOGDIR=${ANDROID_DIR}/Logs
   # export LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log



   # ---------
   # Functions
   # ---------
   # Clean the out and AnyKernel dirs, reset the AnyKernel dir, and make clean
   function clean_all {
      if [[ -f "${MODULES_DIR}/*.ko" ]]; then
        rm `echo ${MODULES_DIR}"/*.ko"`
      fi

      cd ${ANYKERNEL_DIR}
      rm -rf ${KERNEL} > /dev/null 2>&1
      rm -rf ${DTBIMAGE} > /dev/null 2>&1
      git checkout ${AK_BRANCH}
      git reset --hard origin/${AK_BRANCH}
      git clean -f -d -x > /dev/null 2>&1
      git pull > /dev/null 2>&1

      echo

      cd ${KERNEL_DIR}
      git checkout ${KER_BRANCH}
      if [[ ${TEST} = false ]]; then
         git reset --hard origin/${KER_BRANCH}
         git clean -f -d -x > /dev/null 2>&1
         git pull
      fi

      make clean
      make mrproper
   }

   # Make the kernel
   function make_kernel {
      echo
      cd ${KERNEL_DIR}

      # If this is a personal build, set the version to 21
      if [[ ${PERSONAL} = true ]]; then
         rm -rf .version
         touch .version
         echo 20 >> .version
      fi

      # Make the DEFCONFIG and the kernel with the right number of threads
      make ${DEFCONFIG}
      make ${THREAD}
   }

   # Make the modules
   function make_modules {
      if [[ -f "${MODULES_DIR}/*.ko" ]]; then
         rm `echo ${MODULES_DIR}"/*.ko"`
      fi
      #find $MODULES_DIR/proprietary -name '*.ko' -exec cp -v {} $MODULES_DIR \;
      find ${KERNEL_DIR} -name '*.ko' -exec cp -v {} ${MODULES_DIR} \;
   }

   # Make the DTB file
   function make_dtb {
      ${ANYKERNEL_DIR}/tools/dtbToolCM -v2 -o ${ANYKERNEL_DIR}/${DTBIMAGE} -s 2048 -p scripts/dtc/ arch/arm64/boot/dts/
   }

   # Make the zip file, remove the previous version and upload it
   function make_zip {
      # Copy Image.gz
      cp -vr ${ZIMAGE_DIR}/${KERNEL} ${ANYKERNEL_DIR}/zImage

      # Move to AnyKernel directory
      cd ${ANYKERNEL_DIR}

      # Make zip file
      zip -x@zipexclude -r9 ${KERNEL_VERSION}.zip *

      # Make zip format variable
      ZIP_FORMAT=N*.zip

      # If ZIPMOVE doesn't exist, make it; otherwise, clean it
      if [[ ! -d "${ZIPMOVE}" ]]; then
         mkdir -p  "${ZIPMOVE}"
      else
         rm -rf ${ZIP_MOVE}/${ZIP_FORMAT}
      fi

      # Move the new zip to ZIP_MOVE
      mv ${KERNEL_VERSION}.zip ${ZIP_MOVE}

      # Go to the kernel directory
      cd ${KERNEL_DIR}

      # If it isn't a test build, clean it
      if [[ ${TEST} = false ]]; then
         git reset --hard origin/${KER_BRANCH}
         git clean -f -d -x > /dev/null 2>&1
         cd ${HOME}
      fi
   }



   # Clear the terminal
   clear



   # Time the start of the script
   DATE_START=$(date +"%s")




   # Show the version of the kernel compiling
   echo -e ${RED}
   echo -e ""
   echo -e "---------------------------------------------------------------------"
   echo -e ""
   echo -e ""
   echo -e "    _   _______   __    _____       __ __ __________  _   __________ ";
   echo -e "   / | / /  _/ | / /   / /   |     / //_// ____/ __ \/ | / / ____/ / ";
   echo -e "  /  |/ // //  |/ /_  / / /| |    / ,<  / __/ / /_/ /  |/ / __/ / /  ";
   echo -e " / /|  // // /|  / /_/ / ___ |   / /| |/ /___/ _, _/ /|  / /___/ /___";
   echo -e "/_/ |_/___/_/ |_/\____/_/  |_|  /_/ |_/_____/_/ |_/_/ |_/_____/_____/";
   echo -e ""
   echo -e ""
   echo -e "---------------------------------------------------------------------"
   echo -e ""
   echo -e ""
   echo -e ""
   echo "---------------"
   echo "KERNEL VERSION:"
   echo "---------------"
   echo -e ""

   echo -e ${BLINK_RED}
   echo -e ${KERNEL_VERSION}
   echo -e ${RESTORE}

   echo -e ${RED}
   echo -e "---------------------------------------------"
   echo -e "BUILD SCRIPT STARTING AT $(date +%D\ %r)"
   echo -e "---------------------------------------------"
   echo -e ${RESTORE}



   # Clean up
   echo -e ${RED}
   echo -e "-----------"
   echo -e "CLEANING UP"
   echo -e "-----------"
   echo -e ${RESTORE}
   echo -e ""

   clean_all



   # Make the kernel
   echo -e ${RED}
   echo -e "-------------"
   echo -e "MAKING KERNEL"
   echo -e "-------------"
   echo -e ${RESTORE}

   make_kernel
   make_dtb
   make_modules



   # If the above was successful
   if [[ `ls ${ZIMAGE_DIR}/${KERNEL} 2>/dev/null | wc -l` != "0" ]]; then
      BUILD_SUCCESS_STRING="BUILD SUCCESSFUL"


      make_zip


      # Upload
      echo -e ${RED}
      echo -e "------------------"
      echo -e "UPLOADING ZIP FILE"
      echo -e "------------------"
      echo -e ${RESTORE}
      echo -e ""

      . ${HOME}/upload.sh
   else
      BUILD_SUCCESS_STRING="BUILD FAILED"
   fi



   # End the script
   echo -e ""
   echo -e ${RED}
   echo "--------------------"
   echo "SCRIPT COMPLETED IN:"
   echo "--------------------"

   DATE_END=$(date +"%s")
   DIFF=$((${DATE_END} - ${DATE_START}))

   echo -e "${BUILD_SUCCESS_STRING}!"
   echo -e "TIME: $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS"

   echo -e ${RESTORE}

   # Add line to compile log
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${VERSION} ${TOOLCHAIN_VER}" >> ${LOG}
   echo -e "${BUILD_SUCCESS_STRING} IN $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS\n" >> ${LOG}

   echo -e "\a"
}

if [[ "${1}" == "both" ]]; then
   # Update toolchains if requested
   if [[ "${2}" == "tcupdate" ]]; then
      . sync_toolchains.sh
   fi

   # Run my build after syncing toolchains
   compile me

   # Run the two kernel builds
   compile m
   compile n

   cd ${HOME}
   cat ${LOG}
else
   compile ${1}
fi

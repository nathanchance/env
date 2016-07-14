#!/bin/bash

# -----
# Usage
# -----
# $ . kylo.sh <toolchain> <tcupdate>



function compile() {
   # ------
   # Colors
   # ------
   RED="\033[01;31m"
   BLINK_RED="\033[05;31m"
   RESTORE="\033[0m"



   # ----------
   # Parameters
   # ----------
   # TOOLCHAIN: Toolchain to compile with
   # Free flags
   PERSONAL=
   if [[ "${1}" == "me" ]]; then
      PERSONAL=true
   else
      TOOLCHAIN=${1}
   fi



   # ----------
   # Directories
   # ----------
   ANDROID_DIR=${HOME}
   RESOURCE_DIR=${ANDROID_DIR}/Kernels
   KERNEL_DIR=${RESOURCE_DIR}/Kylo
   ZIMAGE_DIR="${KERNEL_DIR}/arch/arm64/boot"
   ANYKERNEL_DIR=${KERNEL_DIR}/out
   ZIP_MOVE=${HOME}/shared/Kernels/angler/Kylo



   # ---------
   # Variables
   # ---------
   THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
   KERNEL="Image.gz-dtb"
   DEFCONFIG="kylo_defconfig"
   if [[ ${PERSONAL} = true ]]; then
      TOOLCHAIN_DIR=Toolchains/Linaro/DF-6.1
      AK_VER="Kylo.R33"
      ZIP_MOVE=${HOME}/shared/.me
   else
      BASE_KYLO_VER="Kylo"
      VER=".R33.M.angler."

      case "${TOOLCHAIN}" in
         "aosp")
            TOOLCHAIN_VER="AOSP4.9"
            TOOLCHAIN_DIR=Toolchains/AOSP ;;
         "uber4")
            TOOLCHAIN_VER="UBER4.9"
            TOOLCHAIN_DIR=Toolchains/UBER/4.9 ;;
         "uber5")
            TOOLCHAIN_VER="UBER5.4"
            TOOLCHAIN_DIR=Toolchains/UBER/5.4 ;;
         "uber6")
            TOOLCHAIN_VER="UBER6.1"
            TOOLCHAIN_DIR=Toolchains/UBER/6.1 ;;
         "uber7")
            TOOLCHAIN_VER="UBER7.0"
            TOOLCHAIN_DIR=Toolchains/UBER/7.0 ;;
         "linaro4.9")
            TOOLCHAIN_VER="LINARO4.9"
            TOOLCHAIN_DIR=Toolchains/Linaro/4.9 ;;
         "linaro5.4")
            TOOLCHAIN_VER="LINARO5.4"
            TOOLCHAIN_DIR=Toolchains/Linaro/5.4 ;;
         "linaro6.1")
            TOOLCHAIN_VER="LINARO6.1"
            TOOLCHAIN_DIR=Toolchains/Linaro/6.1 ;;
         "df-linaro4.9")
            TOOLCHAIN_VER="DF-LINARO4.9"
            TOOLCHAIN_DIR=Toolchains/Linaro/DF-4.9 ;;
         "df-linaro5.4")
            TOOLCHAIN_VER="DF-LINARO5.4"
            TOOLCHAIN_DIR=Toolchains/Linaro/DF-5.4 ;;
         "df-linaro6.1")
            TOOLCHAIN_VER="DF-LINARO6.1"
            TOOLCHAIN_DIR=Toolchains/Linaro/DF-6.1 ;;
      esac

      KYLO_VER="${BASE_KYLO_VER}${VER}${TOOLCHAIN_VER}"
   fi


   # -------
   # Exports
   # -------
   export LOCALVERSION=-`echo ${KYLO_VER}`
   export CROSS_COMPILE="${RESOURCE_DIR}/${TOOLCHAIN_DIR}/bin/aarch64-linux-android-"
   export ARCH=arm64
   export SUBARCH=arm64
   # Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
   # export LOGDIR=${ANDROID_DIR}/Logs
   # export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log


   # ---------
   # Functions
   # ---------
   # Clean the out and AnyKernel dirs, reset the AnyKernel dir, and make clean
   function clean_all {
      cd ${KERNEL_DIR}
      echo
      make clean
      make mrproper
      rm -rf ${KERNEL_DIR}/out/kernel/zImage
      git reset --hard origin/maul
      git clean -f -d -x
   }

   # Make the kernel
   function make_kernel {
      echo
      cd ${KERNEL_DIR}
      make ${DEFCONFIG}
      make ${THREAD}
   }

   # Make the zip file, remove the previous version and upload it
   function make_zip {
      cp -vr ${ZIMAGE_DIR}/${KERNEL} ${ANYKERNEL_DIR}/kernel/zImage
      cd ${ANYKERNEL_DIR}
      zip -r9 `echo ${KYLO_VER}`.zip *
      rm  ${ZIP_MOVE}/${BASE_KYLO_VER}*${TOOLCHAIN_VER}.zip
      mv  `echo ${KYLO_VER}`.zip ${ZIP_MOVE}
      cd ${KERNEL_DIR}
   }



   # Clear the terminal
   clear



   # Time the start of the script
   DATE_START=$(date +"%s")



   # Show the version of the kernel compiling
   echo -e ${RED}
   echo -e ""
   echo -e ""
   echo "--------------------"
   echo "KYLO KERNEL VERSION:"
   echo "--------------------"
   echo -e ""

   echo -e ${BLINK_RED}
   echo -e ${KYLO_VER}
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



   # Update the git
   echo -e ""
   echo -e ${RED}
   echo -e "----------------"
   echo -e "UPDATING SOURCES"
   echo -e "----------------"
   echo -e ${RESTORE}

   git pull



   # Make the kernel
   echo -e ""
   echo -e ${RED}
   echo -e "-------------"
   echo -e "MAKING KERNEL"
   echo -e "-------------"
   echo -e ${RESTORE}

   make_kernel



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
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${TOOLCHAIN_VER}" >> ${COMPILE_LOG}
   echo -e "${BUILD_SUCCESS_STRING} IN $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS\n" >> ${COMPILE_LOG}

   echo -e "\a"
}

if [[ "${1}" == "all" ]]; then
   if [[ "${2}" == "tcupdate" ]]; then
      . sync_toolchains.sh
   fi

   compile me

   TOOLCHAINS="aosp uber4 uber5 uber6 uber7 linaro4.9 linaro5.4 linaro6.1 df-linaro4.9 df-linaro5.4 df-linaro6.1"
   for TOOLCHAIN in ${TOOLCHAINS}; do
      compile ${TOOLCHAIN}
   done

   cd ${HOME}
   cat ${COMPILE_LOG}
else
   compile ${1}
fi

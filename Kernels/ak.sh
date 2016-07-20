#!/bin/bash

# -----
# Usage
# -----
# For one build:
# $ . ak.sh <toolchain> <norm|eas|nh> (per)
# For all builds:
# $ . ak.sh all <tcupdate|notcupdate> (norm|eas|nh) (per)



function compile {
   # ----------
   # Parameters
   # ----------
   # TOOLCHAIN: Toolchain to compile with
   # VERSION: Normal, EAS, or NetHunter
   # PERMISSIVE: Force kernel to be permissive

   # Free flags
   PERSONAL=false
   PERMISSIVE=false

   # Set USER and HOST variables back to what they are in .bashrc
   export KBUILD_BUILD_USER=nathan
   export KBUILD_BUILD_HOST=phoenix

   # If the first parameter is "me", set the personal flag to true
   if [[ "${1}" == "me" ]]; then
      PERSONAL=true
   # Otherwise, parameters are as above.
   else
      TOOLCHAIN=${1}
      VERSION=${2}

      if [[ -n ${3} && "${3}" == "per" ]]; then
         PERMISSIVE=true
      fi
   fi

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
   KERNEL_DIR=${RESOURCE_DIR}/AK
   ANYKERNEL_DIR=${RESOURCE_DIR}/AK-AK2
   PATCH_DIR="${ANYKERNEL_DIR}/patch"
   MODULES_DIR="${ANYKERNEL_DIR}/modules"
   ZIMAGE_DIR="${KERNEL_DIR}/arch/arm64/boot"



   # ---------
   # Variables
   # ---------
   THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
   KERNEL="Image.gz"
   DTBIMAGE="dtb"
   DEFCONFIG="ak_angler_defconfig"
   AK_BRANCH=ak-angler-anykernel

   if [[ ${PERSONAL} = true ]]; then
      AK_VER="AK.066-5"
      KER_BRANCH=ak-mm-staging
      TOOLCHAIN_DIR=Toolchains/Linaro/DF-6.1
      PERMISSIVE=true
      ZIP_MOVE=${HOME}/shared/.me
      export KBUILD_BUILD_USER=nathan
      export KBUILD_BUILD_HOST=phoenix

   else
      BASE_AK_VER="AK"

      case "${VERSION}" in
         "norm")
            KER_BRANCH=ak-mm-staging
            VER=".066-5.ANGLER."
            ZIP_MOVE=${HOME}/shared/Kernels/angler/AK/Normal ;;
         "eas")
            KER_BRANCH=ak-mm-staging-eas
            VER=".066-5.ANGLER.EAS."
            ZIP_MOVE=${HOME}/shared/Kernels/angler/AK/EAS ;;
         "nh")
            KER_BRANCH=ak-mm-staging-nh
            VER=".066-5.ANGLER.NH."
            ZIP_MOVE=${HOME}/shared/Kernels/angler/AK/NH ;;
         "test")
            KER_BRANCH=n-testing-2
            # AK_BRANCH=master
            # DEFCONFIG=angler_defconfig
            VER=".N.ANGLER."
            ZIP_MOVE=${HOME}/shared/Kernels/angler/AK/.tests ;;
         "n")
            KER_BRANCH=nougat
            VER=".N.001.ANGLER."
            ZIP_MOVE=${HOME}/shared/Kernels/angler/AK/.tests ;;
      esac

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

      AK_VER="${BASE_AK_VER}${VER}${TOOLCHAIN_VER}"
   fi



   # -------
   # Exports
   # -------
   export LOCALVERSION=-`echo ${AK_VER}`
   export CROSS_COMPILE="${RESOURCE_DIR}/${TOOLCHAIN_DIR}/bin/aarch64-linux-android-"
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
      if [[ "${VERSION}" != "test" ]]; then
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

      # If the permissive flag is true, cherry pick the permissive commit and set a new ZIPMOVE directory if the build is not personal
      if [[ ${PERMISSIVE} = true ]]; then
         git cherry-pick ba804bd138aa89dbe2f2fc73fd751af60a831097
         if [[ ${PERSONAL} = false ]]; then
            ZIP_MOVE=${ZIP_MOVE}/Permissive
         fi
      fi

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
      cp -vr ${ZIMAGE_DIR}/${KERNEL} ${ANYKERNEL_DIR}/zImage
      cd ${ANYKERNEL_DIR}
      zip -x@zipexclude -r9 `echo ${AK_VER}`.zip *
      if [[ ${PERSONAL} = true ]]
      then
         rm -rf ${ZIP_MOVE}/AK*.zip
      else
         rm  ${ZIP_MOVE}/${BASE_AK_VER}*${TOOLCHAIN_VER}.zip
      fi
      mv  `echo ${AK_VER}`.zip ${ZIP_MOVE}
      if [[ "${VERSION}" == "test" ]]; then
         cd ${KERNEL_DIR}
      else
         cd ${HOME}
      fi
   }



   # Clear the terminal
   clear



   # Time the start of the script
   DATE_START=$(date +"%s")



   # Show the version of the kernel compiling
   echo -e ${RED}
   echo -e "-------------------------------------------------------"
   echo -e ""
   echo -e "      ___    __ __    __ __ __________  _   __________ ";
   echo -e "     /   |  / //_/   / //_// ____/ __ \/ | / / ____/ / ";
   echo -e "    / /| | / ,<     / ,<  / __/ / /_/ /  |/ / __/ / /  ";
   echo -e "   / ___ |/ /| |   / /| |/ /___/ _, _/ /|  / /___/ /___";
   echo -e "  /_/  |_/_/ |_|  /_/ |_/_____/_/ |_/_/ |_/_____/_____/";
   echo -e ""
   echo -e ""
   echo -e "-------------------------------------------------------"
   echo -e ""
   echo -e ""
   echo -e ""
   echo "---------------"
   echo "KERNEL VERSION:"
   echo "---------------"
   echo -e ""

   echo -e ${BLINK_RED}
   echo -e ${AK_VER}
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
   if [ "${FETCHUPSTREAM}" == "update" ]
   then
      echo -e ${RED}
      echo -e "----------------"
      echo -e "UPDATING SOURCES"
      echo -e "----------------"
      echo -e ${RESTORE}

      update_git
   fi



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

if [[ "${1}" == "all" ]]; then
   TOOLCHAINS="aosp uber4 uber5 uber6 uber7 linaro4.9 linaro5.4 linaro6.1 df-linaro4.9 df-linaro5.4 df-linaro6.1"
   VERSIONS="norm eas nh"

   # Update toolchains if requested
   if [[ "${2}" == "tcupdate" ]]; then
      . sync_toolchains.sh
   fi

   # Run my build after syncing toolchains
   compile me

   # If there is a third parameter and it is not per, we are running all the builds of one particular version
   if [[ -n ${3} && "${3}" != "per" ]]; then
      for TOOLCHAIN in ${TOOLCHAINS}; do
         compile ${TOOLCHAIN} ${3} ${4}
      done
   # Otherwise, we're running all three versions and their toolchain options
   else
      for VERSION in ${VERSIONS}; do
         for TOOLCHAIN in ${TOOLCHAINS}; do
            compile ${TOOLCHAIN} ${VERSION} ${3}
         done
      done
   fi

   cd ${HOME}
   cat ${LOG}
else
   compile ${1} ${2} ${3}
fi

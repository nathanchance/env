#!/bin/bash
# Copyright (C) 2015-2016 DragonTC
#
# Licensed under the Apache License, Version 2.0 (the "License");
#   You may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


############
#          #
#  COLORS  #
#          #
############

RED=$(tput setaf 1) # RED
GRN=$(tput setaf 2) # GREEN
BLU=$(tput setaf 4) # BLUE
CYA=$(tput setaf 6) # CYAN
TXTBLD=$(tput bold) # BOLD
BLDRED=${TXTBLD}$(tput setaf 1) # RED
BLDGRN=${TXTBLD}$(tput setaf 2) # GREEN
BLDBLU=${TXTBLD}$(tput setaf 4) # BLUE
BLDCYA=${TXTBLD}$(tput setaf 6) # CYAN
TXTRST=$(tput sgr0) # RESET


###############
#             #
#  VARIABLES  #
#             #
###############

# GET NUMBER OF CPUS
CPUS=$( grep "^processor" /proc/cpuinfo | wc -l )
# SET NUMBER OF JOBS
JOBS=$(bc <<< "$CPUS+2");
# SET DATE FOR COMMIT
DATE=$( date +%Y%m%d )
# SET SOURCE DIRECTORY
SOURCE_DIR=${HOME}/Toolchains/Clang
# SET BUILD DIRECTORY
BUILD_DIR=${SOURCE_DIR}/build
# SET INSTALL DIRECTORY
INSTALL_DIR=${HOME}/Toolchains/Prebuilts/clang-3.9.1


################
#              #
# SCRIPT START #
#              #
################

# CLEAN INSTALL DIR IF IT EXISTS; OTHERWISE MAKE IT
if [[ -d ${INSTALL_DIR} ]]; then
   cd ${INSTALL_DIR} && rm -vrf *
else
   cd $( dirname ${INSTALL_DIR} )
   git clone https://github.com/Flash-ROM/clang_linux-x86_3.9.1 clang-3.9.1
fi


# SYNC DOWN SOURCE; MAKE DIR IF IT DOESN'T EXIST ALREADY
if [[ -d ${SOURCE_DIR} ]]; then
   cd ${SOURCE_DIR}
   repo sync --force-sync -j${CPUS}
else
   mkdir -p ${SOURCE_DIR}
   cd ${SOURCE_DIR}
   repo init -u https://github.com/Flash-ROM/manifest -b llvm
   repo sync --force-sync -j${CPUS}
fi

# CLEAN BUILD DIR
if [[ -d ${BUILD_DIR} ]]; then
   rm -vrf ${BUILD_DIR}
fi
mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR}


# BUILD CLANG
export CC="gcc";
export CXX="g++";
export LD="ld.gold"

# CONSOLIDATE C and C++ FLAGS
COMMON_CXX_FLAGS="-O3 -Wno-macro-redefined -pipe -pthread -g0 -march=native -mtune=native $LOCAL_CXX_FLAGS"
COMMON_C_FLAGS="-O3 -Wno-macro-redefined -pipe -pthread -g0 -march=native -mtune=native $LOCAL_C_FLAGS"

# CONFIGURE LLVM WITH CMAKE
cmake -DLINK_POLLY_INTO_TOOLS:BOOL=ON -DCMAKE_CXX_FLAGS:STRING="${COMMON_CXX_FLAGS}" -DCMAKE_C_FLAGS:STRING="${COMMON_C_FLAGS}" -DLLVM_ENABLE_PIC:BOOL=ON -DCMAKE_INSTALL_PREFIX:PATH=${INSTALL_DIR} -DLLVM_PARALLEL_COMPILE_JOBS=${JOBS} -DLLVM_PARALLEL_LINK_JOBS=${JOBS} -DLLVM_ENABLE_THREADS:BOOL=ON -DLLVM_ENABLE_WARNINGS:BOOL=OFF -DLLVM_ENABLE_WERROR:BOOL=OFF -DLLVM_BUILD_DOCS:BOOL=OFF -DLLVM_INCLUDE_EXAMPLES:BOOL=OFF -DLLVM_INCLUDE_TESTS:BOOL=OFF -DLLVM_BINUTILS_INCDIR:PATH=${SOURCE_DIR}/llvm/tools/binutils/include -DLLVM_TARGETS_TO_BUILD:STRING="X86;ARM;AArch64" -DCMAKE_BUILD_TYPE:STRING=MinSizeRel -DLLVM_OPTIMIZED_TABLEGEN:BOOL=ON -DPOLLY_ENABLE_GPGPU_CODEGEN:BOOL=ON ${SOURCE_DIR}/llvm;

# START BUILD TIME
START_TIME=$( date +%s );

# BUILD LLVM
if ! time cmake --build . -- -j$JOBS; then
   # PRINT FAILURE
   echo "";
   echo -e ${RED} "**************************************" ${TXTRST};
   echo -e ${RED} "       ______      _ __         ____  " ${TXTRST};
   echo -e ${RED} "      / ____/___ _(_) /__  ____/ / /  " ${TXTRST};
   echo -e ${RED} "     / /_  / __ '/ / / _ \/ __  / /   " ${TXTRST};
   echo -e ${RED} "    / __/ / /_/ / / /  __/ /_/ /_/    " ${TXTRST};
   echo -e ${RED} "   /_/    \__,_/_/_/\___/\__,_/_/     " ${TXTRST};
   echo -e ${RED} "                                      " ${TXTRST};
   echo -e ${RED} "     Clang has failed to compile!     " ${TXTRST};
   echo -e ${RED} "**************************************" ${TXTRST};
   exit 1;
else
   # INSTALL TOOLCHAIN
   cmake --build . --target install -- -j$JOBS;

   # COMMIT TOOLCHAIN
   cd ${INSTALL_DIR}/bin
   VERSION=$( ./clang --version | grep version | cut -d ' ' -f 3 )
   cd ..
   git add -A && git commit --signoff -m "Clang ${VERSION}: ${DATE}

Compiled on $( source /etc/os-release; echo ${PRETTY_NAME} ) ($( uname -m ))

Kernel version: $( uname -a )
Host gcc version: $( gcc --version | grep gcc )
Make version: $( make --version  | grep Make )" && git push --force

   # ECHO TIME TAKEN
   END_TIME=$( date +%s );
   TMIN=$(( (END_TIME-START_TIME) / 60 ));
   TSEC=$(( (END_TIME-START_TIME) % 60 ));

   # PRINT SUCCESS
   echo -e "";
   echo -e ${GRN} "*****************************************************" ${TXTRST};
   echo -e ${GRN} "     ______                      __     __       __  " ${TXTRST};
   echo -e ${GRN} "    / ____/___  ____ ___  ____  / /__  / /____  / /  " ${TXTRST};
   echo -e ${GRN} "   / /   / __ \/ __ '__ \/ __ \/ / _ \/ __/ _ \/ /   " ${TXTRST};
   echo -e ${GRN} "  / /___/ /_/ / / / / / / /_/ / /  __/ /_/  __/_/    " ${TXTRST};
   echo -e ${GRN} "  \____/\____/_/ /_/ /_/ .___/_/\___/\__/\___(_)     " ${TXTRST};
   echo -e ${GRN} "                      /_/                            " ${TXTRST};
   echo -e ${GRN} "                                                     " ${TXTRST};
   echo -e ${GRN} "       Clang ${VERSION} has compiled successfully!   " ${TXTRST};
   echo -e ${GRN} "*****************************************************" ${TXTRST};
   echo -e  "";
   echo -e ${BLDGRN}"Total time elapsed:${TXTRST} ${GRN}${TMIN} minutes ${TSEC} seconds"${TXTRST};
   echo -e ${BLDGRN}"Toolchain located at:${TXTRST} ${GRN}${INSTALL_DIR}"${TXTRST};
fi;

# UNSET VARIABLES USED
unset TOOLCHAIN_ROOT;
unset PREFIX_PATH;
unset OPT;
unset LOCAL_CXX_FLAGS;
unset LOCAL_C_FLAGS;
unset CC;
unset CXX;
unset LD;

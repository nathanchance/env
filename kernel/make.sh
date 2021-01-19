#!/usr/bin/env bash

function die() {
    printf '\n%b%s%b\n\n' "\033[01;31m" "${1}" "\033[0m"
    exit "${2}"
}

function parse_parameters() {
    MAKE_ARGS=()
    while ((${#})); do
        case ${1} in
            NO_CCACHE=*)
                export "${1?}"
                ;;

            *=*)
                if [[ ${1} =~ CC= ]]; then
                    CC_WAS_IN_ARGS=true
                else
                    MAKE_ARGS+=("${1}")
                fi
                export "${1?}"
                ;;

            */ | *.i | *.ko | *.o | *.s | all | *clean | *config | *docs | dtbs | *_install | *Image* | modules | mrproper | vmlinux)
                MAKE_ARGS+=("${1}")
                ;;

            -C)
                MAKE_ARGS+=("${1}" "${2}")
                shift
                ;;

            +s)
                SILENT=false
                ;;
        esac
        shift
    done
}

function setup_paths() {
    if [[ ${LLVM} -eq 1 || ${CC} = "clang" ]]; then
        case "$(id -un)@$(uname -n)" in
            nathan@ubuntu-*) TC_FOLDER=${CBL_LLVM_BNTL} ;;
            nathan@Ryzen-5-4500U | nathan@Ryzen-9-3900X) TC_FOLDER=${HOME}/toolchains/cbl/llvm-binutils/bin ;;
        esac
        export PATH=${TC_FOLDER}:${PATH}
        # In case CC is not specified (e.g. LLVM=1)
        [[ -z ${CC} ]] && CC=clang
    else
        export PATH=${GCC_TC_FOLDER}/10.2.0/bin:${PATH}
        [[ -z ${CC} ]] && CC=${CROSS_COMPILE}gcc
    fi

    # Account for PATH override variable
    export PATH=${PO:+${PO}:}${PATH}

    CC_NAME=${CC##* }
    CC_PATH=$(command -v "${CC_NAME}")
    [[ -x ${CC_PATH} ]] || die "${CC_NAME} could not be found or it is not executable!" "${?}"

    CC_LOCATION=${CC_PATH%/*}
    printf '\n\e[01;32mCompiler location:\e[0m %s\n\n' "${CC_LOCATION}"
    printf '\e[01;32mCompiler version:\e[0m %s \n\n' "$("${CC_PATH}" --version | head -n1)"
    if [[ ${LLVM_IAS} -ne 1 ]]; then
        AS_PATH=$(command -v "${CROSS_COMPILE}"as)
        [[ -x ${AS_PATH} ]] || die "binutils could not be found or they are not executable!" "${?}"
        AS_LOCATION=${AS_PATH%/*}
        [[ "${AS_LOCATION}" = "${CC_LOCATION}" ]] || printf '\e[01;32mBinutils location:\e[0m %s\n\n' "${AS_LOCATION}"
        printf '\e[01;32mBinutils version:\e[0m %s \n\n' "$("${AS_PATH}" --version | head -n1)"
    fi
}

function invoke_make() {
    [[ ${V} -eq 1 || ${V} -eq 2 ]] && SILENT=false
    ${SILENT:=true} && SILENT_MAKE_FLAG=s

    if ${FORCE_LE:-true}; then
        case ${ARCH} in
            arm | arm64) [[ ${MAKE_ARGS[*]} =~ allmodconfig || ${MAKE_ARGS[*]} =~ allyesconfig ]] && FORCE_LE=true ;;
        esac
    else
        unset FORCE_LE
    fi

    if command -v ccache &>/dev/null && [[ -z ${NO_CCACHE} ]]; then
        CCACHE="ccache "
    else
        unset CCACHE
        [[ -n ${CC} ]] && ${CC_WAS_IN_ARGS:=false} && MAKE_ARGS+=("CC=${CC}")
    fi

    set -x
    time make -"${SILENT_MAKE_FLAG}"kj"$(nproc)" ${CCACHE:+CC="${CCACHE}${CC}"} "${MAKE_ARGS[@]}" ${FORCE_LE:+KCONFIG_ALLCONFIG=<(echo CONFIG_CPU_BIG_ENDIAN=n)}
}

parse_parameters "${@}"
setup_paths
invoke_make

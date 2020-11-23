#!/usr/bin/env bash

function parse_parameters() {
    MAKE_ARGS=()
    while ((${#})); do
        case ${1} in
            *=*)
                MAKE_ARGS+=("${1}")
                export "${1?}"
                ;;

            */ | *.i | *.ko | *.o | all | *clean | *config | dtbs | *_install | *Image* | modules | vmlinux)
                MAKE_ARGS+=("${1}")
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

    printf '\n\e[01;32mToolchain location:\e[0m %s\n\n' "$(dirname "$(command -v "${CC##* }")")"
    printf '\e[01;32mToolchain version:\e[0m %s \n\n' "$("${CC##* }" --version | head -n1)"
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

    set -x
    time make -"${SILENT_MAKE_FLAG}"kj"$(nproc)" "${MAKE_ARGS[@]}" ${FORCE_LE:+KCONFIG_ALLCONFIG=<(echo CONFIG_CPU_BIG_ENDIAN=n)}
}

parse_parameters "${@}"
setup_paths
invoke_make

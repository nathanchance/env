#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2018 Nathan Chancellor
#
# android-linux-stable management script


# Static logging function
function log() {
    if [[ -n ${LOGGING} ]]; then
        echo "${@}" >> "${LOG}"
    fi
}

# Quick kernel version function
function kv() {
    make CROSS_COMPILE="" kernelversion
}

# Steps to execute post 'git fm'
function post_git_fm_steps() {
    # Log our success
    log "${LOG_TAG} ${1}"
    # Don't push if we're just testing
    [[ -z ${NO_PUSH} ]] && git push
    # Make sure SKIP_BUILD gets unset
    unset SKIP_BUILD
}

# Steps to execute if merge failed
function failed_steps() {
    # Abort merge
    git ma
    # Reset back to origin
    git rh "origin/${BRANCH}"
    # Skip building if requested
    SKIP_BUILD=true
}

# Conflict commands
function post_merge_commands() {
    local FIRST_STATEMENT SECOND_STATEMENT THIRD_STATEMENT
    if [[ ${1} = "-s" ]]; then
        FIRST_STATEMENT="Post merge steps successfully executed"
        SECOND_STATEMENT="Post merge steps failed"
    else
        FIRST_STATEMENT="Merge failed but resolution was successful: $(kv)"
        SECOND_STATEMENT="Merge failed, even after attempting resolution!"
        THIRD_STATEMENT="Resolution was requested but no resolution file was found"
    fi

    # Get the appropriate resolution command filename (static mapping because it is not uniform)
    case "${REPO}:${BRANCH}" in
        "jasmine"*|"marlin"*|"msm"*|"polaris"*|"sagit"*|"tissot"*|"wahoo"*|"whyred"*) COMMANDS="${REPO}-commands" ;;
        "nash"*) COMMANDS="nash-oreo-8.0.0-commands" ;;
        "op3:oneplus/QC8996_O_8.0.0") COMMANDS="${REPO}-8.0.0-commands" ;;
        "op5:oneplus/QC8998_O_8.1"|"op6:oneplus/SDM845_O_8.1") COMMANDS="${REPO}-O_8.1-commands" ;;
        "op6:oneplus/SDM845_P_9.0_Beta") COMMANDS="${REPO}-P_9.0_Beta-commands" ;;
        "op5:oneplus/QC8998_O_8.1_Beta") COMMANDS="${REPO}-O_8.1_Beta-commands" ;;
        "op"*) COMMANDS="${REPO}-${BRANCH}-commands" ;;
    esac

    # If it is found, execute it
    COMMANDS=${REPO_FOLDER}/sp/${KVER}/${COMMANDS}
    if [[ -f ${COMMANDS} ]]; then
        if bash "${COMMANDS}" "${COMMANDS_BRANCH}"; then
            # Log success then push
            post_git_fm_steps "${FIRST_STATEMENT}"
        else
            # Log success and conflicts
            log "${LOG_TAG} ${SECOND_STATEMENT}"
            log "${LOG_TAG} Conflicts:"
            log "$(git cf)"
            failed_steps
        fi
    # If no command file was found and it was a failed merge, log failure
    elif [[ -n ${THIRD_STATEMENT} ]]; then
        log "${LOG_TAG} Resolution was requested but no resolution file was found!"
    fi
}

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" || return; pwd)/common"
source "${SCRIPTS_FOLDER}"/snippets/bk
source "${SCRIPTS_FOLDER}"/snippets/deldog
trap 'echo; die "Manually aborted!"' SIGINT SIGTERM

# Variables
ALS=${KERNEL_FOLDER}/als
REPOS_318=( "marlin" "msm-3.18" "op3" "tissot" )
REPOS_44=( "jasmine" "msm-4.4" "nash" "op5" "sagit" "wahoo" "whyred" )
REPOS_49=( "msm-4.9" "op6" "polaris" )

# Parse parameters
PARAMS="${*}"
while [[ ${#} -ge 1 ]]; do
    case ${1} in
        # Build after merging
        "-b"|"--build")
            BUILD=true ;;

        # Don't resolve conflicts
        "-d"|"--dry-run")
            DRY_RUN=true ;;

        "-i"|"--initialize")
            INIT=true ;;

        # Log merge and build results
        "-l"|"--log")
            LOGGING=true ;;

        # Merge from stable-queue
        "-q"|"--queue")
            ALS_PARAMS+=( "-q" )
            NO_PUSH=true
            QUEUE=true ;;

        # Subset of repos (implies -v has been set)
        "-R"|"--repos")
            shift && enforce_value "${@}"
            read -r -a REPOS_PARAM <<< "${1}" ;;

        # Merge from linux-stable-rc
        "-r"|"--release-candidate")
            ALS_PARAMS+=( "-r" )
            NO_PUSH=true
            RC=true ;;

        # Versions to merge, separated by commas
        "-v"|"--versions")
            shift && enforce_value "${@}"
            # SC2076: Don't quote rhs of =~, it'll match literally rather than as a regex.
            # shellcheck disable=SC2076
            [[ ${1} =~ "3.18" || ${1} =~ "4.4" || ${1} =~ "4.9" ]] || die "Invalid version specified!"
            IFS="," read -r -a VERSIONS <<< "${1}" ;;
    esac
    shift
done

# If no versions were specified, assume we want all
[[ -z ${VERSIONS} ]] && VERSIONS=( "3.18" "4.4" "4.9" )

# Start with a clean log
[[ -n ${LOGGING} ]] && rm -rf "${LOG}"

# If initialization was requested
if [[ -n ${INIT} ]]; then
    mkdir -p "${ALS}"; cd "${ALS}" || die "${ALS} creation failed!"

    for ITEM in "${REPOS_318[@]}" "${REPOS_44[@]}" "${REPOS_49[@]}"; do
        git clone "git@github.com:android-linux-stable/${ITEM}.git" || die "Could not clone ${ITEM}!"
        case ${ITEM} in
            "jasmine"|"polaris"|"sagit"|"tissot"|"whyred")
                REMOTES=( "upstream:https://github.com/MiCode/Xiaomi_Kernel_OpenSource" ) ;;
            "marlin"|"wahoo")
                REMOTES=( "upstream:https://android.googlesource.com/kernel/msm" ) ;;
            "msm-3.18"|"msm-4.4"|"msm-4.9")
                REMOTES=( "upstream:https://source.codeaurora.org/quic/la/kernel/${ITEM}" ) ;;
            "nash")
                REMOTES=( "upstream:https://github.com/MotorolaMobilityLLC/kernel-msm" ) ;;
            "op3")
                REMOTES=( "LineageOS:https://github.com/LineageOS/android_kernel_oneplus_msm8996"
                          "omni:https://github.com/omnirom/android_kernel_oneplus_msm8996"
                          "upstream:https://github.com/OnePlusOSS/android_kernel_oneplus_msm8996" ) ;;
            "op5")
                REMOTES=( "LineageOS:https://github.com/LineageOS/android_kernel_oneplus_msm8998"
                          "omni:https://github.com/omnirom/android_kernel_oneplus_msm8998"
                          "upstream:https://github.com/OnePlusOSS/android_kernel_oneplus_msm8998" ) ;;
            "op6")
                REMOTES=( "LineageOS:https://github.com/LineageOS/android_kernel_oneplus_sdm845"
                          "omni:https://github.com/omnirom/android_kernel_oneplus_sdm845"
                          "upstream:https://github.com/OnePlusOSS/android_kernel_oneplus_sdm845" ) ;;
        esac
        for REMOTE in "${REMOTES[@]}"; do
            git -C "${ITEM}" remote add "${REMOTE%%:*}" "${REMOTE#*:}"
        done
        git -C "${ITEM}" remote update
    done
fi

# Iterate through all versions
for VERSION in "${VERSIONS[@]}"; do
    # Set up repos variable based on version if REPOS is not set
    if [[ -z "${REPOS_PARAM[*]}" ]]; then
        case ${VERSION} in
            "3.18") REPOS=( "${REPOS_318[@]}" ) ;;
            "4.4") REPOS=( "${REPOS_44[@]}" ) ;;
            "4.9") REPOS=( "${REPOS_49[@]}" ) ;;
        esac
    else
        REPOS=( "${REPOS_PARAM[@]}" )
    fi

    # Iterate through the repos
    for REPO in "${REPOS[@]}"; do
        # Map all of the branches of the repo to an upstream remote (if relevant)
        case ${REPO} in
            "jasmine") BRANCHES=( "jasmine-o-oss" ) ;;
            "marlin") BRANCHES=( "android-msm-marlin-3.18" ) ;;
            "msm-3.18") BRANCHES=( "kernel.lnx.3.18.r33-rel" "kernel.lnx.3.18.r34-rel" ) ;;
            "msm-4.4") BRANCHES=( "kernel.lnx.4.4.r27-rel" "kernel.lnx.4.4.r34-rel" "kernel.lnx.4.4.r35-rel" ) ;;
            "msm-4.9") BRANCHES=( "kernel.lnx.4.9.r7-rel" ) ;;
            "nash") BRANCHES=( "oreo-8.0.0-release-nash:upstream" ) ;;
            "op3") BRANCHES=( "android-8.1:omni" "lineage-15.1:LineageOS" "oneplus/QC8996_O_8.0.0:upstream" ) ;;
            "op5") BRANCHES=( "android-8.1:omni" "lineage-15.1" "oneplus/QC8998_O_8.1:upstream" "oneplus/QC8998_O_8.1_Beta:upstream" ) ;;
            "op6") BRANCHES=( "android-9.0:omni" "lineage-15.1:LineageOS" "oneplus/SDM845_O_8.1:upstream" "oneplus/SDM845_P_9.0_Beta:upstream" ) ;;
            "polaris") BRANCHES=( "polaris-o-oss:upstream" ) ;;
            "sagit") BRANCHES=( "sagit-o-oss:upstream" ) ;;
            "tissot") BRANCHES=( "tissot-o-oss-8.1:upstream" ) ;;
            "wahoo") BRANCHES=( "android-msm-wahoo-4.4" ) ;;
            "whyred") BRANCHES=( "whyred-o-oss:upstream" ) ;;
        esac

        # Move into the repo, unless it doesn't exist
        if ! cd "${ALS}/${REPO}"; then
            warn "${ALS}/${REPO} doesn't exist, skipping!"
            log "${REPO}: Skipped\n"
            continue
        fi

        # Iterate through all branches
        for BRANCH in "${BRANCHES[@]}"; do
            REMOTE=${BRANCH##*:}
            BRANCH=${BRANCH%%:*}
            LOG_TAG="${REPO} | ${BRANCH} |"

            header "${REPO} - ${BRANCH}"

            # Checkout the branch
            git ma 2>/dev/null
            git rh 2>/dev/null
            if ! git ch "${BRANCH}"; then
                # If we get an error, it's because git can't resolve which branch we want
                git ch -b "${BRANCH}" "origin/${BRANCH}" || die "Branch doesn't exist!"
            fi

            # Make sure we have a clean tree
            git fetch origin
            git rh "origin/${BRANCH}"

            # If there is an upstream remote (REMOTE and BRANCH aren't the same), merge it if the main merge is not an RC or queue merge
            if [[ "${REMOTE}" != "${BRANCH}" && -z "${ALS_PARAMS[*]}" ]]; then
                git fetch "${REMOTE}"
                git ml --no-edit "${REMOTE}/${BRANCH}" || die "${LOG_TAG} ${REMOTE}/${BRANCH} merge error! Please resolve then re-run the script!"
            fi

            # Cache kernel version. This needs to be done before doing a merge in case Makefile conflicts...
            KVER=$(kv)
            MAJOR_VER=${KVER%.*}
            if [[ -n ${QUEUE} ]]; then
                COMMANDS_BRANCH=MERGE_HEAD
                LOG_TAG="${LOG_TAG} stable-queue/queue-${MAJOR_VER} |"
            else
                COMMANDS_BRANCH=linux-stable${RC:+"-rc"}/linux-${MAJOR_VER}.y
                LOG_TAG="${LOG_TAG} ${COMMANDS_BRANCH} |"
            fi

            # Merge the update, logging success and pushing as necessary
            if merge-stable "${ALS_PARAMS[@]}"; then
                # Show merged kernel version in log
                post_git_fm_steps "Merge successful: $(kv)"

                # Properly set KVER for post merge commands
                if [[ -n ${QUEUE} ]]; then
                    KVER=${MAJOR_VER}.$((${KVER##*.} + 1))
                elif [[ -n ${RC} ]]; then
                    KVER=$(kv | sed 's/-rc.*//')
                else
                    KVER=$(kv)
                fi

                # If a command file is found, execute it
                post_merge_commands -s
            else
                # Resolve if requested
                if [[ -z ${DRY_RUN} ]]; then
                    # Set KVER to be one version ahead of current version
                    KVER=${MAJOR_VER}.$((${KVER##*.} + 1))

                    # Attempt resolution
                    post_merge_commands

                # Log failure otherwise
                else
                    log "${LOG_TAG} Merge failed!"
                    log "${LOG_TAG} Conflicts:"
                    log "$(git cf)"
                    failed_steps
                fi
            fi

            # Build if requested and not Nash
            if [[ -n ${BUILD} && -z ${SKIP_BUILD} ]]; then
                # msm-3.18 has two defconfigs to build: msm-perf_defconfig and msm8937-perf_defconfig
                [[ ${REPO} = "msm-3.18" ]] && BK_COMMANDS=( "bk" "bk -d msm8937-perf_defconfig" ) || BK_COMMANDS=( "bk" )

                for BK_COMMAND in "${BK_COMMANDS[@]}"; do
                    if ${BK_COMMAND}; then
                        # Show kernel version in log
                        log "${LOG_TAG} Build successful: $(kv)$(cd out || return; ../scripts/setlocalversion ..)"
                    else
                        # Add command for quick reproduction of build failure
                        log "${LOG_TAG} Build failed: ( cd ${ALS}/${REPO}; ${BK_COMMAND} )"
                    fi
                done
            fi
            log
        done
    done
    log; log; log
done

if [[ -n ${LOGGING} ]]; then
    URL=$(deldog "${LOG}")

    clear
    echo
    echo "${BOLD}ALS merge results:${RST} ${URL}"
    echo
    tg_msg "ALS merge results (\`$(basename "${0}") ${PARAMS}\`): ${URL}"
fi

exit 0

#!/bin/sh
# shellcheck disable=SC2046,SC2086
# SPDX-License-Identifier: GPL-2.0
#
# Print the compiler name and its version in a 5 or 6-digit form.
# Also, perform the minimum version check.

set -e

# Print the compiler name and some version components.
get_compiler_info() {
    cat <<-EOF | "$@" -E -P -x c - 2>/dev/null
	#if defined(__clang__)
	Clang	__clang_major__  __clang_minor__  __clang_patchlevel__
	#elif defined(__INTEL_COMPILER)
	ICC	__INTEL_COMPILER  __INTEL_COMPILER_UPDATE
	#elif defined(__GNUC__)
	GCC	__GNUC__  __GNUC_MINOR__  __GNUC_PATCHLEVEL__
	#else
	unknown
	#endif
	EOF
}

# Convert the version string x.y.z to a canonical 5 or 6-digit form.
get_canonical_version() {
    IFS=.
    set -- $1
    echo $((10000 * $1 + 100 * $2 + $3))
}

# $@ instead of $1 because multiple words might be given, e.g. CC="ccache gcc".
orig_args="$*"
set -- $(get_compiler_info "$@")

name=$1

case "$name" in
    GCC)
        version=$2.$3.$4
        ;;
    Clang)
        version=$2.$3.$4
        ;;
    ICC)
        version=$(($2 / 100)).$(($2 % 100)).$3
        ;;
    *)
        echo "$orig_args: unknown compiler" >&2
        exit 1
        ;;
esac

get_canonical_version $version

#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

import subprocess


def get_glibc_version():
    ldd_version_out = subprocess.run(['ldd', '--version'],
                                     capture_output=True,
                                     check=True,
                                     text=True).stdout
    ldd_version = ldd_version_out.split('\n')[0].split(' ')[-1].split('.')
    if len(ldd_version) < 3:
        ldd_version += [0]
    return tuple(int(x) for x in ldd_version)


if __name__ == '__main__':
    glibc_version = get_glibc_version()
    print(f"{glibc_version[0]:d}{glibc_version[1]:02d}{glibc_version[2]:02d}")

#!/usr/bin/env python3

import subprocess

if __name__ == '__main__':
    ldd_version_out = subprocess.run(['ldd', '--version'],
                                     capture_output=True,
                                     check=True,
                                     text=True).stdout
    ldd_version = ldd_version_out.split('\n')[0].split(' ')[-1].split('.')
    if len(ldd_version) < 3:
        ldd_version += [0]
    ldd_version = [int(x) for x in ldd_version]
    print(f'{ldd_version[0]:d}{ldd_version[1]:02d}{ldd_version[2]:02d}')

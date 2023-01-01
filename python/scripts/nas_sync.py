#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

from argparse import ArgumentParser
import datetime
import json
import os
from pathlib import Path
import sys

import requests

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.sha256  # noqa: E402
import lib.utils  # noqa: E402
# pylint: enable=wrong-import-position


def parse_parameters():
    parser = ArgumentParser(description='Download certain firmare images to NAS')

    supported_images = [
        'alpine',
        'arch',
        'debian',
        'fedora',
        'ipsw',
        'korg',
        'rpios',
        'ubuntu'
    ]  # yapf: disable

    parser.add_argument('-t',
                        '--targets',
                        choices=supported_images,
                        default=supported_images,
                        help='Download targets',
                        nargs='+')

    return parser.parse_args()


def get_most_recent_sunday():
    today = datetime.date.today()
    sunday_offset = (today.weekday() + 1) % 7
    return today - datetime.timedelta(sunday_offset)


def get_sunday_as_folder():
    return get_most_recent_sunday().strftime('%Y-%m-%d')


def get_latest_ipsw_url(identifier, version):
    # Query the endpoint for list of builds
    response = requests.get(f"https://api.ipsw.me/v4/device/{identifier}?type=ipsw",
                            params={'Accept': 'application/json'},
                            timeout=3600)
    response.raise_for_status()
    firmwares = json.loads(response.content)['firmwares']
    # Eliminate builds that are not for the requested versions
    version_firmwares = [item for item in firmwares if item['version'].split('.')[0] == version]
    # The first item is the newest, which is really all we care about
    return version_firmwares[0]['url']


def download_if_necessary(item):
    base_file = item['base_file'] if 'base_file' in item else item['file_url'].split('/')[-1]
    target = Path(item['containing_folder'], base_file)
    target.parent.mkdir(exist_ok=True, parents=True)
    if target.exists():
        lib.utils.print_yellow(f"SKIP: {base_file} already downloaded!")
    else:
        lib.utils.print_green(f"INFO: {base_file} downloading...")
        response = requests.get(item['file_url'], timeout=3600)
        response.raise_for_status()
        target.write_bytes(response.content)

    if 'sha_url' in item:
        lib.sha256.validate_from_url(target, item['sha_url'])


def update_bundle_symlink(bundle_folder):
    src = Path(bundle_folder, get_sunday_as_folder())
    dest = Path(bundle_folder, 'latest')

    dest.unlink(missing_ok=True)
    dest.symlink_to(src)


def download_items(targets, network_folder):
    if not (firmware_folder := Path(network_folder, 'Firmware_and_Images')).exists():
        raise Exception(f"{firmware_folder} does not exist, systemd automounting broken?")

    if not (bundle_folder := Path(network_folder, 'kernel.org/bundles')).exists():
        raise Exception(f"{bundle_folder} does not exist??")

    items = []
    for target in targets:
        if target == 'alpine':
            alpine_arches = ['aarch64', 'armv7', 'x86', 'x86_64']
            alpine_series = '3.17'
            alpine_patch = '.0'
            alpine_version = alpine_series + alpine_patch

            for alpine_arch in alpine_arches:
                for img_type in ['standard', 'virt']:
                    file_url = f"https://dl-cdn.alpinelinux.org/alpine/v{alpine_series}/releases/{alpine_arch}/alpine-{img_type}-{alpine_version}-{alpine_arch}.iso"
                    items += [{
                        'containing_folder': Path(firmware_folder, 'Alpine', alpine_version),
                        'file_url': file_url,
                        'sha_url': file_url + '.sha256',
                    }]  # yapf: disable

        elif target == 'arch':
            arch_day = '.01'
            arch_date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y.%m") + arch_day

            base_arch_url = f"https://mirrors.edge.kernel.org/archlinux/iso/{arch_date}"
            items += [{
                'containing_folder': Path(firmware_folder, 'Arch', arch_date),
                'file_url': f"{base_arch_url}/archlinux-{arch_date}-x86_64.iso",
                'sha_url': f"{base_arch_url}/sha256sums.txt"
            }]

        elif target == 'debian':
            debian_arches = ['amd64', 'arm64', 'armhf', 'i386']
            debian_ver = '11.6.0'

            for arch in debian_arches:
                arch_debian_folder = Path(firmware_folder, target.capitalize(), debian_ver, arch)
                arch_debian_url = f"https://cdimage.debian.org/debian-cd/current/{arch}"
                items += [
                    {
                        'containing_folder': arch_debian_folder,
                        'file_url': f"{arch_debian_url}/iso-cd/debian-{debian_ver}-{arch}-netinst.iso",
                        'sha_url': f"{arch_debian_url}/iso-cd/SHA256SUMS"
                    },
                    {
                        'containing_folder': arch_debian_folder,
                        'file_url': f"{arch_debian_url}/iso-dvd/debian-{debian_ver}-{arch}-DVD-1.iso",
                        'sha_url': f"{arch_debian_url}/iso-dvd/SHA256SUMS"
                    }
                ]  # yapf: disable

        elif target == 'fedora':
            fedora_arches = ['aarch64', 'x86_64']
            subfolder = Path(firmware_folder, target.capitalize())

            # Constants to update
            fedora_ver = '37'
            server_iso_ver = '1.7'
            workstation_iso_ver = '1.7'

            # Base URLs
            base_fedora_file_url = f"https://download.fedoraproject.org/pub/fedora/linux/releases/{fedora_ver}"
            base_fedora_checksum_url = f"https://getfedora.org/static/checksums/{fedora_ver}/iso/"

            # Server
            for arch in fedora_arches:
                for flavor in ['dvd', 'netinst']:
                    items += [{
                        'containing_folder': Path(subfolder, fedora_ver, 'Server', arch),
                        'file_url': f"{base_fedora_file_url}/Server/{arch}/iso/Fedora-Server-{flavor}-{arch}-{fedora_ver}-{server_iso_ver}.iso",
                        'sha_url': f"{base_fedora_checksum_url}/Fedora-Server-{fedora_ver}-{server_iso_ver}-{arch}-CHECKSUM"
                    }]  # yapf: disable

            # Workstation
            for arch in fedora_arches:
                items += [{
                    'containing_folder': Path(subfolder, fedora_ver, 'Workstation', arch),
                    'file_url': f"{base_fedora_file_url}/Workstation/{arch}/iso/Fedora-Workstation-Live-{arch}-{fedora_ver}-{workstation_iso_ver}.iso",
                    'sha_url': f"{base_fedora_checksum_url}/Fedora-Workstation-{fedora_ver}-{server_iso_ver}-{arch}-CHECKSUM"
                }]  # yapf: disable

        elif target == 'ipsw':
            mac_versions = ['13', '12']

            for mac_version in mac_versions:
                items += [{
                    'containing_folder': Path(firmware_folder, 'macOS/VM'),
                    'file_url': get_latest_ipsw_url('VirtualMac2,1', mac_version)
                }]

        elif target == 'korg':
            repos = [('torvalds/linux', 'linux'), ('next/linux-next', 'linux-next'),
                     ('stable/linux', 'linux-stable')]

            for repo in repos:
                repo_remote = repo[0]
                repo_local = repo[1]

                base_korg_bundle_url = f"https://mirrors.kernel.org/pub/scm/.bundles/pub/scm/linux/kernel/git/{repo_remote}"
                clone_bundle = 'clone.bundle'
                items += [{
                    'base_file': f"{clone_bundle}-{repo_local}",
                    'containing_folder': Path(bundle_folder, get_sunday_as_folder()),
                    'file_url': f"{base_korg_bundle_url}/{clone_bundle}",
                    'sha_url': f"{base_korg_bundle_url}/sha256sums.asc"
                }]

        elif target == 'rpios':
            rpi_arches = ['armhf', 'arm64']
            rpi_date = '2022-09-26/2022-09-22'
            deb_ver = 'bullseye'

            for rpi_arch in rpi_arches:
                base_rpi_url = f"https://downloads.raspberrypi.org/raspios_lite_{rpi_arch}/images/raspios_lite_{rpi_arch}-{rpi_date}-raspios-{deb_ver}-{rpi_arch}-lite.img.xz"
                items += [{
                    'containing_folder': Path(firmware_folder, 'Raspberry Pi OS'),
                    'file_url': base_rpi_url,
                    'sha_url': base_rpi_url + '.sha256'
                }]

        elif target == 'ubuntu':
            ubuntu_arches = ['amd64', 'arm64']
            ubuntu_vers = ['22.04', '22.10']

            for ubuntu_ver in ubuntu_vers:
                if ubuntu_ver == '22.04':
                    ubuntu_subver = ubuntu_ver + '.1'
                else:
                    ubuntu_subver = ubuntu_ver

                for arch in ubuntu_arches:
                    if arch == 'amd64':
                        base_ubuntu_url = f"https://releases.ubuntu.com/{ubuntu_subver}"
                    elif arch == 'arm64':
                        base_ubuntu_url = f"https://cdimage.ubuntu.com/releases/{ubuntu_ver}/release"

                    items += [{
                        'containing_folder': Path(firmware_folder, 'Ubuntu', ubuntu_ver, 'Server'),
                        'file_url': f"{base_ubuntu_url}/ubuntu-{ubuntu_subver}-live-server-{arch}.iso",
                        'sha_url': f"{base_ubuntu_url}/SHA256SUMS"
                    }]    # yapf: disable

    for item in items:
        download_if_necessary(item)
    if 'korg' in targets:
        update_bundle_symlink(bundle_folder)


if __name__ == '__main__':
    args = parse_parameters()

    if not (nas_folder := Path(os.environ['NAS_FOLDER'])).exists():
        raise Exception(f"{nas_folder} does not exist, setup systemd automount files?")

    download_items(args.targets, nas_folder)

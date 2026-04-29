#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "requests>=2.32.5",
# ]
# ///

# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import datetime
import json
import os
import sys
from argparse import ArgumentParser
from pathlib import Path

import requests

sys.path.append(str(Path(__file__).resolve().parents[1]))
import lib.sha256
import lib.utils


class DownloadItem:
    def __init__(self) -> None:
        self.base_file: str = ''
        self.file_url: str = ''
        self.containing_folder: Path | None = None
        self.sha_url: str = ''

    def download_if_necessary(self) -> None:
        if not self.containing_folder:
            msg = 'Containing folder not configured?'
            raise RuntimeError(msg)
        if not self.file_url:
            msg = 'File URL not configured?'
            raise RuntimeError(msg)
        if not self.base_file:
            self.base_file = self.file_url.rsplit('/', 1)[-1]

        if (target := Path(self.containing_folder, self.base_file)).exists():
            lib.utils.print_yellow(f"SKIP: {self.base_file} already downloaded!")
        else:
            target.parent.mkdir(exist_ok=True, parents=True)
            lib.utils.print_green(f"INFO: {self.base_file} downloading...")
            response = requests.get(self.file_url, timeout=3600)
            response.raise_for_status()
            target.write_bytes(response.content)

        if self.sha_url:
            lib.sha256.validate_from_url(target, self.sha_url)


def parse_parameters():
    parser = ArgumentParser(description='Download certain firmare images to NAS')

    supported_images = [
        'alpine',
        'arch',
        'bundles',
        'debian',
        'fedora',
        'ipsw',
        'ubuntu',
    ]  # fmt: off

    parser.add_argument(
        '-t',
        '--targets',
        choices=supported_images,
        default=supported_images,
        help='Download targets',
        nargs='+',
    )

    return parser.parse_args()


def get_latest_ipsw_url(identifier: str, version: str) -> str:
    # Query the endpoint for list of builds
    response = requests.get(
        f"https://api.ipsw.me/v4/device/{identifier}?type=ipsw",
        params={'Accept': 'application/json'},
        timeout=3600,
    )
    response.raise_for_status()
    firmwares = json.loads(response.content)['firmwares']
    # Eliminate builds that are not for the requested versions
    version_firmwares = [item for item in firmwares if item['version'].split('.')[0] == version]
    # The first item is the newest, which is really all we care about
    return version_firmwares[0]['url']


def download_items(targets: list[str], network_folder: Path) -> None:
    if not (firmware_folder := Path(network_folder, 'Firmware_and_Images')).exists():
        msg = f"{firmware_folder} does not exist, systemd automounting broken?"
        raise RuntimeError(msg)

    if not (bundles_folder := Path(network_folder, 'bundles')).exists():
        msg = f"{bundles_folder} does not exist??"
        raise RuntimeError(msg)

    items: list[DownloadItem] = []
    for target in targets:
        if target == 'alpine':
            alpine_arches = ['aarch64', 'armv7', 'x86', 'x86_64']
            alpine_series = '3.20'
            alpine_patch = '.3'
            alpine_version = alpine_series + alpine_patch

            for alpine_arch in alpine_arches:
                for img_type in ['standard', 'virt']:
                    file_url = f"https://dl-cdn.alpinelinux.org/alpine/v{alpine_series}/releases/{alpine_arch}/alpine-{img_type}-{alpine_version}-{alpine_arch}.iso"
                    item = DownloadItem()
                    item.containing_folder = Path(firmware_folder, 'Alpine', alpine_version)
                    item.file_url = file_url
                    item.sha_url = file_url + '.sha256'
                    items.append(item)

        elif target == 'arch':
            arch_day = '.01'
            arch_date = datetime.datetime.now(datetime.UTC).strftime("%Y.%m") + arch_day

            base_arch_url = f"https://mirrors.edge.kernel.org/archlinux/iso/{arch_date}"
            item = DownloadItem()
            item.containing_folder = Path(firmware_folder, 'Arch')
            item.file_url = f"{base_arch_url}/archlinux-{arch_date}-x86_64.iso"
            item.sha_url = f"{base_arch_url}/sha256sums.txt"
            items.append(item)

        elif target == 'bundles':
            repos: dict[str, str] = {
                'binutils': 'https://sourceware.org/git/binutils-gdb.git',
                'linux': 'https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/',
                'linux-next': 'https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/',
                'linux-stable': 'https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/',
                'llvm-project': 'https://github.com/llvm/llvm-project',
            }
            for repo_name, repo_url in repos.items():
                # Download and update repo
                if not (repo_path := Path(os.environ['CBL_SRC_M'], repo_name)).exists():
                    repo_path.parent.mkdir(exist_ok=True, parents=True)
                    lib.utils.call_git_loud(None, ['clone', '--mirror', repo_url, repo_path])
                lib.utils.call_git_loud(repo_path, ['remote', 'update', '--prune'])
                # Create bundles
                repo_bundle = Path(bundles_folder, f"{repo_name}.bundle")
                repo_bundle.unlink(missing_ok=True)
                lib.utils.call_git_loud(repo_path, ['bundle', 'create', repo_bundle, '--all'])

        elif target == 'debian':
            debian_arches = ['amd64', 'arm64', 'armhf']
            debian_ver = '13.0.0'

            for arch in debian_arches:
                arch_debian_folder = Path(firmware_folder, target.capitalize(), debian_ver, arch)
                arch_debian_url = f"https://cdimage.debian.org/debian-cd/current/{arch}"

                netinst_item = DownloadItem()
                netinst_item.containing_folder = arch_debian_folder
                netinst_item.file_url = (
                    f"{arch_debian_url}/iso-cd/debian-{debian_ver}-{arch}-netinst.iso"
                )
                netinst_item.sha_url = f"{arch_debian_url}/iso-cd/SHA256SUMS"

                dvd_item = DownloadItem()
                dvd_item.containing_folder = arch_debian_folder
                dvd_item.file_url = (
                    f"{arch_debian_url}/iso-dvd/debian-{debian_ver}-{arch}-DVD-1.iso"
                )
                dvd_item.sha_url = f"{arch_debian_url}/iso-dvd/SHA256SUMS"

                items += [netinst_item, dvd_item]

        elif target == 'fedora':
            fedora_arches = ['aarch64', 'x86_64']
            subfolder = Path(firmware_folder, target.capitalize())

            # Constants to update
            fedora_ver = '44'
            server_iso_ver = '1.7'
            workstation_iso_ver = '1.7'

            # Base URLs
            base_fedora_url = f"https://mirrors.edge.kernel.org/fedora/releases/{'test/' if '_Beta' in fedora_ver else ''}{fedora_ver}"

            # Server
            for arch in fedora_arches:
                iso_url = f"{base_fedora_url}/Server/{arch}/iso"
                for flavor in ['dvd', 'netinst']:
                    item = DownloadItem()
                    item.containing_folder = Path(subfolder, fedora_ver, 'Server', arch)
                    item.file_url = (
                        f"{iso_url}/Fedora-Server-{flavor}-{arch}-{fedora_ver}-{server_iso_ver}.iso"
                    )
                    item.sha_url = (
                        f"{iso_url}/Fedora-Server-iso-{fedora_ver}-{server_iso_ver}-{arch}-CHECKSUM"
                    )

                    items.append(item)

            # Workstation
            for arch in fedora_arches:
                iso_url = f"{base_fedora_url}/Workstation/{arch}/iso"
                item = DownloadItem()
                item.containing_folder = Path(subfolder, fedora_ver, 'Workstation', arch)
                item.file_url = f"{iso_url}/Fedora-Workstation-Live-{fedora_ver}-{workstation_iso_ver}.{arch}.iso"
                item.sha_url = f"{iso_url}/Fedora-Workstation-iso-{fedora_ver}-{server_iso_ver}-{arch}-CHECKSUM"

                items.append(item)

        elif target == 'ipsw':
            mac_versions = ('26', '15', '14', '13', '12')

            for mac_version in mac_versions:
                item = DownloadItem()
                item.containing_folder = Path(firmware_folder, 'macOS/VM')
                item.file_url = get_latest_ipsw_url('VirtualMac2,1', mac_version)

                items.append(item)

        elif target == 'ubuntu':
            ubuntu_arches = ['amd64', 'arm64']
            ubuntu_vers = ['22.04', '24.04']

            for ubuntu_ver in ubuntu_vers:
                if ubuntu_ver == '24.04':
                    ubuntu_subver = ubuntu_ver + '.1'
                elif ubuntu_ver == '22.04':
                    ubuntu_subver = ubuntu_ver + '.4'
                else:
                    ubuntu_subver = ubuntu_ver

                for arch in ubuntu_arches:
                    if arch == 'amd64':
                        base_ubuntu_url = f"https://releases.ubuntu.com/{ubuntu_subver}"
                    elif arch == 'arm64':
                        base_ubuntu_url = (
                            f"https://cdimage.ubuntu.com/releases/{ubuntu_ver}/release"
                        )
                    else:
                        msg = f"Cannot handle Ubuntu architecture '{arch}'?"
                        raise RuntimeError(msg)

                    item = DownloadItem()
                    item.containing_folder = Path(firmware_folder, 'Ubuntu', ubuntu_ver, 'Server')
                    item.file_url = (
                        f"{base_ubuntu_url}/ubuntu-{ubuntu_subver}-live-server-{arch}.iso"
                    )
                    item.sha_url = f"{base_ubuntu_url}/SHA256SUMS"

                    items.append(item)

    for item in items:
        item.download_if_necessary()


if __name__ == '__main__':
    args = parse_parameters()

    if not (nas_folder := Path(os.environ['NAS_FOLDER'])).exists():
        msg = f"{nas_folder} does not exist, setup systemd automount files?"
        raise RuntimeError(msg)

    download_items(args.targets, nas_folder)

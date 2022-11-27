#!/usr/bin/env python3

import argparse
import datetime
import hashlib
import json
import os
import pathlib
import re
import requests


def print_color(color, string):
    print(f"{color}{string}\033[0m", flush=True)


def print_green(msg):
    print_color('\033[01;32m', msg)


def print_yellow(msg):
    print_color('\033[01;33m', msg)


def parse_parameters():
    parser = argparse.ArgumentParser(description='Download certain firmare images to NAS')

    supported_images = [
        'arch',
        'fedora',
        'ipsw',
        'rpios'
    ]  # yapf: disable

    parser.add_argument('-t',
                        '--targets',
                        choices=supported_images,
                        default=supported_images,
                        help='Download targets')

    return parser.parse_args()


def calculate_sha256(file_path):
    file_hash = hashlib.sha256()
    with open(file_path, 'rb') as file:
        while True:
            chunk = file.read(1048576)  # 1MB at a time
            if not chunk:
                break
            file_hash.update(chunk)
    return file_hash.hexdigest()


def get_sha256_from_url(url, basename):
    response = requests.get(url, timeout=3600)
    response.raise_for_status()
    for line in response.content.decode('utf-8').split('\n'):
        if re.search(basename, line):
            sha256_match = re.search('[A-Fa-f0-9]{64}', line)
            if sha256_match:
                return sha256_match.group(0)
    return None


def validate_sha256(file, url):
    computed_sha256 = calculate_sha256(file)
    expected_sha256 = get_sha256_from_url(url, file.stem)

    if computed_sha256 == expected_sha256:
        print_green(f"SUCCESS: {file.stem} sha256 passed!")
    else:
        raise Exception(
            f"{file.stem} computed checksum ('{computed_sha256}') did not match expected checksum ('{expected_sha256}')!"
        )


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
    base_file = item['file_url'].split('/')[-1]
    target = item['containing_folder'].joinpath(base_file)
    target.parent.mkdir(exist_ok=True)
    if target.exists():
        print_yellow(f"SKIP: {base_file} already downloaded!")
    else:
        print_green(f"INFO: {base_file} downloading...")
        response = requests.get(item['file_url'], timeout=3600)
        response.raise_for_status()
        with open(target, 'xb') as file:
            file.write(response.content)

    sha_url = item['sha_url']
    if sha_url:
        validate_sha256(target, sha_url)


def download_items(targets, containing_folder):
    items = []
    for target in targets:
        if target == 'arch':
            arch_day = '.01'
            arch_date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y.%m") + arch_day

            base_arch_url = f"https://mirrors.edge.kernel.org/archlinux/iso/{arch_date}"
            items += [{
                'containing_folder': containing_folder.joinpath('Arch Linux'),
                'file_url': f"{base_arch_url}/archlinux-{arch_date}-x86_64.iso",
                'sha_url': f"{base_arch_url}/sha256sums.txt"
            }]

        if target == 'fedora':
            fedora_arches = ['aarch64', 'x86_64']
            subfolder = containing_folder.joinpath(target.capitalize())

            # Constants to update
            fedora_ver = 37
            server_iso_ver = 1.7
            workstation_iso_ver = 1.7

            # Base URLs
            base_fedora_file_url = f"https://download.fedoraproject.org/pub/fedora/linux/releases/{fedora_ver}"
            base_fedora_checksum_url = f"https://getfedora.org/static/checksums/{fedora_ver}/iso/"

            # Server
            for arch in fedora_arches:
                items += [{
                    'containing_folder':
                    subfolder,
                    'file_url':
                    f"{base_fedora_file_url}/Server/{arch}/iso/Fedora-Server-netinst-{arch}-{fedora_ver}-{server_iso_ver}.iso",
                    'sha_url':
                    f"{base_fedora_checksum_url}/Fedora-Server-{fedora_ver}-{server_iso_ver}-{arch}-CHECKSUM"
                }]
            # Workstation
            for arch in fedora_arches:
                items += [{
                    'containing_folder':
                    subfolder,
                    'file_url':
                    f"{base_fedora_file_url}/Workstation/{arch}/iso/Fedora-Workstation-Live-{arch}-{fedora_ver}-{workstation_iso_ver}.iso",
                    'sha_url':
                    f"{base_fedora_checksum_url}/Fedora-Workstation-{fedora_ver}-{server_iso_ver}-{arch}-CHECKSUM"
                }]

        elif target == 'ipsw':
            mac_versions = ['13', '12']

            for mac_version in mac_versions:
                items += [{
                    'containing_folder': base_folder.joinpath('macOS', 'VM'),
                    'file_url': get_latest_ipsw_url('VirtualMac2,1', mac_version),
                    'sha_url': None
                }]

        elif target == 'rpios':
            rpi_arches = ['armhf', 'arm64']
            rpi_date = '2022-09-26/2022-09-22'
            deb_ver = 'bullseye'

            for rpi_arch in rpi_arches:
                base_rpi_url = f"https://downloads.raspberrypi.org/raspios_lite_{rpi_arch}/images/raspios_lite_{rpi_arch}-{rpi_date}-raspios-{deb_ver}-{rpi_arch}-lite.img.xz"
                items += [{
                    'containing_folder': containing_folder.joinpath('Raspberry Pi OS'),
                    'file_url': base_rpi_url,
                    'sha_url': base_rpi_url + '.sha256'
                }]

    for item in items:
        download_if_necessary(item)


if __name__ == '__main__':
    args = parse_parameters()

    nas_folder = pathlib.Path(os.environ['NAS_FOLDER'])
    if not nas_folder.exists():
        raise Exception(f"{nas_folder} does not exist, setup systemd automount files?")

    base_folder = nas_folder.joinpath("Firmware_and_Images")
    if not base_folder.exists():
        raise Exception(f"{base_folder} does not exist, systemd automounting broken?")

    download_items(args.targets, base_folder)
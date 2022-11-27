#!/usr/bin/env python3

import argparse
import datetime
import json
import os
import pathlib
import requests


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


def get_latest_ipsw_url(identifier, version):
    # Query the endpoint for list of builds
    response = requests.get(f"https://api.ipsw.me/v4/device/{identifier}?type=ipsw",
                            params={'Accept': 'application/json'},
                            timeout=3600)
    firmwares = json.loads(response.content)['firmwares']
    # Eliminate builds that are not for the requested versions
    version_firmwares = [item for item in firmwares if item['version'].split('.')[0] == version]
    # The first item is the newest, which is really all we care about
    return version_firmwares[0]['url']


def download_if_necessary(parent, url):
    base_file = url.split('/')[-1]
    target = parent.joinpath(base_file)
    if target.exists():
        print(f"{base_file} already downloaded, skipping...")
    else:
        print(f"{base_file} downloading...")
        response = requests.get(url, timeout=3600)
        response.raise_for_status()
        with open(target, 'xb') as file:
            file.write(response.content)


def download_items(targets, containing_folder):
    for target in targets:
        items = []
        if target == 'arch':
            subfolder = 'Arch Linux'

            arch_date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y.%m") + ".01"
            items += [
                f"https://mirrors.edge.kernel.org/archlinux/iso/{arch_date}/archlinux-{arch_date}-x86_64.iso"
            ]

        if target == 'fedora':
            fedora_arches = ['aarch64', 'x86_64']
            subfolder = target.capitalize()

            # Constants to update
            fedora_ver = 37
            server_iso_ver = 1.7
            workstation_iso_ver = 1.7
            base_fedora_url = f"https://download.fedoraproject.org/pub/fedora/linux/releases/{fedora_ver}"

            # Server
            items += [
                f"{base_fedora_url}/Server/{arch}/iso/Fedora-Server-netinst-{arch}-{fedora_ver}-{server_iso_ver}.iso"
                for arch in fedora_arches
            ]
            # Workstation
            items += [
                f"{base_fedora_url}/Workstation/{arch}/iso/Fedora-Workstation-Live-{arch}-{fedora_ver}-{workstation_iso_ver}.iso"
                for arch in fedora_arches
            ]

        elif target == 'ipsw':
            mac_versions = ['13', '12']
            subfolder = 'macOS/VM'

            items += [
                get_latest_ipsw_url('VirtualMac2,1', mac_version) for mac_version in mac_versions
            ]

        elif targets == 'rpios':
            subfolder = 'Raspberry Pi OS'
            rpi_arches = ['armhf', 'arm64']
            rpi_date = '2022-09-26/2022-09-22'
            deb_ver = 'bullseye'

            items += [
                f"https://downloads.raspberrypi.org/raspios_lite_{rpi_arch}/images/raspios_lite_{rpi_arch}-{rpi_date}-raspios-{deb_ver}-{rpi_arch}-lite.img.xz"
                for rpi_arch in rpi_arches
            ]

        target_folder = containing_folder.joinpath(subfolder)
        target_folder.mkdir(exist_ok=True)

        for item in items:
            download_if_necessary(target_folder, item)


if __name__ == '__main__':
    args = parse_parameters()

    nas_folder = pathlib.Path(os.environ['NAS_FOLDER'])
    if not nas_folder.exists():
        raise Exception(f"{nas_folder} does not exist, setup systemd automount files?")

    base_folder = nas_folder.joinpath("Firmware_and_Images")
    if not base_folder.exists():
        raise Exception(f"{base_folder} does not exist, systemd automounting broken?")

    download_items(args.targets, base_folder)

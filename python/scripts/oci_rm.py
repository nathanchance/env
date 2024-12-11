#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position


def fzf(target, fzf_input):
    fzf_cmd = ['fzf', '--header', target.capitalize(), '--multi']
    with subprocess.Popen(fzf_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          text=True) as fzf_proc:
        return fzf_proc.communicate(fzf_input)[0].splitlines()


def oci_json(target):
    podman_out = lib.utils.chronic(['podman', target, 'ls', '--all', '--format', 'json']).stdout
    return json.loads(podman_out)


def parse_arguments():
    parser = ArgumentParser()

    target_choices = ['containers', 'images']
    parser.add_argument('-t',
                        '--targets',
                        choices=target_choices,
                        default=target_choices,
                        metavar='TARGETS',
                        nargs='+',
                        help='Items to potentially remove (default: %(default)s).')

    return parser.parse_args()


def podman_rm(target, items):
    lib.utils.run(['podman', target, 'rm', '--force', *items], show_cmd=True)
    print()


def remove(target):
    target_cmd = target.rstrip('s')
    fzf_choices = []
    json_data = oci_json(target_cmd)

    for json_item in json_data:
        item_id = json_item['Id']
        if 'Image' in json_item:  # Container item
            container_name = json_item['Names'][0]
            image_name = json_item['Image']
            fzf_choices += [f"{item_id} | {image_name} | {container_name}"]
        elif 'Containers' in json_item:  # Image item
            if 'Names' in json_item:
                image_name = json_item['Names'][0]
            else:
                image_name = f"<none> (was: {json_item['History'][0]})"
            fzf_choices += [f"{item_id} | {image_name}"]

    items_to_remove = [item.split(' ')[0] for item in fzf(target, '\n'.join(fzf_choices))]
    if items_to_remove:
        podman_rm(target_cmd, items_to_remove)


if __name__ == '__main__':
    if not shutil.which('podman'):
        raise RuntimeError('podman could not be found?')

    args = parse_arguments()

    for podman_target in args.targets:
        remove(podman_target)

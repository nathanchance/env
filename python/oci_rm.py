#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

from argparse import ArgumentParser
from json import loads
from shutil import which
from subprocess import PIPE, Popen, run


def fzf(target, fzf_input):
    fzf_cmd = ["fzf", "--header", target.capitalize(), "--multi"]
    fzf_proc = Popen(fzf_cmd, stdin=PIPE, stdout=PIPE, text=True)
    return fzf_proc.communicate(fzf_input)[0].splitlines()


def oci_json(target):
    podman_cmd = ["podman", target, "ls", "--all", "--format", "json"]
    podman_out = run(podman_cmd, capture_output=True, check=True, text=True).stdout
    return loads(podman_out)


def parse_arguments():
    parser = ArgumentParser()

    target_choices = ["containers", "images"]
    parser.add_argument("-t",
                        "--targets",
                        choices=target_choices,
                        default=target_choices,
                        metavar="TARGETS",
                        nargs="+",
                        help="Items to potentially remove (default: %(default)s).")

    return parser.parse_args()


def podman_rm(target, items):
    podman_cmd = ["podman", target, "rm", "--force"] + items
    print(f"$ {' '.join(podman_cmd)}")
    run(podman_cmd, check=True)
    print()


def remove(target):
    target_cmd = target.rstrip("s")
    fzf_choices = []
    json_data = oci_json(target_cmd)

    for json_item in json_data:
        item_id = json_item['Id']
        if "Image" in json_item:  # Container item
            container_name = json_item['Names'][0]
            image_name = json_item['Image']
            fzf_choices += [f"{item_id} | {image_name} | {container_name}"]
        elif "Containers" in json_item:  # Image item
            if "Names" in json_item:
                image_name = json_item['Names'][0]
            else:
                image_name = f"<none> (was: {json_item['History'][0]})"
            fzf_choices += [f"{item_id} | {image_name}"]

    items_to_remove = [item.split(" ")[0] for item in fzf(target, '\n'.join(fzf_choices))]
    if items_to_remove:
        podman_rm(target_cmd, items_to_remove)


if __name__ == "__main__":
    if not which("podman"):
        raise RuntimeError("podman could not be found?")

    args = parse_arguments()

    for target in args.targets:
        remove(target)

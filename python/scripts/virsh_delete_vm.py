#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "requests>=2.33.1",
# ]
# ///

import sys
from argparse import ArgumentParser
from pathlib import Path

import requests

sys.path.append(str(Path(__file__).resolve().parents[1]))
import lib.utils


def parse_arguments():
    parser = ArgumentParser(description='Remove virtual machine using virsh')

    parser.add_argument('domains', nargs='+', help='Domains to remove')

    return parser.parse_args()


def main():
    args = parse_arguments()
    codeberg_authorization_header = {'Authorization': f'token {lib.utils.get_codeberg_token()}'}
    codeberg_runners_api = 'https://codeberg.org/api/v1/user/actions/runners'

    result = requests.get(
        codeberg_runners_api,
        headers=codeberg_authorization_header,
        params={'visible': 'false'},
        timeout=10,
    )
    result.raise_for_status()
    registered_runners = {item['name']: item['id'] for item in result.json()}

    running_domains = [
        val
        for item in lib.utils.chronic(
            ['virsh', 'list', '--name', '--state-running']
        ).stdout.splitlines()
        if (val := item.strip())
    ]

    for domain in args.domains:
        if domain in running_domains:
            lib.utils.run(['virsh', 'destroy', domain])

        virsh_undefine_cmd = ['virsh', 'undefine', '--remove-all-storage', domain]
        if 'nvram' in lib.utils.chronic(['virsh', 'dumpxml', domain]).stdout:
            virsh_undefine_cmd.insert(-1, '--nvram')

        lib.utils.run(virsh_undefine_cmd)

        if domain in registered_runners:
            requests.delete(
                f"{codeberg_runners_api}/{registered_runners[domain]}",
                headers=codeberg_authorization_header,
                timeout=10,
            )


if __name__ == '__main__':
    main()

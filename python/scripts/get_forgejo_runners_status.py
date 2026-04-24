#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "requests>=2.33.1",
# ]
# ///

import sys
from pathlib import Path

import requests

sys.path.append(str(Path(__file__).resolve().parents[1]))
import operator

import lib.utils


def main():
    codeberg_token = lib.utils.get_codeberg_token()
    result = requests.get(
        'https://codeberg.org/api/v1/user/actions/runners',
        headers={'Authorization': f'token {codeberg_token}'},
        params={'visible': 'false'},
        timeout=10,
    )
    result.raise_for_status()
    runners = result.json()

    keys = ('name', 'status', 'version')
    columns = {key: len(key) for key in keys}

    for runner in runners:
        for key in keys:
            if (new_max := len(runner[key])) > columns[key]:
                columns[key] = new_max

    table_header = f"| {' | '.join(f'{key:{width}}' for key, width in columns.items())} |"
    table_divider = '-' * len(table_header)
    table_rows = ''.join(
        f"| {' | '.join(f'{runner[key]:{width}}' for key, width in columns.items())} |\n"
        for runner in sorted(runners, key=operator.itemgetter('name'))
    )

    print(table_divider)
    print(table_header)
    print(table_divider)
    print(table_rows, end='')
    print(table_divider)


if __name__ == '__main__':
    if sys.argv[-1] in {'-h', '--help'}:
        print('Get information about Forgejo Runners from Codeberg API')
        sys.exit(0)
    main()

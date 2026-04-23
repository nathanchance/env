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

    first_column_width = 53
    second_column_width = 13

    table_header = f"| {'runner'.ljust(first_column_width, ' ')} | {'status'.ljust(second_column_width, ' ')} |"
    table_divider = '-' * len(table_header)
    table_rows = ''.join(
        f"| {runner['name']:{first_column_width}} | {runner['status']:{second_column_width}} |\n"
        for runner in sorted(runners, key=operator.itemgetter('name'))
    )

    print(table_divider)
    print(table_header)
    print(table_divider)
    print(table_rows, end='')
    print(table_divider)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import hashlib
import re
from pathlib import Path

# Anything that imports this will need to use uv
# pylint: disable-next=import-error
import requests

from . import utils


def calculate(file_path):
    file_hash = hashlib.sha256()
    with Path(file_path).open('rb') as file:
        # 1MB at a time
        while (chunk := file.read(1048576)):  # 1MB at a time
            file_hash.update(chunk)
    return file_hash.hexdigest()


def get_from_url(url, basename):
    response = requests.get(url, timeout=3600)
    response.raise_for_status()
    for line in response.content.decode('utf-8').splitlines():
        if 'clone.bundle' in basename:
            basename = basename.split('-')[0]
        if basename in line and (sha256_match := re.search('[A-Fa-f0-9]{64}', line)):
            return sha256_match.group(0)
    return None


def validate_from_url(file, url):
    computed_sha256 = calculate(file)
    expected_sha256 = get_from_url(url, file.name)

    if computed_sha256 == expected_sha256:
        utils.print_green(f"SUCCESS: {file.name} sha256 passed!")
    else:
        raise RuntimeError(
            f"{file.name} computed checksum ('{computed_sha256}') did not match expected checksum ('{expected_sha256}')!",
        )

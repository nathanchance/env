#!/usr/bin/env python3

import hashlib
import re
import requests

import lib_user


def calculate(file_path):
    file_hash = hashlib.sha256()
    with open(file_path, 'rb') as file:
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
        if basename in line:
            if (sha256_match := re.search('[A-Fa-f0-9]{64}', line)):
                return sha256_match.group(0)
    return None


def validate_from_url(file, url):
    computed_sha256 = calculate(file)
    expected_sha256 = get_from_url(url, file.name)

    if computed_sha256 == expected_sha256:
        lib_user.print_green(f"SUCCESS: {file.name} sha256 passed!")
    else:
        raise Exception(
            f"{file.name} computed checksum ('{computed_sha256}') did not match expected checksum ('{expected_sha256}')!"
        )

#!/usr/bin/env python3

import getpass
import os
import socket
import subprocess
import sys
from pathlib import Path
from typing import Any

import requests


def find_and_validate_runner_cfg() -> Path:
    if len(forgejo_configs := list(Path('/etc/forgejo-runner').glob('config.y*ml'))) != 1:
        msg = f"More than one forgejo-runner configuration? {forgejo_configs}"
        raise RuntimeError(msg)

    with (forgejo_config := forgejo_configs[0]).open('rb') as file:
        file.seek(-16, 2)
        if file.read() != b'\n  connections:\n':
            msg = f"{forgejo_config} is not clean or format changed!"
            raise RuntimeError(msg)

    return forgejo_config


def get_codeberg_token() -> str:
    if token := os.environ.get('CODEBERG_TOKEN'):
        return token
    getpass_kwargs: dict[str, Any] = {'prompt': 'Codeberg API token: '}
    if sys.version_info >= (3, 14, 0):
        getpass_kwargs['echo_char'] = '*'
    return getpass.getpass(**getpass_kwargs)


def setup_ssh_authorized_keys() -> None:
    old_umask = os.umask(0o077)

    ssh_authorized_keys = Path.home().joinpath('.ssh/authorized_keys')
    ssh_authorized_keys.parent.mkdir(exist_ok=True)

    result = requests.get('https://codeberg.org/nathanchance.keys', timeout=10)
    result.raise_for_status()

    ssh_authorized_keys.write_text(result.text, encoding='utf-8')

    os.umask(old_umask)


def main() -> None:
    runner_cfg_yml = find_and_validate_runner_cfg()
    user_endpoint = 'https://codeberg.org/api/v1/user'
    runners_endpoint = f"{user_endpoint}/actions/runners"

    # https://forgejo.org/docs/next/user/api-usage/#more-on-the-authorization-header
    request_headers = {
        'accept': 'application/json',
        'Authorization': f"token {get_codeberg_token()}",
        'Content-Type': 'application/json',
    }

    # Ensure that we can authenticate with the requested token
    requests.get(user_endpoint, headers=request_headers, timeout=10).raise_for_status()

    # Ensure runner is not registered already (which would be rejected by the
    # register user endpoint) to provide a friendlier message
    request_params = {'visible': 'false'}  # exclude global runners
    result = requests.get(
        runners_endpoint, headers=request_headers, params=request_params, timeout=10
    )
    result.raise_for_status()
    existing_runners = {item['name'] for item in result.json()}
    if (runner_name := socket.gethostname()) in existing_runners:
        registered_runners = '\n'.join(sorted(existing_runners))
        msg = f"{runner_name} is already registered!\nRegistered runners:\n{registered_runners}"
        raise RuntimeError(msg)

    # Register runner via Forgejo API on Codeberg:
    # https://codeberg.org/api/swagger#/user/registerUserRunner
    request_json = {
        'description': '',
        'ephemeral': False,
        'name': runner_name,
    }
    result = requests.post(runners_endpoint, headers=request_headers, json=request_json, timeout=10)
    result.raise_for_status()
    registered_runner = result.json()

    # Figure out if VM will be a builder based on number of CPU cores
    label_name = 'docker'
    if (os.cpu_count() or 1) > 8:
        label_name += '-build'
    default_docker_image = 'data.forgejo.org/oci/node:lts'
    runner_label = f"{label_name}:docker://{default_docker_image}"

    # Add connection information to runner configuration file
    connection_info = f'''\
    {runner_name}:
      url: https://codeberg.org/
      uuid: {registered_runner['uuid']}
      token: {registered_runner['token']}
      labels:
      - {runner_label}
'''
    with runner_cfg_yml.open('a') as file:
        file.write(connection_info)

    # Start runner service (it is already enabled by preset in mkosi)
    subprocess.run(['systemctl', 'start', 'forgejo-runner.service'], check=True)

    # Pull Node Docker image from Docker Hub to avoid rate limits from
    # data.forgejo.org when many jobs spawn on fresh VMs
    for image in (f"docker.io/{default_docker_image.rsplit('/', 1)[1]}", default_docker_image):
        subprocess.run(['docker', 'pull', image], check=True)

    # Set up .ssh/authorized_keys to allow passwordless login
    setup_ssh_authorized_keys()

    # Remove setup file
    Path(__file__).unlink()


if __name__ == '__main__':
    main()

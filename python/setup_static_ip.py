#!/usr/bin/env python3

import argparse
import ipaddress
import os
import re
import shutil
import subprocess


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Sets a static IP address on the active Ethernet port')

    parser.add_argument('-i', '--ip-addr', help='IP address to assign', required=True)
    parser.add_argument('-n',
                        '--name',
                        default='Wired connection 1',
                        help='Name of connection to modify in NetworkManager')

    return parser.parse_args()


def check_ip(ip_to_check):
    ipaddress.ip_address(ip_to_check)


def initial_checks(ip_addr):
    if os.geteuid() != 0:
        raise Exception('FAIL: This script need to be run as root!')

    for command in ['ip', 'nmcli']:
        if not shutil.which(command):
            raise Exception(f"FAIL: {command} could not be found")

    # Validate that the supplied IP address is valid
    check_ip(ip_addr)


def get_active_interface(con_name):
    active_connections = subprocess.run(
        ['nmcli', '-f', 'NAME,DEVICE', 'connection', 'show', '--active'],
        capture_output=True,
        check=True,
        text=True).stdout.strip().split('\n')
    for line in active_connections:
        line = line.strip()
        if re.search(con_name, line):
            return line.split(' ')[-1]
    return None


def get_ip_addr_for_intf(intf):
    ip_out = subprocess.run(['ip', 'addr'], capture_output=True, check=True,
                            text=True).stdout.split('\n')
    ip_addr = None
    for line in ip_out:
        if re.search(fr'inet.*\d{{1,3}}\.\d{{1,3}}\.\d{{1,3}}\.\d{{1,3}}.*{intf}', line):
            ip_addr = re.search(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', line).group(0)
            break
    check_ip(ip_addr)
    return ip_addr


def set_ip_addr_for_intf(con_name, intf, ip_addr):
    nmcli_mod = ['nmcli', 'connection', 'modify', con_name]

    if '192.168.4' in ip_addr:
        gateway = '192.168.4.1'
        local_dns = '192.168.0.1'
    else:
        raise Exception(f"FAIL: {ip_addr} not supported by script!")
    dns = ['8.8.8.8', '8.8.4.4', '1.1.1.1', local_dns]

    subprocess.run(nmcli_mod + ['ipv4.addresses', f"{ip_addr}/24"], check=True)
    subprocess.run(nmcli_mod + ['ipv4.dns', ' '.join(dns)], check=True)
    subprocess.run(nmcli_mod + ['ipv4.gateway', gateway], check=True)
    subprocess.run(nmcli_mod + ['ipv4.method', 'manual'], check=True)
    subprocess.run(['nmcli', 'connection', 'reload'], check=True)
    subprocess.run(['nmcli', 'connection', 'down', con_name], check=True)
    subprocess.run(['nmcli', 'connection', 'up', con_name, 'ifname', intf], check=True)

    current_ip = get_ip_addr_for_intf(intf)
    if current_ip != ip_addr:
        raise Exception(
            f"FAIL: IP address of '{intf}' ('{current_ip}') did not change to requested IP address ('{ip_addr}')"
        )


if __name__ == '__main__':
    args = parse_arguments()

    requested_ip = args.ip_addr
    connection_name = args.name

    initial_checks(requested_ip)

    interface = get_active_interface(connection_name)

    set_ip_addr_for_intf(connection_name, interface, requested_ip)

#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from xml.etree.ElementTree import ElementTree  # ruff:ignore[suspicious-xml-etree-import]


def get_running_vms() -> set[str]:
    return {item for item in virsh_list(running=True).splitlines() if item.strip()}


def virsh_dumpxml(vm_name: str) -> ElementTree:
    with TemporaryDirectory() as tempdir:
        with (dumpxml := Path(tempdir, 'dump.xml')).open('w', encoding='utf-8') as file:
            subprocess.run(
                ['virsh', 'dumpxml', vm_name], check=True, stderr=subprocess.PIPE, stdout=file
            )
        (tree := ElementTree()).parse(dumpxml)
    return tree


def virsh_list(plain: bool = True, running: bool = False, sift: bool = True) -> str:
    virsh_cmd = ['virsh', 'list', '--state-running' if running else '--all']
    if plain:
        virsh_cmd.append('--name')
    elif sift:
        print('[-] sifting requested without plain, ignoring...')
        sift = False
    try:
        res = subprocess.run(virsh_cmd, capture_output=True, check=True, text=True)
    except subprocess.CalledProcessError as err:
        if err.stdout:
            print(err.stdout)
        if err.stderr:
            print(err.stderr)
        raise
    if not sift:
        return res.stdout
    return '\n'.join(
        sorted(item for item in res.stdout.splitlines() if item.startswith('forgejo-runner'))
    )


def main():
    if (vm_name := sys.argv[1]) == '-h':
        print('Delete Codeberg API token from virsh XML defintion')
        sys.exit(0)

    if vm_name in get_running_vms():
        msg = f"{vm_name} has not properly shut down!"
        raise RuntimeError(msg)

    # Get current domain XML and look for sysinfo and smbios nodes
    tree = virsh_dumpxml(vm_name)
    if (domain := tree.getroot()) is None:
        msg = 'Could not get domain node!'
        raise RuntimeError(msg)
    if (sysinfo_node := domain.find('sysinfo')) is None:
        print(f"[-] Cannot find sysinfo node for {vm_name}, this is unexpected!")
        return

    print(f"[+] Removing sysinfo and smbios nodes from {vm_name} XML to clear GitHub token")
    domain.remove(sysinfo_node)
    if (os_node := domain.find('os')) is not None and (
        smbios_node := os_node.find('smbios')
    ) is not None:
        os_node.remove(smbios_node)

    with TemporaryDirectory() as tempdir:
        tree.write(new_xml := Path(tempdir, 'new.xml'))
        subprocess.run(['virsh', 'define', '--validate', new_xml], check=True)

    print(f"[+] Starting {vm_name} with updated XML")
    subprocess.run(['virsh', 'start', vm_name], check=True)

    print(f"[+] Checking that {vm_name} XML has no sysinfo node when running")
    if (domain := virsh_dumpxml(vm_name).getroot()) is None:
        msg = 'Could not get domain node!'
        raise RuntimeError(msg)
    if domain.find('sysinfo') is not None:
        msg = f"sysinfo node exists for {vm_name}!"
        raise RuntimeError(msg)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

import pathlib
import re
import shutil
import subprocess

import lib_root


def configure_networking():
    hostname = lib_root.get_hostname()

    ips = {
        'honeycomb': '192.168.4.210',
    }

    if hostname not in ips:
        return

    lib_root.setup_static_ip(ips[hostname])
    lib_root.setup_mnt_nas()


def dnf_add_repo(repo_url):
    lib_root.dnf(['config-manager', '--add-repo', repo_url])


def dnf_install(install_args):
    lib_root.dnf(['install', '-y'] + install_args)


def get_fedora_version():
    return int(lib_root.get_os_rel_val('VERSION_ID'))


def machine_is_trusted():
    return lib_root.get_hostname() in ('honeycomb')


def prechecks():
    lib_root.check_root()
    fedora_version = get_fedora_version()
    if fedora_version not in (35, 36, 37):
        raise Exception(
            f"Fedora {fedora_version} is not tested with this script, add support for it if it works."
        )


def resize_rootfs():
    df_out = subprocess.run(['df', '-T'], capture_output=True, check=True, text=True).stdout
    for line in df_out.split('\n'):
        if '/dev/mapper/' in line:
            dev_mapper_path, dev_mapper_fs_type = line.split(' ')[0:2]

            # This can fail if it is already resized to max so don't bother
            # checking the return code.
            subprocess.run(['lvextend', '-l', '+100%FREE', dev_mapper_path], check=False)

            if dev_mapper_fs_type == 'xfs':
                subprocess.run(['xfs_growfs', dev_mapper_path], check=True)

            break


def install_initial_packages():
    lib_root.dnf(['update', '-y'])
    dnf_install(['dnf-plugins-core'])


def install_packages():
    packages = [
        # administration
        'mosh',
        'opendoas',
        'util-linux-user',

        # b4
        'b4',

        # compression and decompression
        'zstd',

        # distrobox
        'distrobox',
        'podman',

        # email
        'cyrus-sasl-plain',
        'mutt',

        # env
        'curl',
        'fish',
        'fzf',
        'jq',
        'neofetch',
        'openssh',
        'python-pip',
        'python-tmuxp',
        'stow',
        'tmux',
        'vim',
        'zoxide',

        # git
        'gh',
        'git',
        'git-delta',
        'git-email',

        # nicer GNU utilities
        'duf',
        'exa',
        'ripgrep',

        # repo
        'python',

        # tuxmake
        'tuxmake'
    ]  # yapf: disable

    # Install Virtualization group on Equinix Metal servers or trusted machines
    if lib_root.is_equinix() or machine_is_trusted():
        packages += ['@virtualization']

    if machine_is_trusted():
        packages += ['tailscale']

    dnf_install(packages)


def setup_doas():
    # Fedora provides a doas.conf already, just modify it to suit our needs
    doas_conf = pathlib.Path('/etc/doas.conf')
    conf_txt = doas_conf.read_text(encoding='utf-8')

    conf_txt = re.sub('permit :wheel', 'permit persist :wheel', conf_txt)
    conf_txt += ('\n'
                 '# Do not require root to put in a password (makes no sense)\n'
                 'permit nopass root\n')

    doas_conf.write_text(conf_txt, encoding='utf-8')

    # Remove sudo but set up a symlink for compatibility
    pathlib.Path('/etc/dnf/protected.d/sudo.conf').unlink(missing_ok=True)
    lib_root.remove_if_installed('sudo')
    lib_root.setup_sudo_symlink()


def setup_kernel_args():
    if lib_root.get_hostname() != 'honeycomb':
        return

    # Until firmware supports new IORT RMR patches
    args = ['arm-smmu.disable_bypass=0', 'iommu.passthrough=1']
    grubby_cmd = ['grubby', '--args', ' '.join(args), '--update-kernel', 'ALL']
    subprocess.run(grubby_cmd, check=True)


def setup_libvirt(username):
    if not lib_root.is_installed('virt-install'):
        return

    lib_root.setup_libvirt(username)


def setup_mosh():
    if not shutil.which('firewall-cmd'):
        return

    subprocess.run(['firewall-cmd', '--add-port=60000-61000/udp', '--permanent'], check=True)
    subprocess.run(['firewall-cmd', '--reload'], check=True)


def setup_repos():
    dnf_add_repo('https://cli.github.com/packages/rpm/gh-cli.repo')

    if machine_is_trusted():
        dnf_add_repo('https://pkgs.tailscale.com/stable/fedora/tailscale.repo')

    tuxmake_repo_text = ('[tuxmake]\n'
                         'name=tuxmake\n'
                         'type=rpm-md\n'
                         'baseurl=https://tuxmake.org/packages/\n'
                         'gpgcheck=1\n'
                         'gpgkey=https://tuxmake.org/packages/repodata/repomd.xml.key\n'
                         'enabled=1\n')
    pathlib.Path('/etc/yum.repos.d/tuxmake.repo').write_text(tuxmake_repo_text, encoding='utf-8')


if __name__ == '__main__':
    user = lib_root.get_user()

    prechecks()
    resize_rootfs()
    install_initial_packages()
    setup_repos()
    install_packages()
    setup_doas()
    setup_kernel_args()
    setup_libvirt(user)
    setup_mosh()
    configure_networking()
    lib_root.enable_tailscale()
    lib_root.chsh_fish(user)
    lib_root.clone_env(user)
    lib_root.setup_initial_fish_config(user)

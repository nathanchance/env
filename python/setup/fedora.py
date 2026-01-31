#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import shutil
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils

# pylint: enable=wrong-import-position

MIN_FEDORA_VERSION = 35
MAX_FEDORA_VERSION = 43


def dnf_add_repo(repo_url):
    # config-manager does not support --add-repo with dnf5, which is the
    # default in Fedora 41 now.
    # https://github.com/rpm-software-management/dnf5/issues/1537
    # Done in an agnostic way because this is shared with AlmaLinux.
    if Path(shutil.which('dnf')).resolve().name.endswith('5'):
        local_dst = Path('/etc/yum.repos.d', repo_url.rsplit('/', 1)[1])
        lib.utils.curl(repo_url, output=local_dst)
    else:
        lib.setup.dnf(['config-manager', '--add-repo', repo_url])


def dnf_install(install_args):
    lib.setup.dnf(['install', '-y', *install_args])


def get_fedora_version():
    return int(lib.setup.get_os_rel_val('VERSION_ID'))


def machine_is_trusted():
    return lib.setup.get_hostname() in ('aadp', 'honeycomb')


def prechecks():
    lib.utils.check_root()
    if (fedora_version := get_fedora_version()) not in range(MIN_FEDORA_VERSION,
                                                             MAX_FEDORA_VERSION + 1):
        raise RuntimeError(
            f"Fedora {fedora_version} is not tested with this script, add support for it if it works.",
        )


def resize_rootfs():
    for line in lib.utils.chronic(['df', '-T']).stdout.splitlines():
        if '/dev/mapper/' in line:
            dev_mapper_path, dev_mapper_fs_type = line.split(' ')[0:2]

            # This can fail if it is already resized to max so don't bother
            # checking the return code.
            lib.utils.run(['lvextend', '-l', '+100%FREE', dev_mapper_path], check=False)

            if dev_mapper_fs_type == 'xfs':
                lib.utils.run(['xfs_growfs', dev_mapper_path])

            break


def install_initial_packages():
    lib.setup.dnf(['update', '-y'])
    dnf_install(['dnf-plugins-core'])


def install_local_packages(package_names):
    packages_dir = Path(lib.setup.get_env_root(), 'bin/packages')

    package_files = []
    for package in package_names:
        package_files += list(packages_dir.glob(f"{package}-*.rpm"))

    dnf_install(package_files)


def install_packages():
    fedora_version = get_fedora_version()
    packages = [
        # administration
        'btop',
        'clean-rpm-gpg-pubkey',
        'ethtool',
        'fastfetch',
        'mosh',
        'opendoas',
        'remove-retired-packages',
        'rpmconf',
        'symlinks',
        'util-linux-user',

        # b4
        'b4',

        # compression and decompression
        'unzip',
        'zstd',

        # email
        'cyrus-sasl-plain',
        'mutt',

        # env
        'curl',
        'fish',
        'fzf',
        'jq',
        'openssh',
        'python-pip',
        'rsync',
        'stow',
        'tmux',
        'vim',
        'zoxide',

        # git
        'gh',
        'git',
        'git-delta',
        'git-email',

        # mkosi / systemd-nspawn
        'apt',
        'debian-keyring',
        'distribution-gpg-keys',
        'patch',
        'polkit',
        'systemd-container',

        # nicer GNU utilities
        'duf',
        'ripgrep',

        # repo
        'python',

        # tuxmake
        'tuxmake',
    ]  # yapf: disable

    if fedora_version < 42:
        packages.append('eza')

    if not lib.setup.is_lxc():
        packages.append('podman')

    if machine_is_trusted():
        packages += ['@virtualization', 'tailscale']

    # Needed to occasionally upgrade the MMC firmware
    if lib.setup.get_hostname() == 'aadp':
        packages.append('ipmitool')

    dnf_install(packages)

    # Install local packages
    local_packages = ('modprobed-db', )
    install_local_packages(local_packages)


def setup_doas(username):
    # Fedora provides a doas.conf already, just modify it to suit our needs
    doas_conf, conf_txt = lib.utils.path_and_text('/etc/doas.conf')
    if (persist := 'permit persist :wheel') not in conf_txt:
        conf_txt = conf_txt.replace('permit :wheel', persist)

        conf_txt += ('\n'
                     '# Do not require root to put in a password (makes no sense)\n'
                     'permit nopass root\n')

        # OrbStack sets up passwordless sudo, carry it over to doas
        # If we created a user password, this file will not be set up
        # but we still want this behavior, so check for /mnt/mac as well.
        if Path('/etc/sudoers.d/orbstack').exists() or Path('/mnt/mac').is_dir():
            conf_txt += ('\n'
                         '# passwordless doas for my user\n'
                         f"permit nopass {username}\n")
        else:
            conf_txt += (
                '\n'
                '# Allow me to update packages without a password (arguments are matched exactly)\n'
                f"permit nopass {username} as root cmd dnf args update\n"
                f"permit nopass {username} as root cmd dnf args update -y\n")

        doas_conf.write_text(conf_txt, encoding='utf-8')

    # Apply umask value from /etc/login.defs to doas sessions, which mirrors
    # what sudo does
    doas_pam, doas_pam_txt = lib.utils.path_and_text('/etc/pam.d/doas')
    if (pam_umask := 'session    optional     pam_umask.so\n') not in doas_pam_txt:
        with doas_pam.open('a', encoding='utf-8') as file:
            file.write(pam_umask)

    # Remove sudo but set up a symlink for compatibility. Only do this if kdesu
    # is not installed, as it has a dependency on sudo.
    if not lib.setup.is_installed('kf6-kdesu'):
        Path('/etc/dnf/protected.d/sudo.conf').unlink(missing_ok=True)
        # https://src.fedoraproject.org/rpms/sudo/c/770b8e2647c61512b8508c61bb3a55318f31d9b1
        Path('/usr/share/dnf5/libdnf.conf.d/protect-sudo.conf').unlink(missing_ok=True)
        lib.setup.remove_if_installed('sudo')
        lib.setup.setup_sudo_symlink()


def setup_kernel_args():
    if (hostname := lib.setup.get_hostname()) == 'aadp':
        # Intel X550-T2 spews correctable errors about timeouts :(
        args = ['pcie_aspm=off']
    elif hostname == 'honeycomb':
        # Until firmware supports new IORT RMR patches
        args = ['arm-smmu.disable_bypass=0', 'iommu.passthrough=1']
    else:
        return

    grubby_cmd = ['grubby', '--args', ' '.join(args), '--update-kernel', 'ALL']
    lib.utils.run(grubby_cmd)


def setup_libvirt(username):
    if not lib.setup.is_installed('virt-install'):
        return

    lib.setup.setup_libvirt(username)


def setup_mosh():
    if not shutil.which('firewall-cmd'):
        return

    lib.utils.run(['firewall-cmd', '--add-port=60000-61000/udp', '--permanent'])
    lib.utils.run(['firewall-cmd', '--reload'])


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
    Path('/etc/yum.repos.d/tuxmake.repo').write_text(tuxmake_repo_text, encoding='utf-8')


if __name__ == '__main__':
    user = lib.setup.get_user()

    prechecks()
    resize_rootfs()
    install_initial_packages()
    setup_repos()
    install_packages()
    setup_doas(user)
    setup_kernel_args()
    setup_libvirt(user)
    setup_mosh()
    lib.setup.configure_trusted_networking()
    lib.setup.enable_tailscale()
    lib.setup.chsh_fish(user)
    lib.setup.clone_env(user)
    lib.setup.setup_initial_fish_config(user)
    lib.setup.setup_ssh_authorized_keys(user)
    lib.setup.setup_virtiofs_automount()

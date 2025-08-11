#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from pathlib import Path
import re
import shutil
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils
# pylint: enable=wrong-import-position

MIN_FEDORA_VERSION = 35
MAX_FEDORA_VERSION = 42


def configure_networking():
    hostname = lib.setup.get_hostname()

    ips = {
        'aadp': '10.0.1.143',
        'honeycomb': '10.0.1.253',
    }

    if hostname not in ips:
        return

    lib.setup.setup_static_ip(ips[hostname])
    lib.setup.setup_mnt_nas()


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


def early_pi_fixups():
    if not lib.setup.is_pi():
        return

    # There is an unfortunate bug with LVM and arm-image-installer that we
    # need to check for.
    # https://bugzilla.redhat.com/bugzilla/show_bug.cgi?id=2247872
    # https://bugzilla.redhat.com/bugzilla/show_bug.cgi?id=2258764
    lvmsysdev = Path('/etc/lvm/devices/system.devices')
    if lvmsysdev.exists() and '/dev/mmcblk' not in lvmsysdev.read_text(encoding='utf-8'):
        lvmsysdev.unlink()
        lib.utils.run(['vgimportdevices', '-a'])
        lib.utils.run(['vgchange', '-ay'])

    # arm-setup-installer extends the size of the physical partition and
    # LVM partition but not the XFS partition, so just do that and
    # circumvent the rest of this function's logic.
    lib.utils.run(['xfs_growfs', '-d', '/'])

    # Ensure 'rhgb quiet' is removed for all current and future kernels, as it
    # hurts debugging early boot failures. Make sure the serial console is set
    # up properly as well.
    args = ['console=ttyS0,115200', 'console=tty0']
    remove_args = ['rhgb', 'quiet']

    # arm-setup-installer may rename the logical volume and adjust the first
    # bootloader entry but this does not appear to get updated for all future
    # kernel installs.
    grub_txt = Path('/etc/default/grub').read_text(encoding='utf-8')
    if not (match := re.search(r'rd.lvm.lv=(.*)/root', grub_txt)):
        raise RuntimeError('Cannot find rd.lvm.lv value in /etc/default/grub?')
    grub_vg_name = match.groups()[0]
    sys_vg_name = lib.utils.chronic(['vgs', '--noheading', '-o', 'vg_name']).stdout.strip()
    if len(sys_vg_name.split(' ')) != 1:
        raise RuntimeError('More than one VG found?')
    if grub_vg_name != sys_vg_name:
        dm_node_name = {
            'fedora': 'fedora-root',
            'fedora-server': 'fedora--server-root',
        }[sys_vg_name]
        args += [
            f"root=/dev/mapper/{dm_node_name}",
            f"rd.lvm.lv={sys_vg_name}/root",
        ]

    grubby_cmd = [
        'grubby',
        '--args', ' '.join(args),
        '--remove-args', ' '.join(remove_args),
        '--update-kernel', 'ALL',
    ]  # yapf: disable
    lib.utils.run(grubby_cmd)


def get_fedora_version():
    return int(lib.setup.get_os_rel_val('VERSION_ID'))


def machine_is_trusted():
    return lib.setup.get_hostname() in ('aadp', 'honeycomb', 'raspberrypi')


def prechecks():
    lib.utils.check_root()
    if (fedora_version := get_fedora_version()) not in range(MIN_FEDORA_VERSION,
                                                             MAX_FEDORA_VERSION + 1):
        raise RuntimeError(
            f"Fedora {fedora_version} is not tested with this script, add support for it if it works.",
        )


def resize_rootfs():
    # This will be handled in early_pi_setup()
    if lib.setup.is_pi():
        return

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
        'systemd-container',

        # nicer GNU utilities
        'duf',
        'ripgrep',

        # repo
        'python',

        # tuxmake
        'tuxmake',
    ]  # yapf: disable

    if fedora_version < 39:
        packages.append('exa')
    elif fedora_version < 42:
        packages.append('eza')

    if not lib.setup.is_lxc():
        packages.append('podman')

    # Install Virtualization group on Equinix Metal servers or trusted machines
    if lib.setup.is_equinix() or machine_is_trusted():
        packages.append('@virtualization')

    if machine_is_trusted():
        packages.append('tailscale')

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

        doas_conf.write_text(conf_txt, encoding='utf-8')

    # Apply umask value from /etc/login.defs to doas sessions, which mirrors
    # what sudo does
    doas_pam, doas_pam_txt = lib.utils.path_and_text('/etc/pam.d/doas')
    if (pam_umask := 'session    optional     pam_umask.so\n') not in doas_pam_txt:
        with doas_pam.open('a', encoding='utf-8') as file:
            file.write(pam_umask)

    # Remove sudo but set up a symlink for compatibility
    Path('/etc/dnf/protected.d/sudo.conf').unlink(missing_ok=True)
    lib.setup.remove_if_installed('sudo')
    lib.setup.setup_sudo_symlink()


def setup_kernel_args():
    if lib.setup.get_hostname() != 'honeycomb':
        return

    # Until firmware supports new IORT RMR patches
    args = ['arm-smmu.disable_bypass=0', 'iommu.passthrough=1']
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


def setup_pi(username):
    if not lib.setup.is_pi():
        return

    lib.setup.setup_mnt_ssd(username)


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
    early_pi_fixups()
    resize_rootfs()
    install_initial_packages()
    setup_repos()
    install_packages()
    setup_doas(user)
    setup_kernel_args()
    setup_libvirt(user)
    setup_mosh()
    setup_pi(user)
    configure_networking()
    lib.setup.enable_tailscale()
    lib.setup.chsh_fish(user)
    lib.setup.clone_env(user)
    lib.setup.setup_initial_fish_config(user)
    lib.setup.setup_ssh_authorized_keys(user)
    lib.setup.setup_virtiofs_automount()

#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils
# pylint: enable=wrong-import-position

MIN_FEDORA_VERSION = 35
MAX_FEDORA_VERSION = 40


def configure_networking():
    hostname = lib.setup.get_hostname()

    ips = {
        'aadp': '192.168.4.234',
        'honeycomb': '192.168.4.210',
        'raspberrypi': '192.168.4.205',
    }

    if hostname not in ips:
        return

    lib.setup.setup_static_ip(ips[hostname])
    lib.setup.setup_mnt_nas()


def dnf_add_repo(repo_url):
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
        subprocess.run(['vgimportdevices', '-a'], check=True)
        subprocess.run(['vgchange', '-ay'], check=True)

    # arm-setup-installer extends the size of the physical partition and
    # LVM partition but not the XFS partition, so just do that and
    # circumvent the rest of this function's logic.
    subprocess.run(['xfs_growfs', '-d', '/'], check=True)

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
    sys_vg_name = subprocess.run(['vgs', '--noheading', '-o', 'vg_name'],
                                 capture_output=True,
                                 check=True,
                                 text=True).stdout.strip()
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
    subprocess.run(grubby_cmd, check=True)


def get_fedora_version():
    return int(lib.setup.get_os_rel_val('VERSION_ID'))


def machine_is_trusted():
    return lib.setup.get_hostname() in ('aadp', 'honeycomb', 'raspberrypi')


def prechecks():
    lib.setup.check_root()
    if (fedora_version := get_fedora_version()) not in range(MIN_FEDORA_VERSION,
                                                             MAX_FEDORA_VERSION + 1):
        raise RuntimeError(
            f"Fedora {fedora_version} is not tested with this script, add support for it if it works.",
        )


def resize_rootfs():
    # This will be handled in early_pi_setup()
    if lib.setup.is_pi():
        return

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
    lib.setup.dnf(['update', '-y'])
    dnf_install(['dnf-plugins-core'])


def install_packages():
    fedora_version = get_fedora_version()
    packages = [
        # administration
        'btop',
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

        # distrobox
        'distrobox',

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

        # nicer GNU utilities
        'duf',
        'eza' if fedora_version >= 39 else 'exa',
        'ripgrep',

        # repo
        'python',

        # tuxmake
        'tuxmake',
    ]  # yapf: disable

    if lib.setup.is_lxc():
        packages += [
            'docker-ce',
            'docker-ce-cli',
            'containerd.io',
            'docker-buildx-plugin',
            'docker-compose-plugin',
        ]
    else:
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


def setup_doas(username):
    # Fedora provides a doas.conf already, just modify it to suit our needs
    doas_conf, conf_txt = lib.utils.path_and_text('/etc/doas.conf')
    if (persist := 'permit persist :wheel') not in conf_txt:
        conf_txt = conf_txt.replace('permit :wheel', persist)

        conf_txt += ('\n'
                     '# Do not require root to put in a password (makes no sense)\n'
                     'permit nopass root\n')

        # OrbStack sets up passwordless sudo, carry it over to doas
        if Path('/etc/sudoers.d/orbstack').exists():
            conf_txt += ('\n'
                         '# passwordless doas for my user\n'
                         f"permit nopass {username}\n")

        doas_conf.write_text(conf_txt, encoding='utf-8')

    # Remove sudo but set up a symlink for compatibility
    Path('/etc/dnf/protected.d/sudo.conf').unlink(missing_ok=True)
    lib.setup.remove_if_installed('sudo')
    lib.setup.setup_sudo_symlink()


def setup_docker(username):
    if not shutil.which('docker'):
        return

    subprocess.run(['groupadd', '-f', 'docker'], check=True)
    lib.setup.add_user_to_group('docker', username)
    lib.setup.systemctl_enable(['docker'])


def setup_kernel_args():
    if lib.setup.get_hostname() != 'honeycomb':
        return

    # Until firmware supports new IORT RMR patches
    args = ['arm-smmu.disable_bypass=0', 'iommu.passthrough=1']
    grubby_cmd = ['grubby', '--args', ' '.join(args), '--update-kernel', 'ALL']
    subprocess.run(grubby_cmd, check=True)


def setup_libvirt(username):
    if not lib.setup.is_installed('virt-install'):
        return

    lib.setup.setup_libvirt(username)


def setup_mosh():
    if not shutil.which('firewall-cmd'):
        return

    subprocess.run(['firewall-cmd', '--add-port=60000-61000/udp', '--permanent'], check=True)
    subprocess.run(['firewall-cmd', '--reload'], check=True)


def setup_pi(username):
    if not lib.setup.is_pi():
        return

    lib.setup.setup_mnt_ssd(username)


def setup_repos():
    dnf_add_repo('https://cli.github.com/packages/rpm/gh-cli.repo')

    if lib.setup.is_lxc():
        dnf_add_repo('https://download.docker.com/linux/fedora/docker-ce.repo')

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
    setup_docker(user)
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

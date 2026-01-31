#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import copy
import grp
import ipaddress
import os
import platform
import pwd
import re
import shutil
import socket
import sys
import time
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils

# pylint: enable=wrong-import-position


class FstabItem:

    def __init__(self, fs, directory, fstype, opts, dump, check):

        self.fs = fs
        self.dir = str(directory)  # in case Path was passed
        self.type = fstype
        self.opts = opts
        self.dump = dump
        self.check = check

    def __str__(self):
        order = ('fs', 'dir', 'type', 'opts', 'dump', 'check')
        return ' '.join(getattr(self, attr) for attr in order)

    def get_dev(self):
        if (uuid := self.get_uuid()) and (uuid_path := Path('/dev/disk/by-uuid', uuid)).exists():
            return uuid_path.resolve()
        if self.fs.startswith('/dev'):
            return Path(self.fs)
        return None

    def get_uuid(self):
        if self.fs.startswith('UUID='):
            return self.fs.split('=', maxsplit=1)[1]
        return None


class Fstab:

    ARCH_VFAT_OPTS = 'rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro'

    def __init__(self, init_str=''):

        self.entries = {}

        if not init_str:
            init_str = Path('/etc/fstab').read_text(encoding='utf-8')

        for line in init_str.splitlines():
            if line := line.strip():
                if line.startswith('#'):
                    continue

                item = FstabItem(*line.split())
                self.entries[item.dir] = item

    def __contains__(self, item):
        return str(item) in self.entries

    def __delitem__(self, key):
        del self.entries[str(key)]

    def __getitem__(self, item):
        return self.entries[str(item)]

    def __setitem__(self, key, value):
        if not isinstance(value, FstabItem):
            raise TypeError
        if isinstance(key, Path):
            key = str(key)
        if value.dir == key:
            self.entries[key] = value
        else:
            self.entries[key] = copy.copy(value)
            self.entries[key].dir = key

    def _gen_str(self):
        header = ('# Static information about the filesystems.\n'
                  '# See fstab(5) for details.\n'
                  '# <file system> <dir> <type> <options> <dump> <pass>\n')
        lines = []

        for item in self.entries.values():
            # If we have a UUID, try to find the corresponding block device for
            # a comment identifying it.
            if dev := item.get_dev():
                lines.append(f"# {dev}")
            lines.append(str(item))

        return header + '\n'.join(lines) + '\n'

    def __str__(self):
        return self._gen_str()

    # Adjust the options for the ESP and ext partitions on Hetzner systems
    def adjust_for_hetzner(self):
        for item in self.entries.values():
            if (item.type, item.opts) == ('vfat', 'umask=0077'):
                item.opts = Fstab.ARCH_VFAT_OPTS

            if (item.type, item.dir) == ('ext4', '/') and 'errors=remount-ro' not in item.opts:
                item.opts += ',errors=remount-ro'

            if item.type.startswith(('ext', 'btrfs')) and item.check == '0':
                item.check = '1' if item.dir == '/' else '2'

    def write(self, path=None, dryrun=False):
        if not path:
            path = Path('/etc/fstab')
        lib.utils.print_or_write_text(path, self._gen_str(), dryrun)
        if not dryrun:
            lib.utils.run(['systemctl', 'daemon-reload'])


def add_user_to_group(groupname, username):
    lib.utils.run(['usermod', '-aG', groupname, username])


def add_user_to_group_if_exists(groupname, username):
    if group_exists(groupname):
        add_user_to_group(groupname, username)


def apk(apk_arguments):
    lib.utils.run0(['apk', *apk_arguments])


def apt(apt_arguments):
    lib.utils.run0(['apt', *apt_arguments])


def check_ip(ip_to_check):
    ipaddress.ip_address(ip_to_check)


# Easier than os.walk() + shutil.chown()
def chown(new_user, folder):
    lib.utils.run(['chown', '-R', f"{new_user}:{new_user}", folder])


def chpasswd(user_name, new_password):
    lib.utils.run('chpasswd', input=f"{user_name}:{new_password}")


def chsh_fish(username):
    if not (fish := shutil.which('fish')):
        raise RuntimeError('fish not installed?')

    # normalize path
    fish = Path(fish).resolve().as_posix()
    if fish not in Path('/etc/shells').read_text(encoding='utf-8'):
        raise RuntimeError(f"{fish} is not in /etc/shells?")

    lib.utils.run(['chsh', '-s', fish, username])


def clone_env(username):
    if not (env_tmp := Path('/tmp/env')).exists():  # noqa: S108
        lib.utils.run(['git', 'clone', 'https://github.com/nathanchance/env', env_tmp])
        chown(username, env_tmp)


def configure_trusted_networking():
    static_ips = {
        'aadp': '10.0.1.2',
        'asus-intel-core-11700': '10.0.1.5',
        'beelink-amd-ryzen-8745HS': '10.0.1.8',
        'beelink-intel-n100': '10.0.1.11',
        'chromebox3': '10.0.1.14',
        'framework-amd-ryzen-maxplus-395': '10.0.1.23',
        'honeycomb': '10.0.1.17',
        'mac-studio-m1-max': '10.0.1.33',
        'msi-intel-core-10210U': '10.0.1.20',
        # 'thelio-3990X': '',
    }
    if (hostname := get_hostname()) not in static_ips:
        return
    # Validate that the supplied IP address is valid
    check_ip(requested_ip := static_ips[hostname])

    # Configure static IP address on the active interface
    connection_name, interface = get_active_ethernet_info()
    set_ip_addr_for_intf(connection_name, interface, requested_ip)

    # Adjust advertised auto negotiation speeds on X550-T2 NICs
    # to allow 2.5GbE
    setup_x550_link_speeds(interface)

    # Setup /mnt/nas files
    for file in ('mnt-nas.mount', 'mnt-nas.automount'):
        src = Path(get_env_root(), 'configs/systemd', file)
        dst = Path('/etc/systemd/system', file)

        shutil.copyfile(src, dst)
        dst.chmod(0o644)
    systemctl_enable(file)


def disable_suspend():
    # If machine has a battery, the power profile should be customized manually
    if len(list(Path('/sys/class/power_supply').glob('BAT*'))) > 0:
        return

    # https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Disable_sleep_completely
    if not (sleep_drop_in := Path('/etc/systemd/sleep.conf.d/disable-sleep.conf')).exists():
        file_text = ('[Sleep]\n'
                     'AllowSuspend=no\n'
                     'AllowHibernation=no\n'
                     'AllowHybridSleep=no\n'
                     'AllowSuspendThenHibernate=no\n')
        sleep_drop_in.parent.mkdir(exist_ok=True)
        sleep_drop_in.write_text(file_text, encoding='utf-8')
        sleep_drop_in.chmod(0o644)


def dnf(dnf_arguments):
    lib.utils.run0(['dnf', *dnf_arguments])


def enable_tailscale():
    if not is_installed('tailscale'):
        return

    systemctl_enable('tailscaled.service')


def fetch_gpg_key(source_url, dest):
    # Dearmor if necessary
    if (key_data := lib.utils.curl(source_url))[0:2] != b'\x99\x02':
        key_data = lib.utils.chronic(['gpg', '--dearmor'], input=key_data).stdout

    dest.write_bytes(key_data)


def get_active_ethernet_info():
    if not shutil.which('nmcli'):
        raise RuntimeError('Cannot get active Ethernet information without nmcli!')
    nmcli_cmd = ['nmcli', '-f', 'TYPE,NAME,DEVICE', '-t', 'connection', 'show', '--active']
    for line in lib.utils.chronic(nmcli_cmd).stdout.splitlines():
        if 'ethernet' in line:
            return line.split(':')[1:]
    return None


def get_env_root():
    if (env_root := Path(__file__).resolve().parents[2]).joinpath('README.md').exists():
        return env_root
    raise RuntimeError(f"{env_root} does not seem correct?")


def get_glibc_version():
    ldd_version_out = lib.utils.chronic(['ldd', '--version']).stdout
    ldd_version = ldd_version_out.split('\n')[0].split(' ')[-1].split('.')
    if len(ldd_version) < 3:
        ldd_version += [0]
    return tuple(int(x) for x in ldd_version)


def get_hostname():
    return socket.gethostname()


def get_ip_addr_for_intf(intf):
    if not shutil.which('ip'):
        raise RuntimeError(f"Cannot get IP address for {intf} without ip!")
    ip_addr = None
    for line in lib.utils.chronic(['ip', 'addr']).stdout.split('\n'):
        ip_a_regex = fr'inet\s+(\d{{1,3}}\.\d{{1,3}}\.\d{{1,3}}\.\d{{1,3}})/\d+\s+.*{intf}$'
        if (match := re.search(ip_a_regex, line)):
            ip_addr = match.groups()[0]
            break
    check_ip(ip_addr)
    return ip_addr


def get_os_rel_val(variable):
    return get_os_rel()[variable]


def get_os_rel():
    for file_val in ['/etc/os-release', '/usr/lib/os-release']:
        if (file := Path(file_val)).exists():
            break
    else:
        return None

    # Remove quotes now, as they are needed for shell but not for this
    # conversion
    os_rel_txt = file.read_text(encoding='utf-8').replace('"', '')

    return dict(
        item.split('=', 1) for item in os_rel_txt.splitlines() if item and not item.startswith('#'))


def get_udevadm_properties(sysfs_path):
    udevadm_info = {}
    udevadm_info_cmd = ['udevadm', 'info', '-q', 'property', sysfs_path]
    for line in lib.utils.chronic(udevadm_info_cmd).stdout.splitlines():
        key, value = line.split('=', 1)
        udevadm_info[key] = value
    return udevadm_info


def get_user():
    if 'USERNAME' in os.environ:
        return os.environ['USERNAME']
    return 'nathan'


def get_version_codename():
    return get_os_rel_val('VERSION_CODENAME')


def group_exists(group):
    try:
        grp.getgrnam(group)
    except KeyError:
        return False
    return True


def is_installed(package_to_check):
    if using_pacman():
        pacman_packages = lib.utils.chronic(['pacman', '-Qq']).stdout
        return bool(re.search(f"^{package_to_check}$", pacman_packages, flags=re.M))
    if shutil.which('dnf'):
        cmd = ['dnf', 'list', '--installed']
    elif shutil.which('dpkg'):
        cmd = ['dpkg', '-s']
    else:
        raise RuntimeError('Not implemented for the current package manager!')

    return lib.utils.run_check_rc_zero([*cmd, package_to_check])


def is_lxc():
    if shutil.which('systemd-detect-virt'):
        return lib.utils.detect_virt() == 'lxc'
    return 'container=lxc' in Path('/proc/1/environ').read_text(encoding='utf-8')


def is_virtual_machine():
    if shutil.which('systemd-detect-virt'):
        return lib.utils.detect_virt() in ('qemu', 'kvm', 'vmware', 'microsoft', 'apple')
    return get_hostname() in ('hyperv', 'qemu', 'vmware')


def is_systemd_init():
    if not shutil.which('systemctl'):
        return False
    return lib.utils.run_check_rc_zero(['systemctl', 'is-system-running', '--quiet'])


def pacman(args):
    lib.utils.run0(['pacman', *args])


def partition_drive(device, mountpoint, username=None, fstype=None):
    if not username:
        username = get_user()
    if not fstype:
        fstype = 'ext4'
    elif fstype not in ('btrfs', 'ext4'):
        raise RuntimeError(f"Cannot safely handle filesytem type ('{fstype}')?")

    if not device.startswith(('/dev/nvme', '/dev/sd')):
        raise RuntimeError(f"Cannot safely handle device path '{device}'?")

    partition = Path(device + 'p1' if '/dev/nvme' in device else '1')

    if mountpoint.is_mount():
        raise RuntimeError(f"mountpoint ('{mountpoint}') is already mounted?")

    if partition.is_block_device():
        raise RuntimeError(f"partition ('{partition}') already exists?")

    # Create partition on device
    if shutil.which('sgdisk'):
        lib.utils.run(['sgdisk', '-N', '1', '-t', '1:8300', device])
    else:
        lib.utils.run([
            'parted',
            '-s',
            device,
            'mklabel',
            'gpt',
            'mkpart',
            'primary',
            fstype,
            '0%',
            '100%',
        ],
                      check=True)
        # Let everything sync up
        time.sleep(10)

    # Format partition
    lib.utils.run(['mkfs', '-t', fstype, partition], env={'E2FSPROGS_LIBMAGIC_SUPPRESS': '1'})

    # Add partition to fstab
    fstab = Fstab()
    part_uuid = lib.utils.chronic(['blkid', '-o', 'value', '-s', 'PARTUUID',
                                   partition]).stdout.strip()
    fstab[mountpoint] = FstabItem(f"PARTUUID={part_uuid}", mountpoint, fstype, 'defaults', '0', '2')
    fstab.write()

    # Mount partition to its mountpoint
    mountpoint.mkdir(exist_ok=True, parents=True)
    lib.utils.run(['mount', '-a'])
    if mountpoint != Path('/home'):
        lib.setup.chown(username, mountpoint)


def podman_setup(username):
    line = f"{username}:100000:65536\n"

    for letter in ['g', 'u']:
        if (file := Path(f"/etc/sub{letter}id")).exists():
            if username not in (file_text := file.read_text(encoding='utf-8')):
                file.write_text(f"{file_text}\n{line}", encoding='utf-8')
        else:
            file.write_text(line, encoding='utf-8')

    if not (registries_conf := Path('/etc/containers/registries.conf')).exists():
        registries_conf.write_text(
            "[registries.search]\nregistries = ['docker.io', 'ghcr.io', 'quay.io']\n",
            encoding='utf-8')


def remove_if_installed(package_to_remove):
    if is_installed(package_to_remove):
        if using_pacman():
            pacman(['-R', '--noconfirm', package_to_remove])
        elif shutil.which('dnf'):
            dnf(['remove', '-y', package_to_remove])
        elif shutil.which('apt'):
            apt(['remove', '-y', package_to_remove])
        else:
            raise RuntimeError('Not implemented for the current package manager!')


def set_ip_addr_for_intf(con_name, intf, ip_addr):
    nmcli_mod = ['nmcli', 'connection', 'modify', con_name]

    if '10.0.1' in ip_addr:
        gateway = local_dns = '10.0.1.1'
    else:
        raise RuntimeError(f"{ip_addr} not supported by script!")
    dns = ['8.8.8.8', '8.8.4.4', '1.1.1.1', local_dns]

    lib.utils.run([*nmcli_mod, 'ipv4.addresses', f"{ip_addr}/24"])
    lib.utils.run([*nmcli_mod, 'ipv4.dns', ' '.join(dns)])
    lib.utils.run([*nmcli_mod, 'ipv4.gateway', gateway])
    lib.utils.run([*nmcli_mod, 'ipv4.method', 'manual'])
    lib.utils.run(['nmcli', 'connection', 'reload'])
    lib.utils.run(['nmcli', 'connection', 'down', con_name])
    lib.utils.run(['nmcli', 'connection', 'up', con_name, 'ifname', intf])

    current_ip = get_ip_addr_for_intf(intf)
    if current_ip != ip_addr:
        raise RuntimeError(
            f"IP address of '{intf}' ('{current_ip}') did not change to requested IP address ('{ip_addr}')",
        )


def set_date_time():
    if is_systemd_init():
        lib.utils.run(['timedatectl', 'set-timezone', 'America/Phoenix'])


def setup_initial_fish_config(username):
    fish_ver = lib.utils.chronic(['fish', '-c', 'echo $version']).stdout.strip().split('.')
    # Certain 4.0 versions may have non-numeric charcters (like 4.0b1). We can
    # just look at the major version in that case to know that this check will
    # pass.
    if int(fish_ver[0]) < 4 and tuple(map(int, fish_ver)) < (3, 4, 0):
        raise RuntimeError(f"{fish_ver} is less than 3.4.0!")

    user_cfg = Path('/home', username, '.config')
    fish_cfg = Path(user_cfg, 'fish/config.fish')
    if not fish_cfg.is_symlink():
        fish_cfg.parent.mkdir(mode=0o755, exist_ok=True, parents=True)
        fish_cfg_txt = (
            'if status is-interactive\n'
            '    # Start an ssh-agent\n'
            '    if not set -q SSH_AUTH_SOCK\n'
            '        eval (ssh-agent -c)\n'
            '    end\n'
            '\n'
            '    # If we are in a login shell...\n'
            '    status is-login\n'
            '    # or Konsole, which does not use login shells by default...\n'
            '    or set -q KONSOLE_VERSION\n'
            '    # and we are not already in a tmux environment...\n'
            '    and not set -q TMUX\n'
            '    # and we have it installed,\n'
            '    and command -q tmux\n'
            '    # attempt to attach to a session named "main" while detaching everyone\n'
            '    # else or create a new session if one does not already exist\n'
            '    and tmux new-session -AD -s main\n'
            '\n'
            '    # Set up user environment wrapper\n'
            '    function env_setup\n'
            '        if not set -q TMUX\n'
            r"            printf '\n%bERROR: %s%b\n\n' '\033[01;31m' 'env_setup needs to be run in tmux.' '\033[0m'"
            '\n'
            '            return 1\n'
            '        end\n'
            '        if not test -d /tmp/env\n'
            '            git -C /tmp clone -q https://github.com/nathanchance/env\n'
            '            or return\n'
            '        end\n'
            '        git -C /tmp/env pull -qr\n'
            '        curl -LSs https://git.io/fisher | source\n'
            '        and fisher install jorgebucaran/fisher 1>/dev/null\n'
            '        and fisher install /tmp/env/fish 1>/dev/null\n'
            '        and user_setup $argv\n'
            '   end\n'
            'end\n')
        fish_cfg.write_text(fish_cfg_txt, encoding='utf-8')
        chown(username, user_cfg)


def setup_libvirt(username):
    # Add user to libvirt group for rootless access to system sessions.
    add_user_to_group('libvirt', username)

    # Enable libvirtd systemd service to ensure it is brought up on restart.
    systemctl_enable('libvirtd.service')

    # Make the default network come up automatically on restart.
    lib.utils.run(['virsh', 'net-autostart', 'default'])

    # Start network if it is not already started
    net_info = lib.utils.chronic(['virsh', 'net-info', 'default']).stdout
    if re.search('^Active.*no', net_info, flags=re.M):
        lib.utils.run(['virsh', 'net-start', 'default'])


def setup_virtiofs_automount(mountpoint='/mnt/host'):
    # If we are not in a virtual machine, there is no point to setting up a
    # mount for virtiofs :)
    if not is_virtual_machine():
        return

    # /sys/fs/virtiofs/*/tag is only available in Linux 6.9 and newer:
    # https://git.kernel.org/linus/a8f62f50b4e4ea92a938fca2ec1bd108d7f210e9
    # As automounting will fail gracefully if something is not configured
    # correctly, we fallback to the known value from cbl_vmm.py.
    host_kernel_rel = platform.uname().release
    if not (match := re.search(r"^\d+\.\d+\.\d+", host_kernel_rel)):
        raise RuntimeError(f"Unable to match kernel version in '{host_kernel_rel}'??")
    host_kernel_ver = tuple(map(int, match.group().split('.')))
    if host_kernel_ver >= (6, 9, 0):
        tag_sysfs = list(Path('/sys/fs/virtiofs').glob('*/tag'))
        if len(tag_sysfs) == 0:
            lib.utils.print_yellow(
                'Virtual machine has no virtiofs mounts, skipping setting up automounting...')
            return
        if len(tag_sysfs) > 1:
            raise RuntimeError('Multiple virtiofs tags found?')
        tag = tag_sysfs[0].read_text(encoding='utf-8').strip()
    else:
        tag = 'host'

    unit_name = mountpoint.strip('/').replace('/', '-')

    mount_txt = ('[Unit]\n'
                 f"Description=Mount {tag} virtiofs folder\n"
                 '\n'
                 '[Mount]\n'
                 f"What={tag}\n"
                 f"Where={mountpoint}\n"
                 'Type=virtiofs\n'
                 '\n'
                 '[Install]\n'
                 'WantedBy=multi-user.target\n')
    mount_path = Path('/etc/systemd/system', f"{unit_name}.mount")
    mount_path.write_text(mount_txt, encoding='utf-8')
    mount_path.chmod(0o644)

    automount_txt = ('[Unit]\n'
                     f"Description=Automount {tag} virtiofs folder\n"
                     '\n'
                     '[Automount]\n'
                     f"Where={mountpoint}\n"
                     '\n'
                     '[Install]\n'
                     'WantedBy=multi-user.target\n')
    automount_path = mount_path.with_suffix('.automount')
    automount_path.write_text(automount_txt, encoding='utf-8')
    automount_path.chmod(0o644)

    lib.utils.run(['systemctl', 'daemon-reload'])

    systemctl_enable(automount_path.name)


def setup_ssh_authorized_keys(user_name):
    if not (ssh_authorized_keys := Path('/home', user_name, '.ssh/authorized_keys')).exists():
        old_umask = os.umask(0o077)
        ssh_authorized_keys.parent.mkdir(exist_ok=True, parents=True)
        if shutil.which('curl'):
            cmd = ['curl', '-fLSs']
        elif shutil.which('wget'):
            cmd = ['wget', '-q', '-O-']
        else:
            raise RuntimeError(
                'No suitable download command could be found for downloading SSH key!')
        ssh_key = lib.utils.chronic([*cmd, 'https://github.com/nathanchance.keys'],
                                    text=None).stdout
        ssh_authorized_keys.write_bytes(ssh_key)
        os.umask(old_umask)
        chown(user_name, ssh_authorized_keys.parent)


def setup_sudo_symlink():
    prefix = Path(os.environ.get('PREFIX', '/usr/local'))
    sudo_prefix = Path(prefix, 'stow/sudo')
    sudo_bin = Path(sudo_prefix, 'bin/sudo')

    sudo_bin.parent.mkdir(exist_ok=True, parents=True)
    sudo_bin.unlink(missing_ok=True)

    if (doas := Path(shutil.which('doas')).resolve()) == Path('/usr/bin/doas'):
        relative_doas = Path('../../../../bin/doas')
    else:
        raise RuntimeError(f"Can't handle doas location ('{doas}')?")
    sudo_bin.symlink_to(relative_doas)

    lib.utils.run(['stow', '-d', sudo_prefix.parent, '-R', sudo_prefix.name, '-v'])


def setup_x550_link_speeds(intf):
    udevadm_props = get_udevadm_properties(f"/sys/class/net/{intf}")
    if 'Ethernet Controller X550' not in udevadm_props['ID_MODEL_FROM_DATABASE']:
        return

    valid_macs = (
        'b4:96:91:a5:92:34',
        'b4:96:91:a5:92:36',
        'b4:96:91:b8:3e:9a',
        'b4:96:91:b8:3e:98',
    )
    valid_speeds = (
        '100baset-full',
        '1000baset-full',
        '2500baset-full',
        '5000baset-full',
        '10000baset-full',
    )

    rates_conf = Path('/etc/systemd/network/99-default.link.d/x550-t2-rates.conf')
    if not rates_conf.exists():
        if not rates_conf.parent.exists():
            rates_conf.parent.mkdir(mode=0o755)
        rates_conf_txt = ('[Match]\n'
                          f"PermanentMACAddress={' '.join(valid_macs)}\n"
                          '\n'
                          '[Link]\n'
                          f"Advertise={' '.join(valid_speeds)}\n")
        rates_conf.write_text(rates_conf_txt, encoding='utf-8')
        rates_conf.chmod(0o644)


def systemctl_enable(items_to_enable, now=True):
    cmd = ['systemctl', 'enable']
    if now:
        cmd.append('--now')
    (cmd.append if isinstance(items_to_enable, str) else cmd.extend)(items_to_enable)

    lib.utils.run(cmd)


def user_exists(user):
    try:
        pwd.getpwnam(user)
    except KeyError:
        return False
    return True


def using_pacman():
    # pacman may be installed for compatibility with mkosi but we have to make
    # sure that it is actually being used on Arch Linux so ensure that the core
    # repository exists.
    return shutil.which('pacman') and Path('/var/lib/pacman/sync/core.db').exists()


def using_systemd_boot():
    if not shutil.which('bootctl'):
        return False
    return lib.utils.run_check_rc_zero(['bootctl', '--quiet', 'is-installed'])


def umount_gracefully(folder):
    if lib.utils.run_check_rc_zero(['mountpoint', '-q', folder]):
        lib.utils.run(['umount', folder])


def zypper(zypper_args):
    lib.utils.run0(['zypper', *zypper_args])

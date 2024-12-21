#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import copy
import grp
import ipaddress
import os
from pathlib import Path
import platform
import pwd
import re
import shutil
import socket
import sys

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

            if item.type.startswith('ext'):
                if item.dir == '/' and 'errors=remount-ro' not in item.opts:
                    item.opts += ',errors=remount-ro'

                if item.check == '0':
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
    lib.utils.run_as_root(['apk', *apk_arguments])


def apt(apt_arguments):
    lib.utils.run_as_root(['apt', *apt_arguments])


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

    if fish not in Path('/etc/shells').read_text(encoding='utf-8'):
        raise RuntimeError(f"{fish} is not in /etc/shells?")

    lib.utils.run(['chsh', '-s', fish, username])


def clone_env(username):
    if not (env_tmp := Path('/tmp/env')).exists():  # noqa: S108
        lib.utils.run(['git', 'clone', 'https://github.com/nathanchance/env', env_tmp])
        chown(username, env_tmp)


def dnf(dnf_arguments):
    lib.utils.run_as_root(['dnf', *dnf_arguments])


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


def get_user():
    if 'USERNAME' in os.environ:
        return os.environ['USERNAME']
    if is_pi() and user_exists('pi'):
        return 'pi'
    return 'nathan'


def get_version_codename():
    return get_os_rel_val('VERSION_CODENAME')


def group_exists(group):
    try:
        grp.getgrnam(group)
    except KeyError:
        return False
    return True


def is_equinix():
    return re.search('[a|c|f|g|m|n|s|t|x]{1}[1-3]{1}-.*', get_hostname())


def is_installed(package_to_check):
    if shutil.which('pacman'):
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


def is_pi():
    return get_hostname() == 'raspberrypi'


def is_virtual_machine():
    if shutil.which('systemd-detect-virt'):
        return lib.utils.detect_virt() in ('qemu', 'kvm', 'vmware', 'microsoft', 'apple')
    return get_hostname() in ('hyperv', 'qemu', 'vmware')


def is_systemd_init():
    if not shutil.which('systemctl'):
        return False
    return lib.utils.run_check_rc_zero(['systemctl', 'is-system-running', '--quiet'])


def pacman(args):
    lib.utils.run_as_root(['pacman', *args])


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
        if shutil.which('pacman'):
            pacman(['-R', '--noconfirm', package_to_remove])
        elif shutil.which('dnf'):
            dnf(['remove', '-y', package_to_remove])
        elif shutil.which('apt'):
            apt(['remove', '-y', package_to_remove])
        else:
            raise RuntimeError('Not implemented for the current package manager!')


def set_ip_addr_for_intf(con_name, intf, ip_addr):
    nmcli_mod = ['nmcli', 'connection', 'modify', con_name]

    if '192.168.4' in ip_addr:
        gateway = '192.168.4.1'
        local_dns = '192.168.0.1'
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
    host_kernel_ver = tuple(map(int, platform.uname().release.split('-', 1)[0].split('.')))
    if host_kernel_ver >= (6, 9, 0):
        tag_sysfs = list(Path('/sys/fs/virtiofs').glob('*/tag'))
        if len(tag_sysfs) != 1:
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


def setup_mnt_nas():
    systemd_configs = Path(get_env_root(), 'configs/systemd')

    for file in ['mnt-nas.mount', 'mnt-nas.automount']:
        src = Path(systemd_configs, file)
        dst = Path('/etc/systemd/system', file)

        shutil.copyfile(src, dst)
        dst.chmod(0o644)

    systemctl_enable(file)


def setup_mnt_ssd(user_name):
    if (ssd_partition := Path('/dev/sda1')).is_block_device():
        (mnt_point := Path('/mnt/ssd')).mkdir(exist_ok=True, parents=True)
        chown(user_name, mnt_point)

        if mnt_point not in (fstab := Fstab()):
            partuuid = lib.utils.chronic(['blkid', '-o', 'value', '-s', 'PARTUUID',
                                          ssd_partition]).stdout.strip()

            fstab[mnt_point] = FstabItem(f"PARTUUID={partuuid}", mnt_point, 'ext4',
                                         'defaults,noatime', '0', '1')
            fstab.write()

        lib.utils.run(['mount', '-a'])

        if shutil.which('docker'):
            docker_json = Path('/etc/docker/daemon.json')
            docker_json.parent.mkdir(exist_ok=True, parents=True)
            docker_json_txt = ('{\n'
                               f'"data-root": "{mnt_point}/docker"'
                               '\n}\n')
            docker_json.write_text(docker_json_txt, encoding='utf-8')


def setup_static_ip(requested_ip):
    for command in ['ip', 'nmcli']:
        if not shutil.which(command):
            raise RuntimeError(f"{command} could not be found")

    # Validate that the supplied IP address is valid
    check_ip(requested_ip)

    connection_name, interface = get_active_ethernet_info()

    set_ip_addr_for_intf(connection_name, interface, requested_ip)


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


def using_systemd_boot():
    if not shutil.which('bootctl'):
        return False
    return lib.utils.run_check_rc_zero(['bootctl', '--quiet', 'is-installed'])


def umount_gracefully(folder):
    if lib.utils.run_check_rc_zero(['mountpoint', '-q', folder]):
        lib.utils.run(['umount', folder])


def zypper(zypper_args):
    lib.utils.run_as_root(['zypper', *zypper_args])

#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import contextlib
import grp
import ipaddress
import os
from pathlib import Path
import pwd
import re
import shutil
import socket
import sys
import subprocess

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position


def add_user_to_group(groupname, username):
    subprocess.run(['usermod', '-aG', groupname, username], check=True)


def add_user_to_group_if_exists(groupname, username):
    if group_exists(groupname):
        add_user_to_group(groupname, username)


def apk(apk_arguments):
    lib.utils.run_as_root(['apk', *apk_arguments])


def apt(apt_arguments):
    lib.utils.run_as_root(['apt', *apt_arguments])


def check_ip(ip_to_check):
    ipaddress.ip_address(ip_to_check)


def check_root():
    if os.geteuid() != 0:
        raise RuntimeError("root access is required!")


# Easier than os.walk() + shutil.chown()
def chown(new_user, folder):
    subprocess.run(['chown', '-R', f"{new_user}:{new_user}", folder], check=True)


def chpasswd(user_name, new_password):
    subprocess.run(['chpasswd'], check=True, input=f"{user_name}:{new_password}", text=True)


def chsh_fish(username):
    if not (fish := shutil.which('fish')):
        raise RuntimeError('fish not installed?')

    if fish not in Path('/etc/shells').read_text(encoding='utf-8'):
        raise RuntimeError(f"{fish} is not in /etc/shells?")

    subprocess.run(['chsh', '-s', fish, username], check=True)


def clone_env(username):
    if not (env_tmp := Path('/tmp/env')).exists():  # noqa: S108
        subprocess.run(['git', 'clone', 'https://github.com/nathanchance/env', env_tmp], check=True)
        chown(username, env_tmp)


def curl(curl_args):
    return subprocess.run(['curl', '-fLSs', *curl_args], capture_output=True, check=True).stdout


def detect_virt():
    return subprocess.run('systemd-detect-virt', capture_output=True, check=False,
                          text=True).stdout.strip()


def dnf(dnf_arguments):
    lib.utils.run_as_root(['dnf', *dnf_arguments])


def enable_tailscale():
    if not is_installed('tailscale'):
        return

    systemctl_enable(['tailscaled.service'])


def fetch_gpg_key(source_url, dest):
    # Use curl to avoid requests
    key_data = curl([source_url])

    # Dearmor if necessary
    if key_data[0:2] != b'\x99\x02':
        key_data = subprocess.run(['gpg', '--dearmor'],
                                  capture_output=True,
                                  check=True,
                                  input=key_data).stdout

    dest.write_bytes(key_data)


def get_active_ethernet_info():
    nmcli_cmd = ['nmcli', '-f', 'TYPE,NAME,DEVICE', '-t', 'connection', 'show', '--active']
    active_connections = subprocess.run(nmcli_cmd, capture_output=True, check=True,
                                        text=True).stdout.splitlines()
    for line in active_connections:
        if 'ethernet' in line:
            return line.split(':')[1:]
    return None


def get_env_root():
    if (env_root := Path(__file__).resolve().parents[2]).joinpath('README.md').exists():
        return env_root
    raise RuntimeError(f"{env_root} does not seem correct?")


def get_glibc_version():
    ldd_version_out = subprocess.run(['ldd', '--version'],
                                     capture_output=True,
                                     check=True,
                                     text=True).stdout
    ldd_version = ldd_version_out.split('\n')[0].split(' ')[-1].split('.')
    if len(ldd_version) < 3:
        ldd_version += [0]
    return tuple(int(x) for x in ldd_version)


def get_hostname():
    return socket.gethostname()


def get_ip_addr_for_intf(intf):
    ip_out = subprocess.run(['ip', 'addr'], capture_output=True, check=True,
                            text=True).stdout.split('\n')
    ip_addr = None
    for line in ip_out:
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
        pacman_packages = subprocess.run(['pacman', '-Qq'],
                                         capture_output=True,
                                         check=True,
                                         text=True).stdout
        if re.search(f"^{package_to_check}$", pacman_packages, flags=re.M):
            return True
        return False

    if shutil.which('dnf'):
        cmd = ['dnf', 'list', '--installed']
    elif shutil.which('dpkg'):
        cmd = ['dpkg', '-s']
    else:
        raise RuntimeError('Not implemented for the current package manager!')

    try:
        subprocess.run([*cmd, package_to_check], capture_output=True, check=True)
    except subprocess.CalledProcessError:
        return False
    return True


def is_lxc():
    if shutil.which('systemd-detect-virt'):
        return detect_virt() == 'lxc'
    return 'container=lxc' in Path('/proc/1/environ').read_text(encoding='utf-8')


def is_pi():
    return get_hostname() == 'raspberrypi'


def is_virtual_machine():
    if shutil.which('systemd-detect-virt'):
        return detect_virt() in ('qemu', 'kvm', 'vmware', 'microsoft', 'apple')
    return get_hostname() in ('hyperv', 'qemu', 'vmware')


def is_systemd_init():
    if not shutil.which('systemctl'):
        return False
    res = subprocess.run(['systemctl', 'is-system-running', '--quiet'], check=False)
    return res.returncode == 0


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

    subprocess.run([*nmcli_mod, 'ipv4.addresses', f"{ip_addr}/24"], check=True)
    subprocess.run([*nmcli_mod, 'ipv4.dns', ' '.join(dns)], check=True)
    subprocess.run([*nmcli_mod, 'ipv4.gateway', gateway], check=True)
    subprocess.run([*nmcli_mod, 'ipv4.method', 'manual'], check=True)
    subprocess.run(['nmcli', 'connection', 'reload'], check=True)
    subprocess.run(['nmcli', 'connection', 'down', con_name], check=True)
    subprocess.run(['nmcli', 'connection', 'up', con_name, 'ifname', intf], check=True)

    current_ip = get_ip_addr_for_intf(intf)
    if current_ip != ip_addr:
        raise RuntimeError(
            f"IP address of '{intf}' ('{current_ip}') did not change to requested IP address ('{ip_addr}')",
        )


def set_date_time():
    if is_systemd_init():
        subprocess.run(['timedatectl', 'set-timezone', 'America/Phoenix'], check=True)


def setup_initial_fish_config(username):
    fish_ver = subprocess.run(['fish', '-c', 'echo $version'],
                              capture_output=True,
                              check=True,
                              text=True).stdout.strip()
    if tuple(int(x) for x in fish_ver.split('.')) < (3, 4, 0):
        raise RuntimeError(f"{fish_ver} is less than 3.4.0!")

    user_cfg = Path('/home', username, '.config')
    fish_cfg = Path(user_cfg, 'fish/config.fish')
    if not fish_cfg.is_symlink():
        fish_cfg.parent.mkdir(mode=0o755, exist_ok=True, parents=True)
        fish_cfg_txt = (
            '# Start an ssh-agent\n'
            'if not set -q SSH_AUTH_SOCK\n'
            '    eval (ssh-agent -c)\n'
            'end\n'
            '\n'
            '# If we are in a login shell...\n'
            'status is-login\n'
            '# or Konsole, which does not use login shells by default...\n'
            'or set -q KONSOLE_VERSION\n'
            '# and we are not already in a tmux environment...\n'
            'and not set -q TMUX\n'
            '# and we have it installed,\n'
            'and command -q tmux\n'
            '# attempt to attach to a session named "main" while detaching everyone\n'
            '# else or create a new session if one does not already exist\n'
            'and tmux new-session -AD -s main\n'
            '\n'
            '# Set up user environment wrapper\n'
            'function env_setup\n'
            '    if not set -q TMUX\n'
            r"        printf '\n%bERROR: %s%b\n\n' '\033[01;31m' 'env_setup needs to be run in tmux.' '\033[0m'"
            '\n'
            '        return 1\n'
            '    end\n'
            '    if not test -d /tmp/env\n'
            '        git -C /tmp clone -q https://github.com/nathanchance/env\n'
            '    end\n'
            '    git -C /tmp/env pull -qr\n'
            '    curl -LSs https://git.io/fisher | source\n'
            '    and fisher install jorgebucaran/fisher 1>/dev/null\n'
            '    and fisher install /tmp/env/fish 1>/dev/null\n'
            '    and user_setup $argv\n'
            'end\n')
        fish_cfg.write_text(fish_cfg_txt, encoding='utf-8')
        chown(username, user_cfg)


def setup_libvirt(username):
    # Add user to libvirt group for rootless access to system sessions.
    add_user_to_group('libvirt', username)

    # Enable libvirtd systemd service to ensure it is brought up on restart.
    systemctl_enable(['libvirtd.service'])

    # Make the default network come up automatically on restart.
    subprocess.run(['virsh', 'net-autostart', 'default'], check=True)

    # Start network if it is not already started
    net_info = subprocess.run(['virsh', 'net-info', 'default'],
                              capture_output=True,
                              check=True,
                              text=True).stdout
    if re.search('^Active.*no', net_info, flags=re.M):
        subprocess.run(['virsh', 'net-start', 'default'], check=True)


def setup_mnt_nas():
    systemd_configs = Path(get_env_root(), 'configs/systemd')

    for file in ['mnt-nas.mount', 'mnt-nas.automount']:
        src = Path(systemd_configs, file)
        dst = Path('/etc/systemd/system', file)

        shutil.copyfile(src, dst)
        dst.chmod(0o644)

    systemctl_enable([file])


def setup_mnt_ssd(user_name):
    if (ssd_partition := Path('/dev/sda1')).is_block_device():
        (mnt_point := Path('/mnt/ssd')).mkdir(exist_ok=True, parents=True)
        chown(user_name, mnt_point)

        fstab, fstab_text = lib.utils.path_and_text('/etc/fstab')
        if str(mnt_point) not in fstab_text:
            partuuid = subprocess.run(['blkid', '-o', 'value', '-s', 'PARTUUID', ssd_partition],
                                      capture_output=True,
                                      check=True,
                                      text=True).stdout.strip()

            fstab_line = f"PARTUUID={partuuid}\t{mnt_point}\text4\tdefaults,noatime\t0\t1\n"

            fstab.write_text(fstab_text + fstab_line, encoding='utf-8')

        subprocess.run(['systemctl', 'daemon-reload'], check=True)
        subprocess.run(['mount', '-a'], check=True)

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
        ssh_key = subprocess.run([*cmd, 'https://github.com/nathanchance.keys'],
                                 capture_output=True,
                                 check=True).stdout
        ssh_authorized_keys.write_bytes(ssh_key)
        os.umask(old_umask)
        chown(user_name, ssh_authorized_keys.parent)


def setup_sudo_symlink():
    prefix = Path(os.environ.get('PREFIX', '/usr/local'))
    sudo_prefix = Path(prefix, 'stow/sudo')
    sudo_bin = Path(sudo_prefix, 'bin/sudo')

    sudo_bin.parent.mkdir(exist_ok=True, parents=True)
    with contextlib.suppress(FileExistsError):
        sudo_bin.symlink_to(shutil.which('doas'))
    subprocess.run(['stow', '-d', sudo_prefix.parent, '-R', sudo_prefix.name, '-v'], check=True)


def systemctl_enable(items_to_enable, now=True):
    cmd = ['systemctl', 'enable']
    if now:
        cmd.append('--now')
    cmd += items_to_enable

    subprocess.run(cmd, check=True)


def user_exists(user):
    try:
        pwd.getpwnam(user)
    except KeyError:
        return False
    return True


def zypper(zypper_args):
    lib.utils.run_as_root(['zypper', *zypper_args])

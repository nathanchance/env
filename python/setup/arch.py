#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import getpass
import os
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

HETZNER_MIRROR = 'https://mirror.hetzner.com/archlinux/$repo/os/$arch'
PACMAN_CONF = Path('/etc/pacman.conf')

UCODE_VENDOR = None
if (proc_cpuinfo := Path('/proc/cpuinfo')).exists():
    proc_cpuinfo_txt = proc_cpuinfo.read_text(encoding='utf-8')
    if vendor_match := re.search('vendor_id\t: ([a-zA-Z]+)\n', proc_cpuinfo_txt):
        if (vendor_id := vendor_match.groups()[0]) == 'AuthenticAMD':
            UCODE_VENDOR = 'amd'
        elif vendor_id == 'GenuineIntel':
            UCODE_VENDOR = 'intel'


def add_hetzner_mirror_to_repos(config):
    if HETZNER_MIRROR in config:
        return config

    search = ']\nInclude = /etc/pacman.d/mirrorlist\n'
    replace = search.replace(']\n', f"]\nServer = {HETZNER_MIRROR}\n")
    return config.replace(search, replace)


def add_mods_to_mkinitcpio(modules):
    mkinitcpio_conf, conf_text = lib.utils.path_and_text('/etc/mkinitcpio.conf')

    if not (match := re.search(r'^MODULES=\((.*)\)$', conf_text, flags=re.M)):
        raise RuntimeError(f"Could not find MODULES line in {mkinitcpio_conf}!")

    conf_mods = set(match.groups()[0].split(' '))
    for module in modules:
        conf_mods.add(module)
    new_conf_line = f"MODULES=({' '.join(sorted(conf_mods)).strip()})"

    conf_text = conf_text.replace(match.group(0), new_conf_line)
    mkinitcpio_conf.write_text(conf_text, encoding='utf-8')

    subprocess.run(['mkinitcpio', '-P'], check=True)


def adjust_gnome_power_settings():
    if not lib.setup.user_exists('gdm'):
        return

    gdm_cmd = [
        'doas', '-u', 'gdm',
        'dbus-launch', 'gsettings', 'set',
        'org.gnome.settings-daemon.plugins.power',
        'sleep-inactive-ac-type', 'nothing',
    ]  # yapf: disable
    subprocess.run(gdm_cmd, check=True)


def configure_boot_entries(init=True, conf='linux.conf'):
    # Not using systemd-boot, bail out
    if not (boot_entries := Path('/boot/loader/entries')).exists():
        return

    # If we already set up the configuration, no need to go through all this
    # again, unless we are not doing the initial configuration
    if (linux_conf := Path(boot_entries, conf)).exists() and init:
        return

    # Find the configuration with a regex in case we set up another linux.conf
    if init:
        linux_re = re.compile(r'[0-9a-z_]+linux\.conf')
        linux_confs = [item for item in boot_entries.iterdir() if linux_re.search(item.name)]
        if (num := len(linux_confs)) != 1:
            raise RuntimeError(f"Number of possible linux.conf entries ('{num}') is unexpected!")

        # Move the configuration created by archinstall to a deterministic name
        linux_confs[0].replace(linux_conf)

    linux_conf_text = linux_conf.read_text(encoding='utf-8')
    if not (match := re.search('^options (.*)$', linux_conf_text, flags=re.M)):
        raise RuntimeError(f"Could not find 'options' line in {linux_conf}?")
    current_options_str = match.groups()[0]
    current_options = {opt for elem in current_options_str.split(' ') if (opt := elem.strip())}
    new_options = current_options.copy()

    # Add 'console=' if necessary (when connected by serial console in a
    # virtual machine)
    if lib.setup.is_virtual_machine() and 'DISPLAY' not in os.environ:
        new_options.add('console=ttyS0,115200n8')

    # Enable the performance governor
    new_options.add('cpufreq.default_governor=performance')

    # Mitigate SMT RSB vulnerability
    new_options.add('kvm.mitigate_smt_rsb=1')

    if current_options != new_options:
        new_text = linux_conf_text.replace(current_options_str, ' '.join(sorted(new_options)))
        linux_conf.write_text(new_text, encoding='utf-8')

    # Ensure that the new configuration is the default on the machine.
    subprocess.run(['bootctl', 'set-default', linux_conf.name], check=True)


def configure_networking():
    hostname = lib.setup.get_hostname()

    ips = {
        'asus-intel-core-4210U': '192.168.4.137',
        'asus-intel-core-11700': '192.168.4.189',
        'beelink-intel-n100': '192.168.4.190',
        'hp-amd-ryzen-4300G': '192.168.4.177',
        'thelio-3990X': '192.168.4.188',
    }

    if hostname not in ips:
        return

    lib.setup.setup_static_ip(ips[hostname])
    lib.setup.setup_mnt_nas()


def enable_reflector():
    if not lib.setup.is_installed('reflector'):
        return

    # If on a Hetzner server, we should use a closer set of mirrors
    countries = 'Finland,Germany' if is_hetzner() else 'United States'

    reflector_args = [
        f'--country "{countries}"',
        '--latest 15',
        '--protocol https',
        '--save /etc/pacman.d/mirrorlist',
        '--sort rate',
    ]  # yapf: disable
    conf_text = '\n'.join(reflector_args) + '\n'
    Path('/etc/xdg/reflector/reflector.conf').write_text(conf_text, encoding='utf-8')

    reflector_drop_in = Path('/etc/systemd/system/reflector.timer.d/00-twice-daily.conf')
    reflector_drop_in_text = ('[Unit]\n'
                              'Description=Refresh Pacman mirrorlist twice daily with Reflector.\n'
                              '\n'
                              '[Timer]\n'
                              'OnCalendar=\n'
                              'OnCalendar=*-*-* 06,18:00:00\n'
                              'RandomizedDelaySec=1h\n')
    reflector_drop_in.parent.mkdir(exist_ok=True)
    reflector_drop_in.write_text(reflector_drop_in_text, encoding='utf-8')
    reflector_drop_in.chmod(0o644)
    subprocess.run(['systemctl', 'daemon-reload'], check=True)

    lib.setup.systemctl_enable(['reflector.timer'])

    # If we are in a virtual machine, we should enable reflector so that it
    # runs every time it is started up, in case it is not a constantly running
    # virtual machine, which means the timer above will not do much.
    if lib.setup.is_virtual_machine():
        lib.setup.systemctl_enable(['reflector.service'])


# For archinstall, which causes ^M in /etc/fstab
def fix_fstab():
    subprocess.run(['dos2unix', '/etc/fstab'], check=True)


def is_hetzner():
    # pacman_settings() ensures this is a permanent addition
    return HETZNER_MIRROR in PACMAN_CONF.read_text(encoding='utf-8')


def pacman_install(subargs):
    lib.setup.pacman(['-S', '--noconfirm', *subargs])


def pacman_install_packages():
    packages = [
        # Administration tools
        'btop',
        'fastfetch',
        'iputils',
        'kexec-tools',
        'modprobed-db',
        'reflector',

        # b4
        'b4',
        'git-filter-repo',
        'python-dkim',
        'patatt',

        # Container tools
        'aardvark-dns',
        'buildah',
        'catatonit',
        'distrobox',
        'netavark',
        'podman',

        # continuous-integration2 (generate.sh)
        'python-yaml',

        # Development tools
        'dos2unix',
        'hyperfine',
        'patch',
        'ruff',
        'tuxmake',
        'vim',
        'vim-spell-en',

        # Disk management utilities
        'nfs-utils',
        'nvme-cli',
        'parted',
        'smartmontools',

        # Downloading and extracting utilities
        'ca-certificates',
        'curl',
        'unzip',
        'wget',

        # Email
        'mutt',

        # env
        'fish',
        'fzf',
        'hugo',
        'jq',
        'shfmt',
        'stow',
        'tmux',
        'tmuxp',
        'zoxide',

        # git
        'git',
        'git-delta',
        'github-cli',
        'perl-authen-sasl',
        'perl-mime-tools',
        'perl-net-smtp-ssl',
        'repo',

        # Miscellaneous
        'libxkbcommon',
        'lm_sensors',
        'man-db',
        'which',

        # Nicer versions of certain GNU utilities
        'bat',
        'bat-extras',
        'diskus',
        'duf',
        'dust',
        'eza',
        'fd',
        'ripgrep',

        # Package management
        'pacman-contrib',

        # Remote work
        'mosh',
        'openssh',
    ]  # yapf: disable

    if UCODE_VENDOR:
        packages.append(f"{UCODE_VENDOR}-ucode")

    if 'DISPLAY' in os.environ:
        packages += [
            # Chat applications
            'discord',
            'telegram-desktop',

            # Clipboard in terminal
            'wl-clipboard',

            # Fonts
            'cantarell-fonts',
            'ttc-iosevka-ss08',

            # Streaming
            'obs-studio',

            # Web browing
            'firefox',

            # Video viewing
            'vlc',
        ]  # yapf: disable

    # https://wiki.archlinux.org/title/VMware/Install_Arch_Linux_as_a_guest
    if lib.setup.get_hostname() == 'vmware':
        # All of these are needed for autofit
        packages += [
            'gtkmm',
            'gtk2',
            'open-vm-tools',
        ]  # yapf: disable

    # Install libvirt and virt-install for easy management of VMs on
    # Equinix Metal servers; iptables-nft is also needed for networking but
    # that will be installed later to avoid potential issues with replacing
    # iptables.
    if lib.setup.is_equinix() or lib.setup.is_virtual_machine():
        packages += [
            'dmidecode',
            'dnsmasq',
            'libvirt',
            'qemu-desktop',
            'virt-install',
        ]  # yapf: disable

    if lib.setup.is_virtual_machine():
        packages.append('devtools')
    else:
        packages.append('tailscale')

    # Update and install packages
    pacman_install(['--needed', *packages])

    # Explicitly reinstall shadow to fix permissions with newuidmap
    pacman_install(['shadow'])


def pacman_key_setup():
    subprocess.run(['pacman-key', '--init'], check=True)
    subprocess.run(['pacman-key', '--populate', 'archlinux'], check=True)


def pacman_settings(dryrun=False):
    # The Hetzner mirror will be in mirrorlist if this is the first time
    # running pacman_setting() after installimage.
    hetzner_mirror_in_mirrorlist = (mirrorlist := Path('/etc/pacman.d/mirrorlist')).exists() and \
                                   HETZNER_MIRROR in mirrorlist.read_text(encoding='utf-8')
    # The Hetzner mirror will be in pacman.conf if pacman_settings() has
    # already be run. This needs to be checked before we blow away pacman.conf
    # with pacman.conf.pacnew below.
    hetzner_mirror_in_pacman_conf = is_hetzner()

    conf_text = None
    # Handle .pacnew file
    new_pacman_conf = PACMAN_CONF.with_suffix(f"{PACMAN_CONF.suffix}.pacnew")
    if new_pacman_conf.exists():
        if dryrun:
            conf_text = new_pacman_conf.read_text(encoding='utf-8')
        else:
            new_pacman_conf.rename(PACMAN_CONF)
    if not conf_text:
        conf_text = PACMAN_CONF.read_text(encoding='utf-8')

    conf_text = uncomment_pacman_option(conf_text, 'Color')
    conf_text = uncomment_pacman_option(conf_text, 'VerbosePkgLists')
    conf_text = uncomment_pacman_option(conf_text, 'ParallelDownloads', 5, 7)

    # If mirrorlist was generated with "installimage" from Hetzner, add the
    # Hetzner mirror to pacman.conf directly so that mirrorlist can be
    # generated with reflector but the Hetzner mirror can always have priority:
    # https://wiki.archlinux.org/title/Mirrors#Enabling_a_specific_mirror
    if hetzner_mirror_in_mirrorlist or hetzner_mirror_in_pacman_conf:
        conf_text = add_hetzner_mirror_to_repos(conf_text)

    if '[nathan]' not in conf_text:
        conf_text += (
            '\n'
            '[nathan]\n'
            'SigLevel = Optional TrustAll\n'
            'Server = https://raw.githubusercontent.com/nathanchance/arch-repo/main/$arch\n')

    lib.utils.print_or_write_text(PACMAN_CONF, conf_text, dryrun)


def pacman_update():
    pacman_install(['-yyu'])


def parse_arguments():
    parser = ArgumentParser(description='Set up an Arch Linux installation')

    parser.add_argument('-p', '--password', help='User password')

    return parser.parse_args()


def prechecks():
    lib.setup.check_root()


def setup_doas(username):
    # sudo is a little bit more functional. Keep it in virtual machines.
    if lib.setup.is_virtual_machine():
        return

    doas_conf = Path('/etc/doas.conf')
    doas_conf_text = ('# Allow me to be root for 5 minutes at a time\n'
                      f"permit persist {username} as root\n"
                      '# Pass through environment variables to podman\n'
                      f"permit keepenv persist {username} cmd podman\n"
                      '# Allow me to update or install packages without a password\n'
                      f"permit nopass {username} cmd pacman\n"
                      '# Do not require root to put in a password (makes no sense)\n'
                      'permit nopass root\n')
    doas_conf.write_text(doas_conf_text, encoding='utf-8')

    doas_pam = Path('/etc/pam.d/doas')
    doas_pam_text = ('#%PAM-1.0\n'
                     'auth        include     system-auth\n'
                     'account     include     system-auth\n'
                     'session     include     system-auth\n')
    doas_pam.write_text(doas_pam_text, encoding='utf-8')

    lib.setup.remove_if_installed('sudo')
    pacman_install(['opendoas-sudo'])


def setup_libvirt(username):
    if not lib.setup.is_installed('libvirt'):
        return

    # The default network requires iptables-nft but iptables is installed by
    # default due to systemd. Replace iptables with iptables-nft
    # non-interactively:
    # https://unix.stackexchange.com/questions/274727/how-to-force-pacman-to-answer-yes-to-all-questions
    pacman_install(['--ask', '4', 'iptables-nft'])

    lib.setup.setup_libvirt(username)

    # For domains with KVM to autostart, the kvm_<vendor> module needs to be
    # loaded during init.
    cpuinfo = Path('/proc/cpuinfo').read_text(encoding='utf-8')
    if 'svm' in cpuinfo:
        add_mods_to_mkinitcpio(['kvm_amd'])
    elif 'vmx' in cpuinfo:
        add_mods_to_mkinitcpio(['kvm_intel'])


def setup_user(username, userpass):
    if lib.setup.user_exists(username):
        lib.setup.chsh_fish(username)
        lib.setup.add_user_to_group('uucp', username)
    else:
        fish = Path(shutil.which('fish')).resolve()
        subprocess.run(['useradd', '-G', 'wheel,uucp', '-m', '-s', fish, username], check=True)

        lib.setup.chpasswd(username, userpass)

    lib.setup.setup_ssh_authorized_keys(username)


def uncomment_pacman_option(conf, option, old_value=None, new_value=None):
    if old_value and new_value:
        return re.sub(f"^#{option} = {old_value}", f"{option} = {new_value}", conf, flags=re.M)
    if old_value or new_value:
        raise RuntimeError(f"old_value is {old_value} and new_value is {new_value}??")
    return re.sub(f"^#{option}", option, conf, flags=re.M)


def vmware_adjustments():
    if lib.setup.get_hostname() != 'vmware':
        return

    # https://wiki.archlinux.org/title/VMware/Install_Arch_Linux_as_a_guest#In-kernel_drivers
    vmware_mods = [
        'vsock',
        'vmw_vsock_vmci_transport',
        'vmw_balloon',
        'vmw_vmci',
        'vmwgfx',
    ]  # yapf: disable
    add_mods_to_mkinitcpio(vmware_mods)

    # https://wiki.archlinux.org/title/VMware/Install_Arch_Linux_as_a_guest#Installation
    lib.setup.systemctl_enable(['vmtoolsd.service', 'vmware-vmblock-fuse.service'], now=False)


if __name__ == '__main__':
    user = lib.setup.get_user()
    arguments = parse_arguments()
    # Most Arch Linux installs will be set up with archinstall, which sets
    # up the user account/password and root password, so the 'password'
    # argument is only required when the user is going to be created by
    # the script.
    if not (password := arguments.password) and not lib.setup.user_exists(user):
        password = getpass.getpass(prompt='Password for Arch Linux user account: ')

    prechecks()
    # pacman_settings() should always be run first so that is_hetzner() always works
    pacman_settings()
    configure_boot_entries()
    pacman_key_setup()
    pacman_update()
    pacman_install_packages()
    setup_doas(user)
    setup_user(user, password)
    lib.setup.clone_env(user)
    lib.setup.podman_setup(user)
    vmware_adjustments()
    setup_libvirt(user)
    configure_networking()
    enable_reflector()
    adjust_gnome_power_settings()
    lib.setup.systemctl_enable(['sshd.service', 'paccache.timer'])
    lib.setup.enable_tailscale()
    fix_fstab()
    lib.setup.set_date_time()
    lib.setup.setup_initial_fish_config(user)

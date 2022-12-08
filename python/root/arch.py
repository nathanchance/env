#!/usr/bin/env python3

from argparse import ArgumentParser
import os
from pathlib import Path
import re
import shutil
import subprocess

import lib_root


def add_mods_to_mkinitcpio(modules):
    mkinitcpio_conf = Path('/etc/mkinitcpio.conf')
    conf_text = mkinitcpio_conf.read_text(encoding='utf-8')

    orig_conf_line = re.search(r'^MODULES=\(.*\)$', conf_text, flags=re.M).group(0)
    orig_conf_val = re.search(r'\(.*\)', orig_conf_line).group(0).replace('(', '').replace(')', '')
    new_conf_val = f"{orig_conf_val} {' '.join(modules)}"
    new_conf_line = f"MODULES=({new_conf_val.strip()})"

    conf_text = re.sub(re.escape(orig_conf_line), new_conf_line, conf_text)
    mkinitcpio_conf.write_text(conf_text, encoding='utf-8')

    subprocess.run(['mkinitcpio', '-P'], check=True)


def adjust_gnome_power_settings():
    if not lib_root.user_exists('gdm'):
        return

    doas_conf = Path('/etc/doas.conf')
    doas_conf_text = doas_conf.read_text(encoding='utf-8')

    doas_conf.write_text(doas_conf_text + 'permit nopass root as gdm\n', encoding='utf-8')
    gdm_cmd = [
        'doas', '-u', 'gdm', 'dbus-launch gsettings', 'set',
        'org.gnome.settings-daemon.plugins.power', 'sleep-inactive-ac-type', 'nothing'
    ]
    subprocess.run(gdm_cmd, check=True)

    doas_conf.write_text(doas_conf_text, encoding='utf-8')


def configure_networking():
    hostname = lib_root.get_hostname()

    ips = {
        'asus-intel-core-4210U': '192.168.4.137',
        'asus-intel-core-11700': '192.168.4.189',
        'hp-amd-ryzen-4300G': '192.168.4.177',
        'thelio-3990X': '192.168.4.188',
    }

    if hostname not in ips:
        return

    lib_root.setup_static_ip(ips[hostname])
    lib_root.setup_mnt_nas()


def enable_reflector():
    if not lib_root.is_installed('reflector'):
        return

    reflector_args = [
        '--country "United States"',
        '--latest 15',
        '--protocol https',
        '--save /etc/pacman.d/mirrorlist',
        '--sort rate'
    ]  # yapf: disable
    conf_text = '\n'.join(reflector_args) + '\n'
    Path('/etc/xdg/reflector/reflector.conf').write_text(conf_text, encoding='utf-8')
    lib_root.systemctl_enable([f"reflector.{x}" for x in ['service', 'timer']])


# For archinstall, which causes ^M in /etc/fstab
def fix_fstab():
    subprocess.run(['dos2unix', '/etc/fstab'], check=True)


def pacman_install(subargs):
    lib_root.pacman(['-S', '--noconfirm'] + subargs)


def pacman_install_packages():
    packages = [
        # Administration tools
        'btop',
        'iputils',
        'modprobed-db',
        'neofetch',
        'reflector',

        # b4
        'b4',
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
        'exa',
        'fd',
        'ripgrep',

        # Package management
        'pacman-contrib',

        # Remote work
        'mosh',
        'openssh'
    ]  # yapf: disable

    if 'DISPLAY' in os.environ:
        packages += [
            # Chat applications
            'discord',
            'telegram-desktop',

            # Fonts
            'cantarell-fonts',
            'ttc-iosevka-ss08',

            # Streaming
            'obs-studio',

            # Web browing
            'firefox',

            # Video viewing
            'vlc'
        ]  # yapf: disable

    # https://wiki.archlinux.org/title/VMware/Install_Arch_Linux_as_a_guest
    if lib_root.get_hostname() == 'vmware':
        # All of these are needed for autofit
        packages += [
            'gtkmm',
            'gtk2',
            'open-vm-tools'
        ]  # yapf: disable

    # Install libvirt and virt-install for easy management of VMs on
    # Equinix Metal servers; iptables-nft is also needed for networking but
    # that will be installed later to avoid potential issues with replacing
    # iptables.
    if lib_root.is_equinix() or lib_root.is_virtual_machine():
        packages += [
            'dmidecode',
            'dnsmasq',
            'libvirt',
            'qemu-desktop',
            'virt-install'
        ]  # yapf: disable

    if lib_root.is_virtual_machine():
        packages += ['devtools']
    else:
        packages += ['tailscale']

    # Update and install packages
    pacman_install(['--needed'] + packages)

    # Explicitly reinstall shadow to fix permissions with newuidmap
    pacman_install(['shadow'])


def pacman_key_setup():
    subprocess.run(['pacman-key', '--init'], check=True)
    subprocess.run(['pacman-key', '--populate', 'archlinux'], check=True)


def pacman_settings():
    pacman_conf = Path('/etc/pacman.conf')

    # Handle .pacnew file
    pacman_confnew = pacman_conf.with_suffix(f"{pacman_conf.suffix}.pacnew")
    if pacman_confnew.exists():
        pacman_confnew.rename(pacman_conf)

    conf_text = pacman_conf.read_text(encoding='utf-8')

    conf_text = uncomment_pacman_option(conf_text, 'Color')
    conf_text = uncomment_pacman_option(conf_text, 'VerbosePkgLists')
    conf_text = uncomment_pacman_option(conf_text, 'ParallelDownloads', 5, 7)

    if not re.search('nathan', conf_text):
        conf_text += (
            '\n'
            '[nathan]\n'
            'SigLevel = Optional TrustAll\n'
            'Server = https://raw.githubusercontent.com/nathanchance/arch-repo/main/$arch\n')

    pacman_conf.write_text(conf_text, encoding='utf-8')


def pacman_update():
    pacman_install(['-yyu'])


def parse_arguments(username):
    parser = ArgumentParser(description='Set up an Arch Linux installation')

    # Most Arch Linux installs will be set up with archinstall, which sets
    # up the user account/password and root password, so the 'password'
    # argument is only required when the user is going to be created by
    # the script.
    password_args_required = not lib_root.user_exists(username)
    parser.add_argument('-p',
                        '--password',
                        help='User password (only required if user does not exist already)',
                        required=password_args_required)

    return parser.parse_args()


def prechecks():
    lib_root.check_root()


def setup_doas(username):
    # sudo is a little bit more functional. Keep it in virtual machines.
    if lib_root.is_virtual_machine():
        return

    doas_conf = Path('/etc/doas.conf')
    doas_conf_text = ('# Allow me to be root for 5 minutes at a time\n'
                      f"permit persist {username} as root\n"
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

    lib_root.remove_if_installed('sudo')
    pacman_install(['opendoas-sudo'])


def setup_libvirt(username):
    if not lib_root.is_installed('libvirt'):
        return

    # The default network requires iptables-nft but iptables is installed by
    # default due to systemd. Replace iptables with iptables-nft
    # non-interactively:
    # https://unix.stackexchange.com/questions/274727/how-to-force-pacman-to-answer-yes-to-all-questions
    pacman_install(['--ask', '4', 'iptables-nft'])

    lib_root.setup_libvirt(username)

    # For domains with KVM to autostart, the kvm_<vendor> module needs to be
    # loaded during init.
    cpuinfo = Path('/proc/cpuinfo').read_text(encoding='utf-8')
    if re.search('svm', cpuinfo):
        add_mods_to_mkinitcpio(['kvm_amd'])
    elif re.search('vmx', cpuinfo):
        add_mods_to_mkinitcpio(['kvm_intel'])


def setup_user(username, password):
    if lib_root.user_exists(username):
        lib_root.chsh_fish(username)
        lib_root.add_user_to_group('uucp', username)
    else:
        fish = Path(shutil.which('fish')).resolve()
        subprocess.run(['useradd', '-G', 'wheel,uucp', '-m', '-s', fish, username], check=True)

        lib_root.chpasswd(username, password)


def uncomment_pacman_option(conf, option, old_value=None, new_value=None):
    if old_value and new_value:
        return re.sub(f"^#{option} = {old_value}", f"{option} = {new_value}", conf, flags=re.M)
    if old_value or new_value:
        raise Exception(f"old_value is {old_value} and new_value is {new_value}??")
    return re.sub(f"^#{option}", option, conf, flags=re.M)


def vmware_adjustments():
    if lib_root.get_hostname() != 'vmware':
        return

    # https://wiki.archlinux.org/title/VMware/Install_Arch_Linux_as_a_guest#In-kernel_drivers
    vmware_mods = [
        'vsock',
        'vmw_vsock_vmci_transport',
        'vmw_balloon',
        'vmw_vmci',
        'vmwgfx'
    ]  # yapf: disable
    add_mods_to_mkinitcpio(vmware_mods)

    # https://wiki.archlinux.org/title/VMware/Install_Arch_Linux_as_a_guest#Installation
    lib_root.systemctl_enable(['vmtoolsd.service', 'vmware-vmblock-fuse.service'], now=False)


if __name__ == '__main__':
    user = lib_root.get_user()
    arguments = parse_arguments(user)

    prechecks()
    pacman_settings()
    pacman_key_setup()
    pacman_update()
    pacman_install_packages()
    setup_doas(user)
    setup_user(user, arguments.password)
    lib_root.clone_env(user)
    lib_root.podman_setup(user)
    vmware_adjustments()
    setup_libvirt(user)
    configure_networking()
    enable_reflector()
    lib_root.systemctl_enable(['sshd.service'])
    lib_root.enable_tailscale()
    fix_fstab()
    lib_root.set_date_time()
    lib_root.setup_initial_fish_config(user)
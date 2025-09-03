#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import base64
from collections import UserDict
import getpass
import os
from pathlib import Path
import re
import shutil
import sys
from tempfile import TemporaryDirectory

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils
# pylint: enable=wrong-import-position

EDID_1280_1024 = b'BAAAACAAAAAFAAAAR05VAAIAAcAEAAAAAAAAAAAAAAABAAHABAAAAAEAAAAAAAAAAQEBAQEBMCoAmFEAKkAwcBMAvGMRAAAeAAAA/wBMaW51eCAjMAogICAgAAAA/QA7PT5ACwAKICAgICAgAAAA/ABMaW51eCBTWEdBCiAgAC4='
HETZNER_MIRROR = 'https://mirror.hetzner.com/archlinux/$repo/os/$arch'
PACMAN_CONF = Path('/etc/pacman.conf')

CPU_VENDOR = None
if (proc_cpuinfo := Path('/proc/cpuinfo')).exists():
    proc_cpuinfo_txt = proc_cpuinfo.read_text(encoding='utf-8')
    if vendor_match := re.search('vendor_id\t: ([a-zA-Z]+)\n', proc_cpuinfo_txt):
        if (vendor_id := vendor_match.groups()[0]) == 'AuthenticAMD':
            CPU_VENDOR = 'amd'
        elif vendor_id == 'GenuineIntel':
            CPU_VENDOR = 'intel'


class CmdlineOptions(UserDict):

    def __init__(self, initial_argument):
        if isinstance(initial_argument, str):
            super().__init__()

            for item in initial_argument.split(' '):
                if item := item.strip():
                    key, value = item.split('=', maxsplit=1) if '=' in item else (item, None)
                    self.data[key] = value
        else:
            super().__init__(initial_argument)

    def __str__(self):
        return ' '.join(
            sorted(f"{key}={value}" if value else key for key, value in self.data.items()))


class MkinitcpioConf(UserDict):

    def __init__(self, init_arg='', path=None):
        super().__init__()

        self.path = path if path else Path('/etc/mkinitcpio.conf')

        if init_arg and isinstance(init_arg, str):
            self.text = init_arg
        else:
            self.text = self.path.read_text(encoding='utf-8')
        self._reload_data_from_text()

    def _generate_new_text(self):
        new_text = self.text

        for var, vals in self.data.items():
            new_val_str = ' '.join(str(val) for val in sorted(vals))
            if self.orig[var] != (new_str := f"{var}=({new_val_str})"):
                new_text = new_text.replace(self.orig[var], new_str)

        return new_text

    def _reload_data_from_file(self):
        self.text = self.path.read_text(encoding='utf-8')
        self._reload_data_from_text()

    def _reload_data_from_text(self):
        if not (matches := re.findall(r'^([A-Z]+)=\((.*)\)$', self.text, flags=re.M)):
            raise RuntimeError(f"Cannot find any variables in {self.text}?")

        self.orig = {var: f"{var}=({val})" for var, val in matches}
        self.data = {
            var: set(map(Path if var == 'FILES' else str, val.split()))
            for var, val in matches
        }

    def update_if_necessary(self):
        if (new_text := self._generate_new_text()) != self.text:
            self.path.write_text(new_text, encoding='utf-8')
            self._reload_data_from_file()

            lib.utils.run(['mkinitcpio', '-P'])


def add_hetzner_mirror_to_repos(config):
    if HETZNER_MIRROR in config:
        return config

    search = ']\nInclude = /etc/pacman.d/mirrorlist\n'
    replace = search.replace(']\n', f"]\nServer = {HETZNER_MIRROR}\n")
    return config.replace(search, replace)


def adjust_esp_mountpoint(fstab, dryrun=False):
    if (boot_esp := '/boot/efi') not in fstab:
        return

    root_esp = '/efi'

    # umount /boot/efi
    if dryrun:
        print(f"$ umount {boot_esp}\n")
    else:
        lib.setup.umount_gracefully(boot_esp)

    # Replace '/boot/efi' with '/efi' in /etc/stab
    fstab[root_esp] = fstab[boot_esp]
    del fstab[boot_esp]

    # Update /etc/fstab
    fstab.write(dryrun=dryrun)

    # Mount /efi
    lib.utils.print_or_run_cmd(['mount', '--mkdir', root_esp], dryrun)


def adjust_gnome_power_settings():
    if not lib.setup.user_exists('gdm'):
        return

    gdm_cmd = [
        'doas', '-u', 'gdm',
        'dbus-launch', 'gsettings', 'set',
        'org.gnome.settings-daemon.plugins.power',
        'sleep-inactive-ac-type', 'nothing',
    ]  # yapf: disable
    lib.utils.run(gdm_cmd)


def can_use_amd_pstate():
    return CPU_VENDOR == 'amd' and list(Path('/sys/devices/system/cpu').glob('cpu*/acpi_cppc'))


def configure_amd_pstate():
    if not can_use_amd_pstate():
        return

    # Implement amd_pstate_acpi_pm_profile_server() and
    # amd_pstate_acpi_pm_profile_undefined() from drivers/cpufreq/amd-pstate.c
    # to avoid attempting to configure amd_pstate when it is not possible.
    pm_profile = int(Path('/sys/firmware/acpi/pm_profile').read_text(encoding='utf-8').strip())
    if pm_profile in (0, 4, 5, 7) or pm_profile >= 9:
        return

    # WORK IN PROGRESS


def configure_systemd_boot(init=True, conf='linux.conf'):
    # Not using systemd-boot, nothing to configure
    if not lib.setup.using_systemd_boot():
        return

    # Ensure we update systemd-boot with systemd upgrades:
    # https://wiki.archlinux.org/title/Systemd-boot#systemd_service
    if not (systemd_boot_update_hook := Path('/etc/pacman.d/hooks/95-systemd-boot.hook')).exists():
        if not (pacman_hooks := systemd_boot_update_hook.parent).exists():
            pacman_hooks.mkdir()
            pacman_hooks.chmod(0o755)
        systemd_boot_update_hook_txt = (
            '[Trigger]\n'
            'Type = Package\n'
            'Operation = Upgrade\n'
            'Target = systemd\n'
            '\n'
            '[Action]\n'
            'Description = Gracefully upgrading systemd-boot...\n'
            'When = PostTransaction\n'
            'Exec = /usr/bin/systemctl restart systemd-boot-update.service\n')
        systemd_boot_update_hook.write_text(systemd_boot_update_hook_txt, encoding='utf-8')
        systemd_boot_update_hook.chmod(0o644)

    # If we already set up the configuration (either via this function or
    # installimage_adjustments(), depending on what setup was installed prior
    # to running this setup), no need to go through all this again, unless we
    # are not doing the initial configuration
    if (linux_conf := (boot_entries := Path('/boot/loader/entries')) / conf).exists() and init:
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
    original_options_str = match.groups()[0]
    current_options = CmdlineOptions(original_options_str)
    new_options = current_options | get_cmdline_additions()

    if current_options != new_options:
        new_text = linux_conf_text.replace(original_options_str, str(new_options))
        linux_conf.write_text(new_text, encoding='utf-8')

    # Ensure that the new configuration is the default on the machine.
    lib.utils.run(['bootctl', 'set-default', linux_conf.name])


def convert_boot_to_xbootldr(fstab, dryrun):
    # If '/boot' is a 'vfat' filesystem, it means we have already done this
    # transformation.
    if fstab[(boot := '/boot')].type == 'vfat':
        return

    # umount /boot
    if dryrun:
        print(f"$ umount {boot}\n")
    else:
        lib.setup.umount_gracefully(boot)

    # Wipe all signatures of the block device
    if not (part_path := fstab[boot].get_dev()):
        raise RuntimeError(f"Cannot find /dev for {boot}?")
    lib.utils.print_or_run_cmd(['wipefs', '-af', part_path], dryrun)

    # Use sfdisk to set /boot's partition type to "Linux extended boot"
    if part_path.name.startswith('nvme'):
        block, part = part_path.name.rsplit('p', maxsplit=1)
    elif part_path.name.startswith(('sda', 'vda')):
        block, part = part_path.name[0:-1], part_path.name[-1]
    else:
        raise RuntimeError(f"Cannot handle {part_path}?")
    sfdisk_cmd = [
        'sfdisk',
        '--part-type',
        part_path.with_name(block),
        part,
        'bc13c2ff-59e6-4262-a352-b275fd6f7172',
    ]
    lib.utils.print_or_run_cmd(sfdisk_cmd, dryrun)

    # Format the partition to vFAT, which is guaranteed to allow
    # systemd-boot to read the kernel and initramfs.
    lib.utils.print_or_run_cmd(['mkfs', '-t', 'vfat', part_path], dryrun)

    # Update fstab with the new UUID and filesystem type
    if dryrun:
        uuid = 'ABCD-1234'
    else:
        for item in Path('/dev/disk/by-uuid').iterdir():
            if item.resolve() == part_path:
                uuid = item.name
                break
        else:
            raise RuntimeError(f"Could not find new UUID for {part_path}?")
    fstab[boot].fs = f"UUID={uuid}"
    fstab[boot].type = 'vfat'
    fstab[boot].opts = lib.setup.Fstab.ARCH_VFAT_OPTS
    fstab.write(dryrun=dryrun)

    # Bring /boot online
    lib.utils.print_or_run_cmd(['mount', boot], dryrun)

    # Reinstall linux package, as we wiped /boot
    if dryrun:
        print('$ pacman -S --noconfirm linux\n')
    else:
        pacman_install(['linux'])


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

    reflector_drop_in = Path('/etc/systemd/system/reflector.timer.d/00-schedule.conf')
    reflector_drop_in_text = ('[Unit]\n'
                              'Description=Refresh Pacman mirrorlist with Reflector.\n'
                              '\n'
                              '[Timer]\n'
                              'OnCalendar=\n'
                              'OnUnitInactiveSec=18h\n'
                              'OnCalendar=*-*-* 06,18:00:00\n'
                              'RandomizedDelaySec=1h\n')
    reflector_drop_in.parent.mkdir(exist_ok=True)
    reflector_drop_in.write_text(reflector_drop_in_text, encoding='utf-8')
    reflector_drop_in.chmod(0o644)
    lib.utils.run(['systemctl', 'daemon-reload'])

    lib.setup.systemctl_enable('reflector.timer')


# For archinstall, which causes ^M in /etc/fstab
def fix_fstab():
    lib.utils.run(['dos2unix', '/etc/fstab'])


def get_cmdline_additions():
    module_blacklist = []
    options = CmdlineOptions({
        # Mitigate SMT RSB vulnerability
        'kvm.mitigate_smt_rsb': '1',
    })
    if can_use_amd_pstate():
        options['amd_pstate'] = 'active'
    else:
        options['cpufreq.default_governor'] = 'performance'
    # Add 'console=' if necessary (when connected by serial console in a
    # virtual machine)
    if lib.setup.is_virtual_machine() and 'DISPLAY' not in os.environ:
        options['console'] = 'ttyS0,115200n8'
    # The AE4DMA driver does not agree with my Hetzner machine and it is not
    # obvious why because there is no serial access by default. Just blacklist
    # it.
    lspci_lines = lib.utils.chronic(['lspci', '-nn']).stdout.splitlines()
    ae4dma_pci_matches = ('14c8', '14dc', '149b')
    if any(line for line in lspci_lines if any(x in line for x in ae4dma_pci_matches)):
        module_blacklist.append('ae4dma')
    if module_blacklist:
        options['module_blacklist'] = ','.join(module_blacklist)
    return options


def installimage_adjustments(mkinitcpio_conf, conf='linux.conf', dryrun=False):
    # If we are not on a Hetzner machine, do not try to execute anything here,
    # as it was written with primitives to be safe but it is better to be safer
    # than sorry.
    if not (is_hetzner() or dryrun):
        lib.utils.print_yellow(
            'Running installimage_adjustments() requires a Hetzner machine, skipping...')
        return

    # Get the current fstab for adjustments
    fstab = lib.setup.Fstab()
    fstab.adjust_for_hetzner()
    fstab.write(dryrun=dryrun)

    # Hetzner may have added edid_firmware for the drm module but on newer
    # kernels, this is not available:
    # https://git.kernel.org/linus/89ac522d4507126d353834973ddbbf7b6acfdeef
    # Install tools/edid/1280x1024.bin at the parent of that change from a
    # base64 encoded bytes string to ensure it is always available.
    if (modprobe_conf := Path('/etc/modprobe.d/hetzner.conf')).exists():
        modprobe_conf_txt = modprobe_conf.read_text(encoding='utf-8')

        modprobe_conf_search = 'edid/1280x1024.bin'
        firmware_location = Path('/usr/lib/firmware', modprobe_conf_search)

        if modprobe_conf_search in modprobe_conf_txt and not dryrun:
            if not firmware_location.exists():
                if not firmware_location.parent.exists():
                    firmware_location.parent.mkdir()
                    firmware_location.parent.chmod(0o755)  # match rest of firmware

                firmware_location.write_bytes(base64.b64decode(EDID_1280_1024))
                firmware_location.chmod(0o644)

            mkinitcpio_conf['FILES'].add(firmware_location)

    # Drop the additions that Hetzner made to hooks because we do not need them
    if not dryrun:
        mkinitcpio_conf['HOOKS'].discard('lvm2')
        mkinitcpio_conf['HOOKS'].discard('mdadm_udev')

    # Hetzner machines should always be booted in UEFI mode now according to
    # their documentation but the adjustments by this function will be fatal if
    # it is not so just make sure...
    # https://docs.hetzner.com/robot/dedicated-server/operating-systems/uefi
    if not (Path('/sys/firmware/efi').exists() or dryrun):
        raise RuntimeError('Hetzner machine not booted under UEFI?')

    # archinstall sets up /boot as the ESP but installimage requires /boot/efi
    # to be the ESP and sets up /boot separately to hold the kernels. These
    # partitions can be reused for systemd-boot but they need a little
    # tweaking.

    # While ESP at /boot/efi can be used with systemd-boot, it is discouraged.
    # Use the more conventional /efi mountpoint so that bootctl automatically
    # works.
    adjust_esp_mountpoint(fstab, dryrun)

    # In order for ESP and kernel images to be on separate partitions, such as
    # '/boot' and '/efi' in our case, '/boot' must be an XBOOTLDR partition
    # (see "Files" section in
    # https://www.freedesktop.org/software/systemd/man/latest/systemd-boot.html).
    # installimage does not allow us to do this automatically.
    convert_boot_to_xbootldr(fstab, dryrun)

    # Switch to systemd-boot from grub, as my environment expects systemd-boot
    # and it is simpler to configure and manipulate.
    switch_from_grub_to_systemd_boot(conf, dryrun)


def is_hetzner():
    # While this lives in arch.py because that is the only place within setup
    # where it is relevant, it might be called on any platform from fish, so
    # ensure it works when /etc/pacman.conf does not exists.
    # pacman_settings() ensures that HETZNER_MIRROR is a permanent addition.
    return PACMAN_CONF.exists() and HETZNER_MIRROR in PACMAN_CONF.read_text(encoding='utf-8')


def pacman_install(subargs):
    lib.setup.pacman(['-S', '--noconfirm', *subargs])


def pacman_install_packages():
    packages = [
        # Administration tools
        'btop',
        'ethtool',
        'fastfetch',
        'iputils',
        'kexec-tools',
        'modprobed-db',
        'polkit',
        'reflector',
        'tio',

        # b4
        'b4',
        'git-filter-repo',
        'python-dkim',
        'patatt',

        # Container tools
        'aardvark-dns',
        'buildah',
        'catatonit',
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

        # mkosi
        'apt',
        'debian-archive-keyring',
        'distribution-gpg-keys',
        'dnf',

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
        'fakeroot',  # optional dependency of checkupdates
        'pacman-contrib',

        # Remote work
        'mosh',
        'openssh',
    ]  # yapf: disable

    if CPU_VENDOR:
        packages.append(f"{CPU_VENDOR}-ucode")

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
    lib.utils.run(['pacman-key', '--init'])
    lib.utils.run(['pacman-key', '--populate', 'archlinux'])


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

    # Ensure that my database exists, as we may need to reinstall the linux
    # package and that can fail if my database is not available. It is tempting
    # to just 'pacman -Sy' here but we do not want to risk a partial upgrade...
    if not (nathan_db := Path('/var/lib/pacman/sync/nathan.db')).exists():
        with TemporaryDirectory() as tempdir:
            Path(tempdir).chmod(0o755)  # avoid permission errors from pacman
            lib.utils.run(['pacman', '--dbpath', tempdir, '-Sy'])
            shutil.move(Path(tempdir, *nathan_db.parts[-2:]), nathan_db)


def pacman_update():
    pacman_install(['-yyu'])


def parse_arguments():
    parser = ArgumentParser(description='Set up an Arch Linux installation')

    parser.add_argument('-p', '--password', help='User password')

    return parser.parse_args()


def prechecks():
    lib.utils.check_root()


def setup_doas(username):
    # sudo is a little bit more functional. Keep it in virtual machines.
    if lib.setup.is_virtual_machine():
        return

    if (doas_conf := Path('/etc/doas.conf')).exists():
        # doas.conf is recommend to be read only to root but we need to write
        # to the file. Temporarily adjust the permissions and put them back
        # when we are done. https://wiki.archlinux.org/title/Doas#Configuration
        doas_conf.chmod(0o600)
    doas_conf_text = (
        '# Allow me to be root for 5 minutes at a time\n'
        f"permit persist {username} as root\n"
        '# Pass through environment variables to podman\n'
        f"permit keepenv persist {username} as root cmd podman\n"
        '# Allow me to update packages without a password (arguments are matched exactly)\n'
        f"permit nopass {username} as root cmd pacman args -Syu\n"
        f"permit nopass {username} as root cmd pacman args -Syyu\n"
        f"permit nopass {username} as root cmd pacman args -Syu --noconfirm\n"
        f"permit nopass {username} as root cmd pacman args -Syyu --noconfirm\n"
        '# Do not require root to put in a password (makes no sense)\n'
        'permit nopass root\n')
    doas_conf.write_text(doas_conf_text, encoding='utf-8')
    doas_conf.chmod(0o400)

    doas_pam = Path('/etc/pam.d/doas')
    doas_pam_text = ('#%PAM-1.0\n'
                     'auth            include         system-auth\n'
                     'account         include         system-auth\n'
                     'session         include         system-auth\n'
                     'session         optional        pam_umask.so\n')
    doas_pam.write_text(doas_pam_text, encoding='utf-8')

    lib.setup.remove_if_installed('sudo')
    pacman_install(['opendoas-sudo'])


def setup_libvirt(username, mkinitcpio_conf):
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
        mkinitcpio_conf['MODULES'].add('kvm_amd')
    elif 'vmx' in cpuinfo:
        mkinitcpio_conf['MODULES'].add('kvm_intel')


def setup_user(username, userpass):
    if lib.setup.user_exists(username):
        lib.setup.chsh_fish(username)
        lib.setup.add_user_to_group('uucp', username)
    else:
        fish = Path(shutil.which('fish')).resolve()
        lib.utils.run(['useradd', '-G', 'wheel,uucp', '-m', '-s', fish, username])

        lib.setup.chpasswd(username, userpass)

    lib.setup.setup_ssh_authorized_keys(username)


def switch_from_grub_to_systemd_boot(conf='linux.conf', dryrun=False):
    # If systemd-boot is already set up, we do not need to do anything further
    if lib.setup.using_systemd_boot():
        return

    # Install systemd-boot to ESP, which will create /boot/loader and
    # /boot/loader/entries.
    lib.utils.print_or_run_cmd(['bootctl', 'install'], dryrun)

    # Create initial loader.conf
    loader_conf_txt = f"default {conf}\ntimeout 3\n"
    lib.utils.print_or_write_text(Path('/boot/loader/loader.conf'), loader_conf_txt, dryrun)

    # Default cmdline options
    root_findmnt = lib.utils.get_findmnt_info('/')
    cmdline_options = CmdlineOptions({
        'root': f"PARTUUID={root_findmnt['partuuid']}",
        'rootfstype': root_findmnt['fstype'],
        'rw': None,
    })
    # grub adds this dynamically during grub-mkconfig, we need it to boot
    if root_findmnt['fstype'] == 'btrfs' and (subvol := root_findmnt['fsroot'].strip('/')):
        cmdline_options['rootflags'] = f"subvol={subvol}"
    cmdline_options |= get_cmdline_additions()

    # Copy over any cmdline options that we added in grub, as those might be
    # necessary for the machine to work properly.
    if (grub_default := Path('/etc/default/grub')).exists():
        grub_default_txt = grub_default.read_text(encoding='utf-8')

        # Filter the default values, as there may be some set that are harmful for debugging
        if match := re.search('^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"$', grub_default_txt, flags=re.M):
            default_filter = ('loglevel=', 'quiet')
            filtered_defaults = ' '.join(item for item in match.groups()[0].split(' ')
                                         if not item.startswith(default_filter))
            cmdline_options |= CmdlineOptions(filtered_defaults)

        # Take the regular options wholesale
        if match := re.search('^GRUB_CMDLINE_LINUX="(.*)"$', grub_default_txt, flags=re.M):
            cmdline_options |= CmdlineOptions(match.groups()[0])

    # We may have multiple initrds
    initrds = ['initramfs-linux']
    if not lib.setup.is_virtual_machine() and CPU_VENDOR:
        initrds.insert(0, f"{CPU_VENDOR}-ucode")

    # Easily generate the text for initial linux.conf
    linux_conf_parts = [
        'title Arch Linux (linux)',
        'linux /vmlinuz-linux',
        *[f"initrd /{initrd}.img" for initrd in initrds],
        f"options {cmdline_options}",
    ]
    linux_conf_txt = ''.join(f"{item}\n" for item in linux_conf_parts)
    lib.utils.print_or_write_text(Path('/boot/loader/entries/linux.conf'), linux_conf_txt, dryrun)

    # Clean up grub
    if dryrun:
        print('$ rm -fr /boot/grub /efi/EFI/GRUB')
    else:
        lib.setup.remove_if_installed('grub')
        for cleanup_path in ('/boot/grub', '/efi/EFI/GRUB'):
            if Path(cleanup_path).exists():
                shutil.rmtree(cleanup_path)


def uncomment_pacman_option(conf, option, old_value=None, new_value=None):
    if old_value and new_value:
        return re.sub(f"^#{option} = {old_value}", f"{option} = {new_value}", conf, flags=re.M)
    if old_value or new_value:
        raise RuntimeError(f"old_value is {old_value} and new_value is {new_value}??")
    return re.sub(f"^#{option}", option, conf, flags=re.M)


def vmware_adjustments(mkinitcpio_conf):
    if lib.setup.get_hostname() != 'vmware':
        return

    # https://wiki.archlinux.org/title/VMware/Install_Arch_Linux_as_a_guest#In-kernel_drivers
    vmware_mods = {
        'vsock',
        'vmw_vsock_vmci_transport',
        'vmw_balloon',
        'vmw_vmci',
        'vmwgfx',
    }  # yapf: disable
    mkinitcpio_conf['MODULES'].update(vmware_mods)

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
    # It would be wasteful to update mkinitcpio.conf every time it was
    # modified, so it is instantiated once here then passed along to all
    # functions that modify it, so that it can be updated once at the end here.
    initcpio_conf = MkinitcpioConf()

    prechecks()
    # pacman_settings() should always be run first so that is_hetzner() always works
    pacman_settings()
    installimage_adjustments(initcpio_conf)
    configure_amd_pstate()
    configure_systemd_boot()
    pacman_key_setup()
    pacman_update()
    pacman_install_packages()
    setup_doas(user)
    setup_user(user, password)
    lib.setup.clone_env(user)
    lib.setup.podman_setup(user)
    vmware_adjustments(initcpio_conf)
    setup_libvirt(user, initcpio_conf)
    lib.setup.configure_trusted_networking()
    enable_reflector()
    adjust_gnome_power_settings()
    lib.setup.systemctl_enable(['sshd.service', 'paccache.timer'])
    lib.setup.enable_tailscale()
    fix_fstab()
    lib.setup.set_date_time()
    lib.setup.setup_initial_fish_config(user)
    if lib.setup.is_virtual_machine():
        initcpio_conf['HOOKS'].discard('keyboard')
    initcpio_conf.update_if_necessary()
    lib.setup.setup_virtiofs_automount()

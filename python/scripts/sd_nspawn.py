#!/usr/bin/env python3
# ruff: noqa: S108

from argparse import ArgumentParser
from collections import UserDict
import os
from pathlib import Path
import platform
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position

# This should not change after import
USER = os.environ['USER']
SYSTEMD_RUN_M = Path('/usr/local/bin/systemd-run-m')

# Default machine for a particular architecture
DEF_MACH = {
    'aarch64': 'dev-fedora',
    'armv7l': 'dev-debian',
    'x86_64': 'dev-arch',
}

DEV_KVM_ACCESS = os.access('/dev/kvm', os.R_OK | os.W_OK)


class NspawnConfig(UserDict):

    def __init__(self, name):
        # Initial static defaults
        super().__init__({
            'Exec': {
                'Boot':
                'yes',
                # Machine name will be accessed via IMAGE_ID within the
                # container, use the host's hostname for easy identification
                'Hostname':
                platform.uname().node,
                'PrivateUsers':
                'pick',
                'SystemCallFilter': [
                    # Necessary to avoid 'gpg: Using insecure memory'
                    'mlock',
                    # Necessary for 'perf record'
                    'perf_event_open',
                ],
            },
            'Files': {
                # Bind my /home directory and user into the container
                'BindUser': USER,
                # Mounts will be added dynamically
                'Bind': [],
                'BindReadOnly': [],
                'PrivateUsersOwnership': 'auto',
            },
            'Network': {
                # Use host networking, as my use of nspawn is not around
                # isolation
                'VirtualEthernet': 'no',
            },
        })
        self.name = name

        # Add dynamic bind mounts
        self._add_dynamic_mounts()

        # Set machine path based on the name
        self.machine_dir = Path('/var/lib/machines', self.name)

        # Set systemd version. If this fails, it means we do not have nspawn
        # installed or the output has changed, both of which need to be dealt
        # with.
        self.systemd_version = int(
            lib.utils.chronic(['systemd-nspawn', '--version']).stdout.splitlines()[0].split()[1])

    def _add_dynamic_mounts(self):
        automounted_mounts = {
            # We may be in a virtual machine
            os.environ['HOST_FOLDER'],
        }
        rw_mounts = {
            '/dev/kvm',
            *automounted_mounts,
            os.environ['NVME_FOLDER'],
            # Allow 'fzf --tmux' to work properly
            '/var/tmp/fzf',
        }
        ro_mounts = {
            # Broken in 258: https://github.com/systemd/systemd/issues/39037
            # os.environ['OPT_ORB_GUEST'],
            # Allow interacting with the host tmux socket
            f"/var/tmp/tmux-{os.getuid()}",
        }

        if mac_folder := os.environ.get('MAC_FOLDER'):
            rw_mounts.add(mac_folder)
        else:
            automounted_mounts.add(os.environ['NAS_FOLDER'])

        if 'arch' in self.name:
            # Share the host's mirrorlist so that reflector does not have to be
            # run in the container (even if it could)
            ro_mounts.add('/etc/pacman.d/mirrorlist')

            # This one should really be a tmpfs overlay to avoid polluting the
            # host but it does not look like nspawn's overlay configuration
            # allows idmapping? https://github.com/systemd/systemd/issues/25886
            rw_mounts.add('/var/cache/pacman/pkg')

        for mount in rw_mounts:
            # If it is a temporary directory that does not exist already, just
            # created it so that the next checks passes.
            if mount.startswith('/var/tmp'):
                Path(mount).mkdir(exist_ok=True)

            # '--bind-user' creates a specific uid_map entry for the host user
            # to the container user, so idmapping is only necessary when a
            # mount that is expected to be written to is not readable and
            # writeable by the current user, such as '/var/cache/pacman/pkg',
            # which needs to be written to as the host root user by the
            # container root user. For mounts where the current user can read
            # and write to, the mapping mentioned earlier makes everything work
            # as expeced without 'idmap'. We special case automounted mounts
            # because the os.access check may not pass if the folder has not
            # been automounted yet.
            if mount in automounted_mounts or os.access(mount, os.R_OK | os.W_OK):
                item = mount
            else:
                item = f"{mount}:{mount}:idmap"

            # The mount must exist on the host otherwise the container will not
            # start
            if Path(mount).exists():
                self.data['Files']['Bind'].append(item)

        for mount in ro_mounts:
            if Path(mount).exists():
                self.data['Files']['BindReadOnly'].append(mount)

    def _gen_cfg_str(self):
        parts = []

        for key, values in self.data.items():
            parts.append(f"[{key}]")
            for subkey, subval in values.items():
                if isinstance(subval, list):
                    # SystemCallFilter takes a space separated list of values
                    if subkey == 'SystemCallFilter':
                        parts.append(f"{subkey}={' '.join(subval)}")
                    # All other list configurations should be joined with the key
                    else:
                        parts += [f"{subkey}={item}" for item in sorted(subval)]
                elif subval:
                    parts.append(f"{subkey}={subval}")
            parts.append('')

        return '\n'.join(parts)

    def _cfg_to_args(self):
        cfg_to_arg = {
            'Bind': '--bind',
            'BindReadOnly': '--bind-ro',
            'BindUser': '--bind-user',
            'Boot': '--boot',
            'Hostname': '--hostname',
            'PrivateUsers': '--private-users',
            'PrivateUsersOwnership': '--private-users-ownership',
            'SystemCallFilter': '--system-call-filter',
        }
        nspawn_args = [
            # This script is the ultimate source of truth for arguments, not
            # our configuration files, which may be stale (but should still be
            # updated)
            '--settings=no',
        ]

        for values in self.data.values():
            for key, value in values.items():
                # If there is no corresponding command line flag, skip it
                # This namely affects VirtualEthernet, as host networking is
                # the default with systemd-nspawn but virtual networking is the
                # default with systemd-nspawn@.service.
                if not (flag := cfg_to_arg.get(key)):
                    continue

                if isinstance(value, list):
                    if flag == '--system-call-filter':
                        nspawn_args.append(f"{flag}={' '.join(value)}")
                    else:
                        nspawn_args += [f"{flag}={item}" for item in sorted(value)]
                # boot is special
                elif flag == '--boot':
                    nspawn_args.append(flag if value == 'yes' else '--as-pid2')
                else:
                    nspawn_args.append(f"{flag}={value}")

        return nspawn_args

    def _gen_eph_cmd(self):
        # Generate our command line arguments
        return [
            'systemd-nspawn',
            f"--directory={self.machine_dir}",
            '--ephemeral',
            # Bind mount an empty file to /etc/ephemeral to allow notating via
            # our prompt that we are in an ephemeral environment (so any
            # changes to /usr or other paths will not be persistent)
            '--bind-ro=:/etc/ephemeral',
            # Avoid using CBL tools in ephemeral environments by default (they
            # can still be manually used via their full path or temporarily be
            # added if needed). This allows config.fish to test if the file is
            # readable before adding the tools to the environment.
            '--inaccessible=/etc/use-cbl',
            *self._cfg_to_args(),
        ]

    def _gen_run_cmd(self, cmd):
        args = [
            SYSTEMD_RUN_M,
            self.name,
            # We do not need our units to remain in memory
            '--collect',
            # Allowing interacting with stdin and seeing stdout/stderr
            '--pty',
            # Show no machinectl output
            '--quiet',
            # Run command as our user
            f"--uid={USER}",
            # Get return code of the process
            '--wait',
        ]
        # The shell will expand our environment
        if self.systemd_version >= 254:
            args.append('--expand-environment=no')
        args += [
            # Use a qualified path
            '/usr/bin/fish',
            '-c',
            cmd,
        ]
        return args

    def _gen_upd_cmd(self):
        self.data['Exec']['Boot'] = 'no'
        return [
            'systemd-nspawn',
            f"--machine={self.name}",
            # We should only interact with this instance of the machine through this shell
            '--register=no',
            # Suppress the initial interaction message
            '--quiet',
            *self._cfg_to_args(),
            '/usr/bin/fish',
            '-l',
        ]

    def install_files(self):
        lib.utils.print_green('Requesting sudo permissions for file creation...')
        lib.utils.run_as_root('true')

        # Allow containers started as services to access /dev/kvm to run
        # accelerated VMs, which allows avoiding installing QEMU in the host
        # environment.
        if DEV_KVM_ACCESS and not (kvm_conf := Path(
                '/etc/systemd/system/systemd-nspawn@.service.d/kvm.conf')).exists():
            kvm_conf_txt = ('[Service]\n'
                            'DeviceAllow=/dev/kvm rw\n')
            if not kvm_conf.parent.exists():
                lib.utils.run_as_root(['mkdir', '-p', kvm_conf.parent])
            lib.utils.run_as_root(['tee', kvm_conf], input=kvm_conf_txt)

        # Allow my user to access 'machinectl shell' without authentication
        # rules.d can only be read by root so we need to use sudo to test
        polkit_rule = Path('/etc/polkit-1/rules.d', f"50-permit-{USER}-machinectl-shell.rules")
        if not lib.utils.run_check_rc_zero(['sudo', 'test', '-e', polkit_rule]):
            polkit_rule_txt = ('polkit.addRule(function(action, subject) {\n'
                               '    if (action.id == "org.freedesktop.machine1.shell" &&\n'
                               f'        subject.user == "{USER}") {{\n'
                               '        return polkit.Result.YES;\n'
                               '    }\n'
                               '});\n')
            lib.utils.run_as_root(['tee', polkit_rule], input=polkit_rule_txt)
            lib.utils.run_as_root(['chmod', '640', polkit_rule])
            lib.utils.run_as_root(['chown', 'root:polkitd', polkit_rule])

        # Set up passwordless systemd-run for machines similar to 'machinectl
        # shell' above. While this may be considered a security risk, I think
        # it should be relatively safe because there are few folders passed
        # into the container from the host and there is nothing secret about
        # the container, which is really just an extension of the host. It
        # would be nice if there was a way to allow this through the
        # configurations directly but it does not appear possible.
        if not SYSTEMD_RUN_M.exists():
            root_confs = [
                {
                    'path':
                    Path('/etc/doas.conf'),
                    'cfg':
                    ('# Allow me to run commands in nspawn machines without a password via a wrapper\n'
                     f"permit nopass {USER} as root cmd {SYSTEMD_RUN_M}\n"),
                    'rw':
                    '0600',
                    'ro':
                    '0400',
                },
                {
                    'path': Path(f"/etc/sudoers.d/00_{USER}"),
                    'cfg': f"{USER} ALL = NOPASSWD: {SYSTEMD_RUN_M}\n",
                    'rw': '0640',
                    'ro': '0440',
                },
            ]
            for root_conf in root_confs:
                if not lib.utils.run_check_rc_zero(['sudo', 'test', '-e', root_conf['path']]):
                    continue

                conf_txt = lib.utils.chronic(['sudo', 'cat', root_conf['path']]).stdout
                if str(SYSTEMD_RUN_M) not in conf_txt:
                    lib.utils.run_as_root(['chmod', root_conf['rw'], root_conf['path']])
                    lib.utils.run_as_root(['tee', '-a', root_conf['path']], input=root_conf['cfg'])
                    lib.utils.run_as_root(['chmod', root_conf['ro'], root_conf['path']])

                break
            else:
                raise RuntimeError('Cannot find a privilege escalation configuration?')

            systemd_run_m_txt = '#!/bin/sh\n\nexec systemd-run -M "$@"\n'
            lib.utils.run_as_root(['tee', SYSTEMD_RUN_M], input=systemd_run_m_txt)
            lib.utils.run_as_root(['chmod', '0755', SYSTEMD_RUN_M])

        # Write configuration file. We allow the user to interactively remove
        # an old one if so desired.
        if (nspawn_conf := Path('/etc/systemd/nspawn', f"{self.name}.nspawn")).exists():
            answer = input(f"\033[01;33m{nspawn_conf} already exists, remove it? [y/N]\033[0m ")
            if answer.lower() in ('y', 'yes'):
                lib.utils.run_as_root(['rm', nspawn_conf])
        if not nspawn_conf.exists():
            if not nspawn_conf.parent.exists():
                lib.utils.run_as_root(['mkdir', '-p', nspawn_conf.parent])
            lib.utils.run_as_root(['tee', nspawn_conf], input=self._gen_cfg_str())

        # Print a warning if the machine does not already exist
        # /var/lib/machines can only be read by root so we need to use sudo to test
        if not lib.utils.run_check_rc_zero(['sudo', 'test', '-e', self.machine_dir]):
            lib.utils.print_yellow(
                f"WARNING: {self.machine_dir} does not exist, machine will not start without it")

    def is_running(self):
        is_active_cmd = ['systemctl', 'is-active', '-q', f"systemd-nspawn@{self.name}.service"]
        return lib.utils.run_check_rc_zero(is_active_cmd)

    def reset(self, mode):
        machine_files = {
            self.machine_dir,
            Path('/etc/systemd/nspawn', self.name).with_suffix('.nspawn'),
        }
        setup_files = {
            SYSTEMD_RUN_M,
            Path('/etc/polkit-1/rules.d', f"50-permit-{USER}-machinectl-shell.rules"),
        }
        if DEV_KVM_ACCESS:
            setup_files.add(Path('/etc/systemd/system/systemd-nspawn@.service.d/kvm.conf'))

        if mode == 'machine':
            items_to_remove = machine_files
        elif mode == 'setup':
            items_to_remove = setup_files
        elif mode == 'all':
            items_to_remove = machine_files | setup_files
        else:
            raise ValueError(f"Do not know how to handle mode '{mode}'?")

        # If we are removing the machine and it has been enabled on boot, we
        # should make sure it is disabled and stopped before removing the
        # files.
        if mode in ('machine', 'all') and lib.utils.run_check_rc_zero(
            ['systemctl', 'is-enabled', f"systemd-nspawn@{self.name}"]):
            lib.utils.run_as_root(['machinectl', 'disable', '--now', self.name])

        lib.utils.run_as_root(['rm', '-r', *items_to_remove])

    def run_mach_cmd(self, cmd):
        lib.utils.run_as_root(self._gen_run_cmd(cmd))

    def run_eph_cmd(self):
        lib.utils.run_as_root(self._gen_eph_cmd())

    def run_upd_cmd(self):
        # First, we need to make sure this machine is not running via
        # systemd-nspawn.service. If it is, the user should use 'machinectl
        # shell' to enter the machine and update it directly, as there may be
        # running services that need to be restarted.
        if self.is_running():
            raise RuntimeError(
                'Machine is running when trying to update, interact via "machinectl shell"')
        lib.utils.run_as_root(self._gen_upd_cmd())


def parse_arguments():
    parser = ArgumentParser(description='Manager and wrapper for systemd-spawn')

    parser.add_argument('-n',
                        '--name',
                        default=DEF_MACH.get(platform.machine()),
                        help='Name of machine (default: %(default)s)')

    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument('-e',
                            '--ephemeral',
                            action='store_true',
                            help='Run "systemd-nspawn -x" command')
    mode_group.add_argument('-i', '--install', action='store_true', help='Install .nspawn files')
    mode_group.add_argument('--is-running', action='store_true', help='Check if machine is running')
    mode_group.add_argument('-r', '--run', metavar='CMD', help='Run command in nspawn machine')
    mode_group.add_argument('-R',
                            '--reset',
                            choices=['machine', 'setup', 'all'],
                            metavar='TYPE',
                            help='Remove the requested files (machine, setup, or both)')
    mode_group.add_argument('-u',
                            '--update',
                            action='store_true',
                            help='Enter inactive machine to update')

    return parser.parse_args()


def main():
    args = parse_arguments()

    if os.geteuid() == 0:
        raise RuntimeError('This script should not be run as root!')

    if lib.utils.in_container():
        raise RuntimeError('This script should be run on the host!')

    if not args.name:
        raise RuntimeError('No name specified and architecture has no default!')

    config = NspawnConfig(args.name)

    if args.ephemeral:
        config.run_eph_cmd()
    if args.install:
        config.install_files()
    if args.is_running:
        sys.exit(0 if config.is_running() else 1)
    if args.update:
        config.run_upd_cmd()
    if args.reset:
        config.reset(args.reset)
    if args.run:
        config.run_mach_cmd(args.run)


if __name__ == '__main__':
    main()

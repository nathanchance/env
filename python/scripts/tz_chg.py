#!/usr/bin/env python3

import platform
import sys
from argparse import ArgumentParser
from collections.abc import Iterator
from pathlib import Path
from subprocess import CalledProcessError

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
from scripts.sd_nspawn import DEF_MACH

# pylint: enable=wrong-import-position

DEV_IMG = DEF_MACH[platform.machine()]


def clean_timer_files() -> None:
    active_timers = get_active_timers()
    timers_to_clean = [timer for timer in get_timers() if timer not in active_timers]
    disable_and_rm_timers(timers_to_clean)


def create_service_file() -> None:
    service_name = 'chg_tz@.service'

    try:
        systemctl_host_mach(['list-unit-files', '--quiet', service_name])
    except CalledProcessError:
        service_txt = '''[Unit]
Description=Change system timezone to %I
CollectMode=inactive-or-failed

[Service]
ExecStart=/usr/bin/timedatectl set-timezone %I
'''
        systemctl_create_file(service_name, service_txt)


def disable_and_rm_timers(timers: list[Path]) -> None:
    if not timers:
        return

    disable_cmd = ['disable', '--now'] + [item.name for item in timers]
    systemctl_host(disable_cmd)
    systemctl_mach(disable_cmd, check=False)  # files may not exist in machine

    lib.utils.run0(rm_cmd := ['/usr/bin/rm', '-f', *timers])
    run_mach(rm_cmd)


def get_active_timers() -> list[Path]:
    base_systemctl_cmd = ['systemctl', 'list-timers', '--all', '--legend=no']
    return [
        timer
        for timer in get_timers()
        if not lib.utils.chronic([*base_systemctl_cmd, timer.name]).stdout.startswith('-')
    ]


def get_timers() -> Iterator[Path]:
    return Path('/etc/systemd/system').glob('sch_tz_chg-*.timer')


def parse_args():
    parser = ArgumentParser(description='Manage timezone changes')
    subparser = parser.add_subparsers(dest='subcommand', metavar='SUBCOMMAND', required=True)

    subparser.add_parser('clean', help='Clean up stale timer files')

    cancel_parser = subparser.add_parser('cancel', help='Cancel active timers')
    cancel_parser.add_argument(
        'files', help='Full path to timer files to cancel', nargs='*', type=Path
    )

    list_parser = subparser.add_parser('list', help='List scheduled timers')
    list_parser.add_argument(
        '-a',
        '--all',
        action='store_const',
        const='--all',
        help="Pass '--all' to 'systemctl list-timers'",
    )

    schedule_parser = subparser.add_parser('sch', help='Schedule a timezone change')
    schedule_parser.add_argument(
        'date_str',
        help="Date to perform timezone change at (in a format suitable for OnCalendar=)",
    )
    schedule_parser.add_argument(
        'time_str',
        help='Time to perform timezone change at (in a format suitable for OnCalendar=)',
    )
    schedule_parser.add_argument('timezone', help="Timezone to change to")

    subparser.add_parser('sync', help='Sync host timezone changes to container')

    return parser.parse_args()


def run_mach(cmd: list, **kwargs) -> None:
    if lib.utils.in_container():
        return

    sd_run_cmd = [
        'systemd-run',
        f"--machine={DEV_IMG}",
        '--collect',
        '--pipe',
        '--pty',
        '--quiet',
        '--wait',
        *cmd,
    ]
    lib.utils.run0(sd_run_cmd, **kwargs)


def schedule_tz_change(date_str: str, timezone: str) -> None:
    timer_name = f"sch_tz_chg-{date_str.replace(' ', '-').replace('/', '-')}.timer"
    timer_txt = f"""[Unit]
Description=Change system timezone to {timezone} @ {date_str}
CollectMode=inactive-or-failed

[Timer]
OnCalendar={date_str}
RemainAfterElapse=no
Unit=chg_tz@{timezone.replace('/', '-')}.service

[Install]
WantedBy=timers.target
"""

    systemctl_create_file(timer_name, timer_txt)
    systemctl_host_mach(['enable', '--now', timer_name])


def systemctl_create_file(
    file_name: str, file_txt: str, host: bool = True, container: bool = True
) -> None:
    systemctl_cmd = ['edit', '--force', '--full', '--stdin']
    if host:
        systemctl_host([*systemctl_cmd, file_name], input=file_txt)
    if container:
        systemctl_mach([*systemctl_cmd, file_name], input=file_txt)


def systemctl_host(cmd: list, **kwargs):
    return lib.utils.run0(['/usr/bin/systemctl', *cmd], **kwargs)


def systemctl_mach(cmd: list, **kwargs):
    return run_mach(['/usr/bin/systemctl', *cmd], **kwargs)


def systemctl_host_mach(cmd: list, **kwargs):
    systemctl_host(cmd, **kwargs)
    systemctl_mach(cmd, **kwargs)


if __name__ == '__main__':
    args = parse_args()

    # Make sure we are not in a container already and that it is active
    if lib.utils.in_container():
        raise RuntimeError('This needs to be run on the host!')
    lib.utils.chronic(['systemctl', 'is-active', f"systemd-nspawn@{DEV_IMG}.service"])

    if args.subcommand == 'cancel':
        if files := args.files:
            for file in files:
                if not file.exists():
                    raise FileNotFoundError(f"Provided file ('{file}') could not be found?")
        else:
            all_timers = list(map(str, Path('/etc/systemd/system').glob('sch_tz_chg-*.timer')))
            if files := lib.utils.fzf(
                'timers to cancel', '\n'.join(all_timers), ['--preview', 'cat {}']
            ):
                files = list(map(Path, files))

        disable_and_rm_timers(files)

    elif args.subcommand == 'clean':
        clean_timer_files()

    elif args.subcommand == 'list':
        list_cmd = ['systemctl', 'list-timers', 'sch_tz_chg-*']
        if args.all:
            list_cmd.insert(-1, args.all)
        lib.utils.run(list_cmd)

    elif args.subcommand == 'sch':
        if not Path('/usr/share/zoneinfo', args.timezone).exists():
            raise FileNotFoundError(f"{args.timezone} does not exist within /usr/share/zoneinfo?")

        DATE_STR = f"{args.date_str} {args.time_str} {args.timezone}"
        lib.utils.chronic(['systemd-analyze', 'calendar', DATE_STR])

        clean_timer_files()
        create_service_file()
        schedule_tz_change(DATE_STR, args.timezone)

    elif args.subcommand == 'sync':
        clean_timer_files()
        create_service_file()
        for timer in get_active_timers():
            systemctl_create_file(timer.name, timer.read_text(encoding='utf-8'), host=False)
            systemctl_mach(['enable', '--now', timer.name])

    else:
        raise RuntimeError(f"Don't know how to handle subcommand '{args.subcommand}'?")

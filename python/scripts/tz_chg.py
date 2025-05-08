#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import platform
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
from scripts.sd_nspawn import DEF_MACH
# pylint: enable=wrong-import-position

DEV_IMG = DEF_MACH[platform.machine()]


def clean_timer_files():
    timers_to_clean = []
    for timer in Path('/etc/systemd/system').glob('sch_tz_chg-*.timer'):
        cmd = ['systemctl', 'list-timers', '--all', '--legend=no', timer.name]
        if lib.utils.chronic(cmd).stdout.startswith('-'):  # not going to run again
            timers_to_clean.append(timer)
    disable_and_rm_timers(timers_to_clean)


def disable_and_rm_timers(timers):
    if not timers:
        return

    disable_cmd = ['disable', '--now'] + [item.name for item in timers]
    systemctl_host_mach(disable_cmd)

    lib.utils.run_as_root(rm_cmd := ['/usr/bin/rm', *timers])
    run_mach(rm_cmd)


def parse_args():
    parser = ArgumentParser(description='Manage timezone changes')
    subparser = parser.add_subparsers(dest='subcommand', metavar='SUBCOMMAND', required=True)

    subparser.add_parser('clean', help='Clean up stale timer files')

    cancel_parser = subparser.add_parser('cancel', help='Cancel active timers')
    cancel_parser.add_argument('files',
                               help='Full path to timer files to cancel',
                               nargs='*',
                               type=Path)

    list_parser = subparser.add_parser('list', help='List scheduled timers')
    list_parser.add_argument('-a',
                             '--all',
                             action='store_const',
                             const='--all',
                             help="Pass '--all' to 'systemctl list-timers'")

    schedule_parser = subparser.add_parser('sch', help='Schedule a timezone change')
    schedule_parser.add_argument(
        'date_str',
        help="Date to perform timezone change at (in a format suitable for OnCalendar=)")
    schedule_parser.add_argument(
        'time_str',
        help='Time to perform timezone change at (in a format suitable for OnCalendar=)')
    schedule_parser.add_argument('timezone', help="Timezone to change to")

    return parser.parse_args()


def run_mach(cmd, **kwargs):
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
    lib.utils.run_as_root(sd_run_cmd, **kwargs)


def schedule_tz_change(date_str, timezone):
    systemctl_cmd = ['edit', '--force', '--full', '--stdin']

    if not (service := Path('/etc/systemd/system/chg_tz@.service')).exists():
        service_txt = '''[Unit]
Description=Change system timezone to %I
CollectMode=inactive-or-failed

[Service]
ExecStart=/usr/bin/timedatectl set-timezone %I
'''
        systemctl_host_mach([*systemctl_cmd, service.name], input=service_txt)

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
    systemctl_host_mach([*systemctl_cmd, timer_name], input=timer_txt)

    systemctl_host_mach(['enable', '--now', timer_name])


def systemctl_host_mach(cmd, **kwargs):
    systemctl_cmd = ['/usr/bin/systemctl', *cmd]
    lib.utils.run_as_root(systemctl_cmd, **kwargs)
    run_mach(systemctl_cmd, **kwargs)


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
            if files := lib.utils.fzf('timers to cancel', '\n'.join(all_timers),
                                      ['--preview', 'cat {}']):
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

        date_str = f"{args.date_str} {args.time_str} {args.timezone}"
        lib.utils.chronic(['systemd-analyze', 'calendar', date_str])

        clean_timer_files()
        schedule_tz_change(date_str, args.timezone)

    else:
        raise RuntimeError(f"Don't know how to handle subcommand '{args.subcommand}'?")

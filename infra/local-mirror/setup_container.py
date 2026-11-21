#!/usr/bin/env python3

import subprocess
from pathlib import Path

GIT_DATA_DIR = Path('/srv/mirror/git')


def setup_grokmirror():
    print('[+] Running systemd-tmpfiles')
    subprocess.run(['systemd-tmpfiles', '--create', '/etc/tmpfiles.d/00-mirror.conf'], check=True)

    print('[+] Running grok-pull')
    grokmirror_conf = Path('/etc/grokmirror/grokmirror.conf')
    subprocess.run(['grok-pull', '-c', grokmirror_conf, '-v'], check=True)

    if not Path(GIT_DATA_DIR, 'fsck.status.js').exists():
        print('[+] Running grok-fsck')
        subprocess.run(['grok-fsck', '-c', grokmirror_conf, '-f', '-v'], check=True)

    dumb_mirrors = {'github.com': ('llvm/llvm-project',)}
    for host, repos in dumb_mirrors.items():
        for repo in repos:
            if (local_repo := Path(GIT_DATA_DIR, f"{repo}.git")).exists():
                print(f"[+] Running grok-dumb-pull on {local_repo}")
                subprocess.run(['grok-dumb-pull', local_repo], check=True)
            else:
                upstream_url = f"https://{host}/{repo}.git"
                print(f"[+] Cloning {upstream_url} into {local_repo}")
                subprocess.run(['git', 'clone', '--mirror', upstream_url, local_repo], check=True)


def main():
    setup_grokmirror()

    print('[+] Validating nginx configuration')
    subprocess.run(['nginx', '-t'], check=True)


if __name__ == '__main__':
    main()

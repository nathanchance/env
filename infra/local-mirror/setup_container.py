#!/usr/bin/env python3

import subprocess
from pathlib import Path

GIT_DATA_DIR = Path('/srv/mirror/git')


def setup_git_mirror():
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
                git_clone_cmd = ['git', 'clone', '--mirror']
                if 'llvm-project' in repo:
                    # these are all temporary refs, there is no need to mirror them
                    excluded_refs = ('heads/users/', 'heads/revert-', 'pull/')
                    git_clone_cmd += [
                        f"--config=remote.origin.fetch=^refs/{ref}*" for ref in excluded_refs
                    ]
                subprocess.run([*git_clone_cmd, upstream_url, local_repo], check=True)


def main():
    setup_git_mirror()

    print('[+] Validating nginx configuration')
    subprocess.run(['nginx', '-t'], check=True)


if __name__ == '__main__':
    main()

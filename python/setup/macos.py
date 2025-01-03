#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from pathlib import Path
import os
import re
import shutil
from subprocess import CalledProcessError
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position


def brew(brew_args):
    lib.utils.run([get_brew_path(), *brew_args])


def clone_env_plugins():
    env_folder = get_env_folder()
    github_folder = env_folder.parent

    if not env_folder.exists():
        env_folder.parent.mkdir(exist_ok=True, parents=True)
        repo_clone(env_folder)
    lib.utils.call_git_loud(env_folder, 'pull')

    forked_fisher_plugins = ['hydro']
    for plugin in [Path(github_folder, elem) for elem in forked_fisher_plugins]:
        if not plugin.exists():
            plugin.parent.mkdir(exist_ok=True, parents=True)
            repo_clone(plugin, 'personal')
        lib.utils.call_git_loud(plugin, ['remote', 'update'])


def get_brew_bin():
    return Path('/opt/homebrew/bin')


def get_brew_path():
    return Path(get_brew_bin(), 'brew')


def get_env_folder():
    return Path(get_main_folder(), 'github/env')


def get_main_folder():
    return Path(get_home(), 'Dev')


def get_home():
    return Path.home()


def brew_gh(gh_args):
    lib.utils.run([Path(get_brew_bin(), 'gh'), *gh_args])


def brew_git(git_args):
    lib.utils.run([Path(get_brew_bin(), 'git'), *git_args])


def install_packages():
    packages = [
        '1password-cli',
        'bat',
        'fd',
        'fish',
        'fzf',
        'gh',
        'git',
        'jq',
        'libusb',
        'mosh',
        'ripgrep',
        'rustup-init',
        'zoxide',
    ]  # yapf: disable
    brew(['install', *packages])

    casks = {
        # No tap needed
        '': ['wezterm@nightly'],
        'homebrew/cask-fonts': ['font-iosevka-ss08'],
    }
    for cask, packages in casks.items():
        if cask:
            brew(['tap', cask])
        brew(['install', '--cask', *packages])


def is_vm():
    return 'Virtual-Machine' in os.uname().nodename


def repo_clone(repo_dest, repo_branch=None):
    # neither ssh nor gh will be set up in virtual machines, just use plain ol' git.
    if is_vm():
        clone_args = ['-b', repo_branch] if repo_branch else []
        clone_args += [f"https://github.com/nathanchance/{repo_dest.name}.git", repo_dest]
        brew_git(['clone', *clone_args])
    else:
        clone_args = [repo_dest.name, repo_dest]
        if repo_branch:
            clone_args += ['--', '-b', repo_branch]
        brew_gh(['repo', 'clone', *clone_args])


def setup_gh():
    if is_vm():
        return

    try:
        brew_gh(['auth', 'status'])
    except CalledProcessError:
        brew_gh(['auth', 'login'])


def setup_homebrew():
    if not get_brew_path().exists():
        install_sh = lib.utils.curl(
            'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh').decode('utf-8')
        lib.utils.run(['/bin/bash', '-c', install_sh])


def setup_ssh():
    if is_vm():
        return

    home = get_home()
    if not (ssh_key := Path(home, '.ssh/id_ed25519')).exists():
        ssh_key.parent.mkdir(exist_ok=True, parents=True)

        if not (keys_folder := Path('/tmp/keys')).exists():  # noqa: S108
            repo_clone(keys_folder)

        keys_ssh = Path(keys_folder, 'ssh')
        for file in [ssh_key.name, f"{ssh_key.name}.pub"]:
            src = Path(keys_ssh, file)
            dst = Path(ssh_key.parent, file)
            shutil.copyfile(src, dst)

        ssh_key.chmod(0o600)

        shutil.rmtree(keys_folder)

    try:
        lib.utils.run(['ssh-add', '-l'])
    except CalledProcessError:
        lib.utils.run(['ssh-add', ssh_key])

    gh_conf_text = Path(home, '.config/gh/config.yml').read_text(encoding='utf-8')
    if re.search(r'^git_protocol:\s+(.*)$', gh_conf_text, flags=re.M).groups()[0] != 'ssh':
        brew_gh(['config', 'set', '-h', 'github.com', 'git_protocol', 'ssh'])
        brew_gh(['config', 'set', 'git_protocol', 'ssh'])
    Path(home, '.gitconfig').unlink(missing_ok=True)


def setup_wezterm_cfg():
    (wezterm_cfg := Path(get_home(), '.config/wezterm/wezterm.lua')).unlink(missing_ok=True)
    wezterm_cfg.parent.mkdir(exist_ok=True, parents=True)
    wezterm_cfg.symlink_to(Path(get_env_folder(), 'configs/local', wezterm_cfg.name))


def setup_fish():
    fish_script = ('# Start an ssh-agent\n'
                   'if not set -q SSH_AUTH_SOCK\n'
                   '    eval (ssh-agent -c)\n'
                   'end\n'
                   '\n'
                   f"set github_folder {get_env_folder().parent}\n"
                   'set fisher_plugins \\\n'
                   '    jorgebucaran/fisher \\\n'
                   '    $github_folder/{env/fish,hydro} \\\n'
                   '    PatrickF1/fzf.fish \\\n'
                   '    jorgebucaran/autopair.fish \\\n'
                   '    wfxr/forgit\n'
                   '\n'
                   'fisher list | fisher remove\n'
                   'curl -LSs https://git.io/fisher | source\n'
                   'and fisher install $fisher_plugins\n'
                   'or return\n'
                   '\n'
                   'set fish_cfg $__fish_config_dir/config.fish\n'
                   'rm -fr $fish_cfg\n'
                   'mkdir -p (dirname $fish_cfg)\n'
                   'ln -fsv $github_folder/env/fish/config.fish $fish_cfg\n'
                   '\n'
                   'git_setup\n'
                   'vim_setup\n')
    lib.utils.run([Path(get_brew_bin(), 'fish'), '-c', fish_script])


if __name__ == '__main__':
    if (user := get_home().name) != 'nathan':
        raise RuntimeError(f"Current user ('{user}') is unexpected!")

    if os.uname().sysname != 'Darwin':
        raise RuntimeError('Not running on macOS?')

    setup_homebrew()
    install_packages()
    setup_gh()
    setup_ssh()
    clone_env_plugins()
    setup_wezterm_cfg()
    setup_fish()

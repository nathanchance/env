#!/usr/bin/env python3

import pathlib
import os
import re
import shutil
import subprocess


def brew(brew_args):
    subprocess.run([get_brew_path()] + brew_args, check=True)


def clone_env_plugins():
    env_folder = get_env_folder()
    github_folder = env_folder.parent

    if not env_folder.exists():
        env_folder.parent.mkdir(exist_ok=True, parents=True)
        gh_repo_clone([env_folder.name, env_folder])
    subprocess.run(['git', 'pull'], check=True, cwd=env_folder)

    forked_fisher_plugins = ['hydro']
    for plugin in [github_folder.joinpath(elem) for elem in forked_fisher_plugins]:
        if not plugin.exists():
            plugin.parent.mkdir(exist_ok=True, parents=True)
            gh_repo_clone([plugin.name, plugin, '--', '-b', 'personal'])
        subprocess.run(['git', 'remote', 'update'], check=True, cwd=plugin)


def get_brew_bin():
    return pathlib.Path('/opt/homebrew/bin')


def get_brew_path():
    return get_brew_bin().joinpath('brew')


def get_env_folder():
    return get_home().joinpath('Dev', 'github', 'env')


def get_home():
    return pathlib.Path.home()


def brew_gh(gh_args):
    subprocess.run([get_brew_bin().joinpath('gh')] + gh_args, check=True)


def gh_repo_clone(clone_args):
    brew_gh(['repo', 'clone'] + clone_args)


def install_packages():
    packages = [
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
        'zoxide'
    ]  # yapf: disable
    brew(['install'] + packages)

    casks = [('homebrew/cask-fonts', ['font-iosevka-ss08']),
             ('wez/wezterm', ['wez/wezterm/wezterm-nightly'])]
    for cask in casks:
        repo = cask[0]
        packages = cask[1]

        brew(['tap', repo])
        brew(['install', '--cask'] + packages)


def setup_gh():
    try:
        brew_gh(['auth', 'status'])
    except subprocess.CalledProcessError:
        brew_gh(['auth', 'login'])


def setup_homebrew():
    if not get_brew_path().exists():
        install_sh = subprocess.run(
            ['curl', '-fLSs', 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'],
            capture_output=True,
            check=True,
            text=True).stdout
        subprocess.run(['/bin/bash', '-c', install_sh], check=True)


def setup_ssh():
    home = get_home()
    ssh_key = home.joinpath('.ssh', 'id_ed25519')
    if not ssh_key.exists():
        ssh_key.parent.mkdir(exist_ok=True, parents=True)

        keys_folder = pathlib.Path('/tmp/keys')
        if not keys_folder.exists():
            gh_repo_clone([keys_folder.name, keys_folder])

        keys_ssh = keys_folder.joinpath('ssh')
        for file in [ssh_key.name, f"{ssh_key.name}.pub"]:
            src = keys_ssh.joinpath(file)
            dst = ssh_key.parent.joinpath(file)
            shutil.copyfile(src, dst)

        ssh_key.chmod(0o600)

        shutil.rmtree(keys_folder)

    try:
        subprocess.run(['ssh-add', '-l'], check=True)
    except subprocess.CalledProcessError:
        subprocess.run(['ssh-add', ssh_key], check=True)

    gh_conf = home.joinpath('.config', 'gh', 'config.yml')
    gh_conf_text = gh_conf.read_text(encoding='utf-8')
    gh_proto = re.search(r'^git_protocol:.*$', gh_conf_text, flags=re.M).group(0).split(' ')[1]
    if gh_proto != 'ssh':
        brew_gh(['config', 'set', '-h', 'github.com', 'git_protocol', 'ssh'])
        brew_gh(['config', 'set', 'git_protocol', 'ssh'])
    home.joinpath('.gitconfig').unlink(missing_ok=True)


def setup_wezterm_cfg():
    wezterm_cfg = get_home().joinpath('.config', 'wezterm', 'wezterm.lua')
    if not wezterm_cfg.is_symlink():
        wezterm_cfg.unlink(missing_ok=True)
        wezterm_cfg.parent.mkdir(exist_ok=True, parents=True)
        wezterm_cfg.symlink_to(get_env_folder().joinpath('configs', 'local', wezterm_cfg.name))


def setup_fish_cfg():
    fish_cfg = get_home().joinpath('.config', 'fish', 'config.fish')
    if not fish_cfg.is_symlink():
        fish_cfg.unlink(missing_ok=True)
        fish_cfg.parent.mkdir(exist_ok=True, parents=True)
        fish_cfg_txt = ('# Start an ssh-agent\n'
                        'if not set -q SSH_AUTH_SOCK\n'
                        '    eval (ssh-agent -c)\n'
                        'end\n'
                        '\n'
                        '# Set up user environment wrapper\n'
                        'function env_setup\n'
                        '    set -l github_folder $HOME/Dev/github\n'
                        '    set -l fisher_plugins \\\n'
                        '        jorgebucaran/fisher \\\n'
                        '        $github_folder/{env/fish,hydro} \\\n'
                        '        PatrickF1/fzf.fish \\\n'
                        '        jorgebucaran/autopair.fish \\\n'
                        '        wfxr/forgit\n'
                        '\n'
                        '    curl -LSs https://git.io/fisher | source\n'
                        '    and fisher install $fisher_plugins\n'
                        '\n'
                        '    set -l fish_cfg $__fish_config_dir/config.fish\n'
                        '    if not test -L $fish_cfg\n'
                        '        rm -fr $fish_cfg\n'
                        '        mkdir -p (dirname $fish_cfg)\n'
                        '        ln -fsv $github_folder/env/fish/config.fish $fish_cfg\n'
                        '    end\n'
                        '\n'
                        '    git_setup\n'
                        '    vim_setup\n'
                        'end\n')
        fish_cfg.write_text(fish_cfg_txt, encoding='utf-8')


if __name__ == '__main__':
    user = get_home().name
    if user != 'nathan':
        raise Exception(f"Current user ('{user}') is unexpected!")

    if os.uname().sysname != 'Darwin':
        raise Exception('Not running on macOS?')

    setup_homebrew()
    install_packages()
    setup_gh()
    setup_ssh()
    clone_env_plugins()
    setup_wezterm_cfg()
    setup_fish_cfg()

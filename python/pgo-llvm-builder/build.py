#!/usr/bin/env python3

from argparse import ArgumentParser
import datetime
import json
from pathlib import Path
import platform
import shutil
import subprocess

IMAGE_TAG = 'pgo-llvm-builder'
ROOT = Path(__file__).resolve().parent
BUILD = Path(ROOT, 'build')
GIT = Path(ROOT, 'git')
INSTALL = Path(ROOT, 'install')
SRC = Path(ROOT, 'src')
MACHINE = platform.machine()

LLVM_REFS = {
    '19.0.0': 'origin/main',
    '18.1.0': 'release/18.x',
}

LLVM_VERSIONS = [
    '19.0.0',  # git
    '18.1.0',  # release/18.x
    '17.0.6',
    '16.0.6',
    '15.0.7',
    '14.0.6',
    '13.0.1',
    '12.0.1',
    '11.1.0',
]

parser = ArgumentParser(description='Build LLVM with PGO in a container.')
parser.add_argument('-b',
                    '--build-folder',
                    help='Location of build folder. Omit for build folder in repo')
parser.add_argument('-B',
                    '--build-args',
                    default=[],
                    help='Build arguments for Docker container build',
                    nargs='+')
parser.add_argument('-f',
                    '--force-build-container',
                    action='store_true',
                    help='Build container even if it exists')
parser.add_argument('-i',
                    '--install-folder',
                    help='Location of install folder. Omit for install folder in repo')
parser.add_argument('-l',
                    '--llvm-folder',
                    help='Location of llvm-project source. Omit for vendored version')
parser.add_argument('-s', '--skip-tests', action='store_true', help='Skip running LLVM/Clang tests')
parser.add_argument('-t',
                    '--tc-build-folder',
                    help='Location of tc-build. Omit for vendored version')
parser.add_argument('-v',
                    '--versions',
                    choices=[*LLVM_VERSIONS, 'all', 'all-stable', 'main'],
                    help='LLVM versions to build',
                    metavar='LLVM_VERSION',
                    nargs='+',
                    required=True)
args = parser.parse_args()

if not shutil.which('podman'):
    raise RuntimeError('podman not found!')

if 'all-stable' in args.versions:
    versions = LLVM_VERSIONS[1:]
elif 'all' in args.versions:
    versions = LLVM_VERSIONS
else:
    versions = args.versions

# First, build container if necessary
if not (build_container := args.force_build_container):
    podman_image_cmd = ['podman', 'image', 'ls', '--format', 'json']
    cmd_out = subprocess.run(podman_image_cmd, capture_output=True, check=True, text=True).stdout
    build_container = not [
        name for item in json.loads(cmd_out) if 'Names' in item
        for name in item['Names'] if 'pgo-llvm-builder' in name
    ]
if build_container:
    podman_build_cmd = [
        'podman',
        'build',
        *[f"--build-arg={arg}" for arg in args.build_args],
        '--layers=false',
        '--pull=always',
        '--tag',
        IMAGE_TAG,
        ROOT,
    ]
    subprocess.run(podman_build_cmd, check=True)

build_folder = Path(args.build_folder).resolve() if args.build_folder else BUILD

install_folder = Path(args.install_folder).resolve() if args.install_folder else INSTALL

if args.llvm_folder:
    llvm_folder = Path(args.llvm_folder).resolve()
    if not Path(llvm_folder, 'llvm').is_dir():
        raise FileNotFoundError('Invalid llvm-project provided, no llvm folder?')
elif not (llvm_folder := Path(GIT, 'llvm-project')).exists():
    llvm_folder.parent.mkdir(exist_ok=True, parents=True)
    git_clone_cmd = ['git', 'clone', 'https://github.com/llvm/llvm-project', llvm_folder]
    subprocess.run(git_clone_cmd, check=True)
subprocess.run(['git', 'remote', 'update'], check=True, cwd=llvm_folder)

if args.tc_build_folder:
    tc_build_folder = Path(args.tc_build_folder).resolve()
    if not Path(tc_build_folder, 'build-llvm.py').exists():
        raise FileNotFoundError('Invalid tc-build provided, no build-llvm.py?')
else:
    if not (tc_build_folder := Path(GIT, 'tc-build')).exists():
        tc_build_folder.parent.mkdir(exist_ok=True, parents=True)
        git_clone_cmd = [
            'git',
            'clone',
            'https://github.com/ClangBuiltLinux/tc-build',
            tc_build_folder,
        ]
        subprocess.run(git_clone_cmd, check=True)
    subprocess.run(['git', 'remote', 'update'], check=True, cwd=tc_build_folder)
    subprocess.run(['git', 'reset', '--hard', '@{u}'], check=True, cwd=tc_build_folder)

llvm_git_dir = Path(llvm_folder, '.git')
static_mounts = [
    {
        'src': build_folder,
        'dst': '/build',
    },
    {
        'src': tc_build_folder,
        'dst': '/tc-build',
    },
    # This has to be present for git operations to work in the worktree. It is
    # marked read only so that any attempts to modify the user's repo rather
    # than worktree will fail.
    {
        'src': llvm_git_dir,
        'dst': llvm_git_dir,
        'opts': {'ro'},
    },
]

if args.skip_tests:
    check_args = []
else:
    check_args = [
        '--check-targets',
        'clang',
        'lld',
        'llvm',
        'llvm-unit',
    ]
install_targets = [
    'clang',
    'clang-resource-headers',
    'compiler-rt',
    'lld',
    'llvm-addr2line',
    'llvm-ar',
    'llvm-dwarfdump',
    'llvm-nm',
    'llvm-objcopy',
    'llvm-objdump',
    'llvm-ranlib',
    'llvm-readelf',
    'llvm-strings',
    'llvm-strip',
]
projects = [
    'clang',
    'compiler-rt',
    'lld',
]
build_llvm_py_cmd = [
    Path('/tc-build/build-llvm.py'),
    '--build-folder', '/build',
    *check_args,
    '--install-folder', '/install',
    '--install-targets', *install_targets,
    '--llvm-folder', '/llvm',
    '--no-ccache',
    '--pgo', 'kernel-defconfig',
    '--projects', *projects,
    '--quiet-cmake',
    '--show-build-commands',
]  # yapf: disable

podman_run_cmd = [
    'podman',
    'run',
    '--cap-drop=DAC_OVERRIDE',  # for ld.lld tests
    '--env=DISTRIBUTING=1',  # for tc-build
    '--interactive',
    '--pids-limit=-1',  # to avoid running of PIDs when building
    '--rm',
    '--tty',
]
selinux_enabled = (enforce := Path('/sys/fs/selinux/enforce')).exists() and \
                  int(enforce.read_text(encoding='utf-8')) == 1

for value in versions:
    VERSION = LLVM_VERSIONS[0] if value == 'main' else value
    ref = LLVM_REFS[VERSION] if VERSION in LLVM_REFS else f"llvmorg-{VERSION}"

    if 'llvmorg' not in ref:
        date_info = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
        ref_info = subprocess.run(['git', 'show', '--format=%H', '-s', ref],
                                  capture_output=True,
                                  check=True,
                                  cwd=llvm_folder,
                                  text=True).stdout.strip()
        VERSION += f"-{ref_info}-{date_info}"

    if (llvm_install := Path(install_folder,
                             f"llvm-{VERSION}-{MACHINE}")).joinpath('bin/clang').exists():
        print(
            f"LLVM {VERSION} has already been built in {llvm_install}, remove installation to rebuild!",
        )
        continue
    llvm_install.mkdir(exist_ok=True, parents=True)

    if (worktree := Path(SRC, 'llvm-project')).exists():
        shutil.rmtree(worktree)
        subprocess.run(['git', 'worktree', 'prune'], check=True, cwd=llvm_folder)
    git_worktree_cmd = ['git', 'worktree', 'add', '--detach', worktree, ref]
    subprocess.run(git_worktree_cmd, check=True, cwd=llvm_folder)

    shutil.rmtree(build_folder, ignore_errors=True)
    build_folder.mkdir(exist_ok=True, parents=True)

    mounts = [
        *static_mounts,
        {
            'src': llvm_install,
            'dst': '/install',
        },
        {
            'src': worktree,
            'dst': '/llvm',
        },
    ]
    if selinux_enabled:
        for mount in mounts:
            if 'opts' in mount:
                mount['opts'].add('z')
            else:
                mount['opts'] = {'z'}

    build_cmd = [
        *podman_run_cmd,
        *[
            f"--volume={d['src']}:{d['dst']}{(':' + ','.join(d['opts'])) if 'opts' in d else ''}"
            for d in mounts
        ],
        IMAGE_TAG,
        *build_llvm_py_cmd,
    ]
    # Enable BOLT for more optimization if:
    # - We are on x86_64 with LLVM greater than or equal to 16.x (due to
    #   https://github.com/llvm/llvm-project/issues/55004)
    # - We are on aarch64 with LLVM greater than or equal to 18.x (due to
    #   https://github.com/llvm/llvm-project/issues/71822)
    # Enable ThinLTO if BOLT is enabled, as it adds more speed gains (but it
    # appears to regress PGO's wins without BOLT)
    maj_ver = int(VERSION.split('.', 1)[0])
    if (maj_ver >= 16 and MACHINE == 'x86_64') or (maj_ver >= 18 and MACHINE == 'aarch64'):
        build_cmd += ['--bolt', '--lto', 'thin']
    subprocess.run(build_cmd, check=True)

    llvm_tarball = Path(llvm_install.parent, f"{llvm_install.name}.tar")
    tar_cmd = [
        'tar',
        '--create',
        '--directory',
        llvm_install.parent,
        '--file',
        llvm_tarball,
        llvm_install.name,
    ]
    subprocess.run(tar_cmd, check=True)

    llvm_tarball_compressed = llvm_tarball.with_suffix('.tar.zst')
    zstd_cmd = [
        'zstd',
        '-19',
        '-T0',
        '-o',
        llvm_tarball_compressed,
        llvm_tarball,
    ]
    subprocess.run(zstd_cmd, check=True)

    info_text = ('\n'
                 f"Tarball is available at: {llvm_tarball}\n"
                 f"Compressed tarball is available at: {llvm_tarball_compressed}")
    print(info_text)

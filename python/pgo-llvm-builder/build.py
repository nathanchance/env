#!/usr/bin/env python3

from argparse import ArgumentParser
import datetime
from pathlib import Path
import platform
import shutil
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position

MACH_FOLDER = Path('/var/lib/machines/pgo-llvm-builder')
ROOT = Path(__file__).resolve().parent
BUILD = Path(ROOT, 'build')
GIT = Path(ROOT, 'git')
INSTALL = Path(ROOT, 'install')
SRC = Path(ROOT, 'src')
MACHINE = platform.machine()

LLVM_REFS = {
    '21.0.0': 'origin/main',
    '20.1.0': 'origin/release/20.x',
}

LLVM_VERSIONS = [
    '21.0.0',  # git
    '20.1.0',  # release/20.x
    '20.1.0-rc3',
    '19.1.8',
    '19.1.7',
    '18.1.8',
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

if not shutil.which('systemd-nspawn'):
    raise RuntimeError('systemd-nspawn not found!')

if 'all-stable' in args.versions:
    versions = LLVM_VERSIONS[1:]
elif 'all' in args.versions:
    versions = LLVM_VERSIONS
else:
    versions = args.versions

# First, make sure environment exists. Check for this requires root because
# /var/lib/machines can only be read by the root user but we need it for later
# anyways.
lib.utils.run_as_root(['test', '-e', MACH_FOLDER])

build_folder = Path(args.build_folder).resolve() if args.build_folder else BUILD

install_folder = Path(args.install_folder).resolve() if args.install_folder else INSTALL

if args.llvm_folder:
    llvm_folder = Path(args.llvm_folder).resolve()
    if not Path(llvm_folder, 'llvm').is_dir():
        raise FileNotFoundError('Invalid llvm-project provided, no llvm folder?')
elif not (llvm_folder := Path(GIT, 'llvm-project')).exists():
    llvm_folder.parent.mkdir(exist_ok=True, parents=True)
    lib.utils.call_git_loud(None, ['clone', 'https://github.com/llvm/llvm-project', llvm_folder])
lib.utils.call_git_loud(llvm_folder, ['remote', 'update'])

if args.tc_build_folder:
    tc_build_folder = Path(args.tc_build_folder).resolve()
    if not Path(tc_build_folder, 'build-llvm.py').exists():
        raise FileNotFoundError('Invalid tc-build provided, no build-llvm.py?')
else:
    if not (tc_build_folder := Path(GIT, 'tc-build')).exists():
        tc_build_folder.parent.mkdir(exist_ok=True, parents=True)
        lib.utils.call_git_loud(
            None, ['clone', 'https://github.com/ClangBuiltLinux/tc-build', tc_build_folder])
    lib.utils.call_git_loud(tc_build_folder, ['remote', 'update'])
    lib.utils.call_git_loud(tc_build_folder, ['reset', '--hard', '@{u}'])

llvm_git_dir = Path(llvm_folder, '.git')
rw_mounts = {
    f"{build_folder}:/build",
    f"{tc_build_folder}:/tc-build",
}
ro_mounts = {
    llvm_git_dir,
}

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
    'libclang',
    'libclang-headers',
    'lld',
    *[
        f"llvm-{tool}" for tool in ('addr2line', 'ar', 'as', 'dwarfdump', 'link', 'nm', 'objcopy',
                                    'objdump', 'ranlib', 'readelf', 'strings', 'strip')
    ],
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

systemd_nspawn_cmd = [
    'systemd-nspawn',
    '--as-pid2',
    '--ephemeral',
    f"--machine={MACH_FOLDER.name}",
    '--private-users=pick',
    '--private-users-ownership=auto',
    '--quiet',
    '--register=no',
    '--setenv=DISTRIBUTING=1',
    '--settings=no',
    '--system-call-filter=perf_event_open',
    '--user=builder',
]

for value in versions:
    VERSION = LLVM_VERSIONS[0] if value == 'main' else value
    ref = LLVM_REFS.get(VERSION, f"llvmorg-{VERSION}")

    if 'llvmorg' not in ref:
        date_info = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
        ref_info = lib.utils.get_git_output(llvm_folder, ['show', '--format=%H', '-s', ref])
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
        lib.utils.call_git(llvm_folder, ['worktree', 'prune'])

    lib.utils.call_git_loud(llvm_folder, ['worktree', 'add', '--detach', worktree, ref])

    # Python 3.12 deprecates and changes a few things in the tests. If we are
    # running the tests, make sure we have the fixes. It is safe to apply them
    # even if we are not using Python 3.12.
    if check_args:
        # https://github.com/llvm/llvm-project/commit/015c43178f9d8531b6bcd1685dbf72b7d837cf5a
        if (gen_cfi_funcs := Path(worktree, 'lld/test/MachO/tools/generate-cfi-funcs.py')).exists():
            gen_cfi_funcs_txt = gen_cfi_funcs.read_text(encoding='utf-8')
            if 'frame_offset = -random.randint(0, (frame_size/16 - 4)) * 16' in gen_cfi_funcs_txt:
                if 'regs_saved = saved_regs_combined[reg_count][reg_combo]' in gen_cfi_funcs_txt:
                    # 015c43178f9d8531b6bcd1685dbf72b7d837cf5a won't pick cleanly, just do the replacement ourselves
                    new_text = gen_cfi_funcs_txt.replace('(frame_size/16 - 4)) * 16',
                                                         'int(frame_size/16 - 4)) * 16')
                    gen_cfi_funcs.write_text(new_text, encoding='utf-8')
                else:
                    lib.utils.call_git_loud(worktree, [
                        'cherry-pick',
                        '--no-commit',
                        '015c43178f9d8531b6bcd1685dbf72b7d837cf5a',
                    ])
        # https://github.com/llvm/llvm-project/commit/01fdc2a3c9e0df4e54bb9b88f385f68e7b0d808c
        if (uctc := Path(worktree, 'llvm/utils/update_cc_test_checks.py')).exists():
            uctc_txt = uctc.read_text(encoding='utf-8')
            if 'distutils.spawn' in uctc_txt:
                lib.utils.call_git_loud(worktree, [
                    'cherry-pick',
                    '--no-commit',
                    '01fdc2a3c9e0df4e54bb9b88f385f68e7b0d808c',
                ])

    shutil.rmtree(build_folder, ignore_errors=True)
    build_folder.mkdir(exist_ok=True, parents=True)

    rw_mounts.add(f"{llvm_install}:/install")
    rw_mounts.add(f"{worktree}:/llvm")

    build_cmd = [
        *systemd_nspawn_cmd,
        *[f"--bind={val}:idmap" for val in rw_mounts],
        *[f"--bind-ro={val}" for val in ro_mounts],
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
    lib.utils.run_as_root(build_cmd)

    llvm_tarball = Path(llvm_install.parent, f"{llvm_install.name}.tar")
    lib.utils.run([
        'tar',
        '--create',
        '--directory',
        llvm_install.parent,
        '--file',
        llvm_tarball,
        llvm_install.name,
    ])

    llvm_tarball_compressed = llvm_tarball.with_suffix('.tar.zst')
    lib.utils.run([
        'zstd',
        '-19',
        '-T0',
        '-o',
        llvm_tarball_compressed,
        llvm_tarball,
    ])

    INFO_TEXT = ('\n'
                 f"Tarball is available at: {llvm_tarball}\n"
                 f"Compressed tarball is available at: {llvm_tarball_compressed}")
    print(INFO_TEXT)

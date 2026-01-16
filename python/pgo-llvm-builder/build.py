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
    '23.0.0': 'origin/main',
    '22.1.0': 'origin/release/21.x',
}

LLVM_VERSIONS = [
    '23.0.0',  # git
    '22.1.0',  # release/22.x
    '22.1.0-rc1',
    '21.1.8',
    '20.1.8',
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

if __name__ == '__main__':
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
    parser.add_argument('-s',
                        '--skip-tests',
                        action='store_true',
                        help='Skip running LLVM/Clang tests')
    parser.add_argument('--slim-pgo',
                        action='store_true',
                        help='Perform slim PGO instead of full PGO')
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
    lib.utils.tg_msg(f"sudo authorization needed to check for {MACH_FOLDER}")
    lib.utils.run_as_root(['test', '-e', MACH_FOLDER])

    build_folder = Path(args.build_folder).resolve() if args.build_folder else BUILD

    install_folder = Path(args.install_folder).resolve() if args.install_folder else INSTALL

    if args.llvm_folder:
        llvm_folder = Path(args.llvm_folder).resolve()
        if not Path(llvm_folder, 'llvm').is_dir():
            raise FileNotFoundError('Invalid llvm-project provided, no llvm folder?')
    elif not (llvm_folder := Path(GIT, 'llvm-project')).exists():
        llvm_folder.parent.mkdir(exist_ok=True, parents=True)
        lib.utils.call_git_loud(None,
                                ['clone', 'https://github.com/llvm/llvm-project', llvm_folder])
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

    if args.skip_tests:
        CHECK_ARGS = []
    else:
        CHECK_ARGS = [
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
            f"llvm-{tool}"
            for tool in ('addr2line', 'ar', 'as', 'dwarfdump', 'link', 'nm', 'objcopy', 'objdump',
                         'ranlib', 'readelf', 'strings', 'strip')
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
        *CHECK_ARGS,
        '--install-folder', '/install',
        '--install-targets', *install_targets,
        '--llvm-folder', '/llvm',
        '--no-ccache',
        '--pgo', f"kernel-defconfig{'-slim' if args.slim_pgo else ''}",
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
        '--setenv=TMPDIR=/build/tmp',
        '--settings=no',
        '--system-call-filter=perf_event_open',
        '--user=builder',
    ]

    for value in versions:
        version = LLVM_VERSIONS[0] if value == 'main' else value
        ref = LLVM_REFS.get(version, f"llvmorg-{version}")

        if 'llvmorg' not in ref:
            date_info = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
            ref_info = lib.utils.get_git_output(llvm_folder, ['show', '--format=%H', '-s', ref])
            version += f"-{ref_info}-{date_info}"

        if (llvm_install := Path(install_folder,
                                 f"llvm-{version}-{MACHINE}")).joinpath('bin/clang').exists():
            print(
                f"LLVM {version} has already been built in {llvm_install}, remove installation to rebuild!",
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
        if CHECK_ARGS:
            base_cp_cmd = ['cherry-pick', '--no-commit']
            # https://github.com/llvm/llvm-project/commit/015c43178f9d8531b6bcd1685dbf72b7d837cf5a
            if (gen_cfi_funcs := Path(worktree,
                                      'lld/test/MachO/tools/generate-cfi-funcs.py')).exists():
                gen_cfi_funcs_txt = gen_cfi_funcs.read_text(encoding='utf-8')
                if 'frame_offset = -random.randint(0, (frame_size/16 - 4)) * 16' in gen_cfi_funcs_txt:
                    if 'regs_saved = saved_regs_combined[reg_count][reg_combo]' in gen_cfi_funcs_txt:
                        # 015c43178f9d8531b6bcd1685dbf72b7d837cf5a won't pick cleanly, just do the replacement ourselves
                        new_text = gen_cfi_funcs_txt.replace('(frame_size/16 - 4)) * 16',
                                                             'int(frame_size/16 - 4)) * 16')
                        gen_cfi_funcs.write_text(new_text, encoding='utf-8')
                    else:
                        lib.utils.call_git_loud(worktree, [
                            *base_cp_cmd,
                            '015c43178f9d8531b6bcd1685dbf72b7d837cf5a',
                        ])
            # https://github.com/llvm/llvm-project/commit/01fdc2a3c9e0df4e54bb9b88f385f68e7b0d808c
            if (uctc := Path(worktree, 'llvm/utils/update_cc_test_checks.py')).exists():
                uctc_txt = uctc.read_text(encoding='utf-8')
                if 'distutils.spawn' in uctc_txt:
                    # https://github.com/llvm/llvm-project/commit/d1007478f19d3ff19a2ecd5ecb04b467933041e6
                    # to make the following change apply cleanly
                    if 'infer_dependent_args' not in uctc_txt:
                        lib.utils.call_git_loud(
                            worktree, [*base_cp_cmd, 'd1007478f19d3ff19a2ecd5ecb04b467933041e6'])
                    lib.utils.call_git_loud(worktree, [
                        *base_cp_cmd,
                        '01fdc2a3c9e0df4e54bb9b88f385f68e7b0d808c',
                    ])
            # https://github.com/llvm/llvm-project/commit/bc839b4b4e27b6e979dd38bcde51436d64bb3699
            # Manually applied because it does not apply cleanly to any release
            # that needs it.
            if (go_bindings := Path(worktree, 'llvm/bindings/go')).is_dir():
                rm_dirs = (go_bindings, Path(worktree, 'llvm/test/Bindings/Go'),
                           Path(worktree, 'llvm/tools/llvm-go'))
                for rm_dir in rm_dirs:
                    shutil.rmtree(rm_dir)

                site_cfg_py = Path(worktree, 'llvm/test/lit.site.cfg.py.in')
                line_to_delete = 'config.go_executable = "@GO_EXECUTABLE@"\n'
                new_site_cfg_py = site_cfg_py.read_text(encoding='utf-8').replace(
                    line_to_delete, '')
                site_cfg_py.write_text(new_site_cfg_py, encoding='utf-8')

                mod_files = ('.gitignore', 'cmake/config-ix.cmake', 'test/lit.cfg.py',
                             'utils/lit/lit/llvm/subst.py')
                fp_cmd = [
                    'format-patch',
                    '-1',
                    '--stdout',
                    'bc839b4b4e27b6e979dd38bcde51436d64bb3699',
                ] + [Path(worktree, 'llvm', file) for file in mod_files]
                mod_diff = lib.utils.call_git(worktree, fp_cmd).stdout
                lib.utils.call_git_loud(worktree, ['ap'], input=mod_diff)

        shutil.rmtree(build_folder, ignore_errors=True)
        Path(build_folder, 'tmp').mkdir(exist_ok=True, parents=True)

        mounts = (
            (build_folder, '/build'),
            (llvm_install, '/install'),
            (worktree, '/llvm'),
            (llvm_git_dir, llvm_git_dir),
            (tc_build_folder, '/tc-build'),
        )
        mount_args = []
        for src, dst in mounts:
            mountpoint = lib.utils.chronic(['stat', '-c', '%m', src]).stdout.strip()
            mountinfo = lib.utils.get_findmnt_info(mountpoint)
            # virtiofs does not support idmapping
            opts = '' if mountinfo['fstype'] == 'virtiofs' else ':idmap'
            mount_args.append(f"--bind={src}:{dst}{opts}")
        build_cmd = [
            *systemd_nspawn_cmd,
            *mount_args,
            *build_llvm_py_cmd,
        ]
        # Enable BOLT for more optimization if:
        # - We are on x86_64 with LLVM greater than or equal to 16.x (due to
        #   https://github.com/llvm/llvm-project/issues/55004)
        # - We are on aarch64 with LLVM greater than or equal to 18.x (due to
        #   https://github.com/llvm/llvm-project/issues/71822)
        # Enable ThinLTO if BOLT is enabled, as it adds more speed gains (but it
        # appears to regress PGO's wins without BOLT)
        maj_ver = int(version.split('.', 1)[0])
        if (maj_ver >= 16 and MACHINE == 'x86_64') or (maj_ver >= 18 and MACHINE == 'aarch64'):
            build_cmd += ['--bolt', '--lto', 'thin']

        lib.utils.tg_msg(f"sudo authorization needed to build LLVM {version}")
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

        info_text = ('\n'
                     f"Tarball is available at: {llvm_tarball}\n"
                     f"Compressed tarball is available at: {llvm_tarball_compressed}")
        print(info_text)
        lib.utils.tg_msg(f"LLVM {version} finished building successfully")

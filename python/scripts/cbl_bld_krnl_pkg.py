#!/usr/bin/env python3

from argparse import ArgumentParser
import os
from pathlib import Path
import shutil
import subprocess
import sys

import korg_tc

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.kernel
# pylint: enable=wrong-import-position


class KernelPkgBuilder:

    def __init__(self, source_folder=None):

        if not source_folder:
            source_folder = Path.cwd()
        if not Path(source_folder, 'Makefile').exists():
            raise RuntimeError(
                f"Derived kernel source ('{source_folder}') does not appear to be a Linux kernel tree?",
            )

        self._source_folder = source_folder
        self._build_folder = Path(os.environ['TMP_BUILD_FOLDER'],
                                  self._source_folder.name)  # same as tbf

        self.extra_sc_args = []
        self.make_variables = {
            'ARCH': 'x86_64',
            'HOSTLDFLAGS': '-fuse-ld=lld',
            'LLVM': os.environ.get('LLVM', f"{os.environ['CBL_TC_LLVM']}/"),
            'LOCALVERSION': '',
            'O': self._build_folder,
        }

        self._kernver = ''
        self._pkgname = 'linux-' + self._source_folder.name.replace('linux-', '')

    def _kmake(self, targets, **kwargs):
        lib.kernel.kmake(self.make_variables.copy(),
                         targets,
                         directory=self._source_folder,
                         **kwargs)

    def _prepare_files(self, _localmodconfig=False, _menuconfig=False):
        src_config_file = Path(os.environ['ENV_FOLDER'], f"configs/kernel/{self._pkgname}.config")
        dst_config_file = Path(self._build_folder, '.config')
        base_sc_cmd = [Path(self._source_folder, 'scripts/config'), '--file', src_config_file]
        kconfig_env = {'KCONFIG_CONFIG': src_config_file, **os.environ}
        plain_make_vars = {'ARCH': 'x86_64', 'LOCALVERSION': '', 'O': self._build_folder}

        # Step 1: Copy default Arch configuration and set a few options
        crl_cmd = [
            'curl',
            '-LSs',
            '-o', src_config_file,
            'https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/config',
        ]  # yapf: disable
        subprocess.run(crl_cmd, check=True)
        sc_cmd = [
            *base_sc_cmd,
            '-d', 'LOCALVERSION_AUTO',
            '-e', 'DEBUG_INFO_DWARF5',
            '-m', 'DRM',
        ]  # yapf: disable
        subprocess.run(sc_cmd, check=True)

        # Step 2: Run olddefconfig
        lib.kernel.kmake(plain_make_vars.copy(), ['olddefconfig'],
                         directory=self._source_folder,
                         env=kconfig_env)

        # Step 3: Run through olddefconfig with Clang
        self._kmake(['olddefconfig'], env=kconfig_env)

        # Step 4: Enable ThinLTO, CFI, or UBSAN (and any other requested configurations)
        if self.extra_sc_args:
            subprocess.run([*base_sc_cmd, *self.extra_sc_args], check=True)
            self._kmake(['olddefconfig'], env=kconfig_env)

        # Copy new configuration into place
        shutil.rmtree(self._build_folder)
        self._build_folder.mkdir(parents=True)
        shutil.copyfile(src_config_file, dst_config_file)

        self._kmake(['olddefconfig', 'prepare'])
        subprocess.run(
            ['git', '--no-pager', 'diff', '--no-index', src_config_file, dst_config_file],
            check=False)

        print('Setting version...')
        Path(self._build_folder, 'localversion.10-pkgname').write_text('-llvm\n', encoding='utf-8')

    def build(self):
        # Use upstream 'pacman-pkg' target if it is available
        if Path(self._source_folder, 'scripts/package/PKGBUILD').exists():
            target = 'pacman-pkg'
            self.make_variables['PACMAN_EXTRAPACKAGES'] = ''
            self.make_variables['PACMAN_PKGBASE'] = self._pkgname
        else:
            target = 'all'
        self._kmake([target])

    def package(self):
        # If build was done with upstream 'pacman-pkg' target, no need to run package()
        if Path(self._build_folder, 'pacman').exists():
            return

        if (pkgroot := Path(self._build_folder, 'pkgbuild')).exists():
            shutil.rmtree(pkgroot)
        pkgroot.mkdir(parents=True)

        pkgdir = Path(pkgroot, 'pkg-prepared', self._pkgname)
        modulesdir = Path(pkgdir, 'usr/lib/modules', self._kernver)

        print('Installing boot image...')
        kernel_image = subprocess.run(['make', '-s', f"O={self._build_folder}", 'image_name'],
                                      capture_output=True,
                                      cwd=self._source_folder,
                                      text=True,
                                      check=False).stdout.strip()
        # systemd expects to find the kernel here to allow hibernation
        # https://github.com/systemd/systemd/commit/edda44605f06a41fb86b7ab8128dcf99161d2344
        subprocess.run([
            'install',
            '-Dm644',
            Path(self._build_folder, kernel_image),
            Path(modulesdir, 'vmlinuz'),
        ],
                       check=True)

        # Used by mkinitcpio to name the kernel
        (pkgbase := Path(modulesdir, 'pkgbase')).write_text(f"{self._pkgname}\n", encoding='utf-8')
        pkgbase.chmod(0o644)

        print('Installing modules...')
        modules_env = {'ZSTD_CLEVEL': '19', **os.environ}
        modules_vars = {
            **self.make_variables,
            'DEPMOD': '/doesnt/exist',
            'INSTALL_MOD_PATH': Path(pkgdir, 'usr'),
            'INSTALL_MOD_STRIP': 1,
        }
        lib.kernel.kmake(modules_vars, ['modules_install'],
                         directory=self._source_folder,
                         env=modules_env)

        # remove build and source links if they exist
        for link in ['source', 'build']:
            Path(modulesdir, link).unlink(missing_ok=True)

        pkgver = subprocess.run(['git', 'describe'],
                                capture_output=True,
                                check=True,
                                cwd=self._source_folder,
                                text=True).stdout.strip().replace('-', '_')
        pkgbuild_text = fr"""
pkgname={self._pkgname}
pkgver={pkgver}
pkgrel=1
pkgdesc='{self._pkgname}'
url="https://kernel.org/"
arch=(x86_64)
license=(GPL2)
options=(!debug !strip)

package() {{
  pkgdesc="$pkgdesc kernel and modules"
  depends=(coreutils kmod initramfs)
  optdepends=('crda: to set the correct wireless channels of your country'
              'linux-firmware: firmware images needed for some devices')
  provides=(VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE)
  replaces=(virtualbox-guest-modules-arch wireguard-arch)

  local pkgroot="${{pkgdir//\/pkg\/$pkgname/}}"
  rm -rf "$pkgroot"/pkg
  mv -v "$pkgroot"/pkg-prepared "$pkgroot"/pkg
}}"""
        Path(pkgroot, 'PKGBUILD').write_text(pkgbuild_text, encoding='utf-8')
        subprocess.run(['makepkg', '-R'], check=True, cwd=pkgroot)

    def prepare(self, base_ref, localmodconfig=False, menuconfig=False):
        lib.kernel.prepare_source(self._pkgname, base_ref)

        self._prepare_files(localmodconfig, menuconfig)

        self._kernver = subprocess.run(
            ['make', '-s', 'LOCALVERSION=', f"O={self._build_folder}", 'kernelrelease'],
            capture_output=True,
            cwd=self._source_folder,
            text=True,
            check=False).stdout.strip()
        print(f"Prepared {self._pkgname} version {self._kernver}")


class DebugPkgBuilder(KernelPkgBuilder):

    def __init__(self):

        super().__init__(Path(os.environ['CBL_SRC_D'], 'linux-debug'))

    # pylint: disable-next=signature-differs
    def _prepare_files(self, localmodconfig, menuconfig):
        config = Path(self._build_folder, '.config')
        base_sc_cmd = [Path(self._source_folder, 'scripts/config'), '--file', config]

        if self._build_folder.exists():
            if self._build_folder.is_dir():
                shutil.rmtree(self._build_folder)
            else:
                self._build_folder.unlink()
        self._build_folder.mkdir(parents=True)

        crl_cmd = [
            'curl',
            '-LSs',
            '-o', config,
            'https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/config',
        ]  # yapf: disable
        subprocess.run(crl_cmd, check=True)
        sc_cmd = [*base_sc_cmd, '-m', 'DRM', *self.extra_sc_args]
        subprocess.run(sc_cmd, check=True)

        self._kmake(['olddefconfig'])

        if localmodconfig:
            if not (modprobedb := Path('/tmp/modprobed.db')).exists():  # noqa: S108
                raise RuntimeError(f"localmodconfig requested without {modprobedb}!")
            self._kmake(['localmodconfig'],
                        env={
                            'LSMOD': modprobedb,
                            **os.environ,
                        },
                        stdin=subprocess.DEVNULL)

        if menuconfig:
            self._kmake(['menuconfig'])

        self._kmake(['prepare'])

        print('Setting version...')
        Path(self._build_folder, 'localversion.10-pkgname').write_text('-debug\n', encoding='utf-8')


class MainlinePkgBuilder(KernelPkgBuilder):

    def __init__(self):

        super().__init__(Path(os.environ['CBL_SRC_P'], 'linux-mainline-llvm'))

    def _prepare_files(self, _localmodconfig=False, _menuconfig=False):
        super()._prepare_files()

        git_add_files = ['drivers/hwmon/Makefile']
        for part in ['', '_dev', '_hwmon']:
            src_url = f"https://github.com/pop-os/system76-io-dkms/raw/master/system76-io{part}.c"
            dst_local = Path(self._source_folder, 'drivers/hwmon', src_url.rsplit('/', 1)[-1])
            subprocess.run(['curl', '-LSs', '-o', dst_local, src_url], check=True)
            git_add_files.append(dst_local.relative_to(self._source_folder))
        with Path(self._source_folder, git_add_files[0]).open('a', encoding='utf-8') as file:
            file.write('obj-m += system76-io.o\n')
        subprocess.run(['git', 'add', *git_add_files], check=True, cwd=self._source_folder)
        subprocess.run(['git', 'commit', '-m', 'Add system76-io driver'],
                       check=True,
                       cwd=self._source_folder)

        git_kwargs = {
            'capture_output': True,
            'check': False,
            'cwd': self._source_folder,
            'text': True,
        }
        local_ver_parts = []

        # pylint: disable=subprocess-run-check
        head = subprocess.run(  # noqa: PLW1510
            ['git', 'rev-parse', '--verify', 'HEAD'], **git_kwargs).stdout.strip()
        exact_match = subprocess.run(  # noqa: PLW1510
            ['git', 'describe', '--exact-match'], **git_kwargs).stdout.strip()
        if head and exact_match == '':
            if (atag := subprocess.run(  # noqa: PLW1510
                ['git', 'describe'], **git_kwargs).stdout.strip()):
                local_ver_parts.append(f"{int(atag.split('-')[-2]):05}")
            local_ver_parts.append(f"g{head[0:12]}")
        # pylint: enable=subprocess-run-check

        if local_ver_parts:
            Path(self._build_folder,
                 'localversion.20-git').write_text(f"-{'-'.join(local_ver_parts)}\n",
                                                   encoding='utf-8')


class NextPkgBuilder(KernelPkgBuilder):

    def __init__(self):

        super().__init__(Path(os.environ['CBL_SRC_P'], 'linux-next-llvm'))


def parse_arguments():
    parser = ArgumentParser(description='Build Arch Linux package from kernel source')

    parser.add_argument('--cfi', action='store_true', help='Enable CONFIG_CFI_CLANG')
    parser.add_argument('--cfi-permissive',
                        action='store_true',
                        help='Enable CONFIG_CFI_PERMISSIVE')
    parser.add_argument('--lto', action='store_true', help='Enable CONFIG_LTO_CLANG_THIN')

    parser.add_argument('-g', '--gcc', action='store_true', help='Build with GCC instead of LLVM')

    parser.add_argument('-l',
                        '--localmodconfig',
                        action='store_true',
                        help='Call localmodconfig during configuration')
    parser.add_argument('-m',
                        '--menuconfig',
                        action='store_true',
                        help='Call menuconfig during configuration')

    parser.add_argument('--no-werror',
                        action='store_true',
                        help='Disable CONFIG_WERROR (on by default)')

    parser.add_argument('-r',
                        '--ref',
                        default='origin/master',
                        help='Reference to base kernel tree on')

    parser.add_argument('pos_args',
                        nargs='+',
                        help='Postitional arguments (package name, make arguments)')

    return parser.parse_args()


if __name__ == '__main__':
    args = parse_arguments()

    make_vars = {}
    for arg in args.pos_args:
        if '=' in arg:
            make_vars.update([arg.split('=', 1)])
        elif (pkgname := arg.replace('linux-', '')) in ('debug', 'mainline-llvm', 'next-llvm'):
            pass
        else:
            raise RuntimeError(f"Cannot handle positional argument ('{arg}')!")

    builder = {
        'debug': DebugPkgBuilder,
        'mainline-llvm': MainlinePkgBuilder,
        'next-llvm': NextPkgBuilder,
    }[pkgname]()

    if args.cfi or args.cfi_permissive:
        builder.extra_sc_args += ['-e', 'CFI_CLANG']
    if args.cfi_permissive:
        builder.extra_sc_args += ['-e', 'CFI_PERMISSIVE']
    if args.lto:
        builder.extra_sc_args += [
            '-d',
            'LTO_NONE',
            '-e',
            'LTO_CLANG_THIN',
        ]
    if not args.no_werror:
        builder.extra_sc_args += ['-e', 'WERROR']

    if args.gcc and 'CROSS_COMPILE' not in make_vars:
        make_vars['CROSS_COMPILE'] = korg_tc.GCCManager().get_cc_as_path(
            korg_tc.GCCManager.VERSIONS[-1], 'x86_64')
    if 'CROSS_COMPILE' in make_vars:
        del builder.make_variables['HOSTLDFLAGS']
        del builder.make_variables['LLVM']
    builder.make_variables.update(make_vars)

    builder.prepare(args.ref, args.localmodconfig, args.menuconfig)
    builder.build()
    builder.package()

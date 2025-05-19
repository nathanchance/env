#!/usr/bin/env python3

from argparse import ArgumentParser
import hashlib
from pathlib import Path
import shutil
import sys
if sys.version_info >= (3, 11, 0):
    import tomllib
else:
    print(
        f"{Path(sys.argv[0]).name} requires Python 3.11.0 or newer for tomllib (running {'.'.join(map(str, sys.version_info[0:3]))})",
    )
    sys.exit(1)

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position

ROOT = Path(__file__).resolve().parent
RUST = Path(ROOT, 'rust')

FAILED = '\033[01;31mFAILED\033[0m'
SUCCESS = '\033[01;32mSUCCESS\033[0m'


def download_and_verify(url, dst):
    if dst.exists():
        return

    base_gpg_cmd = ['gpg', '--homedir', rust_gpg := Path(RUST, 'gpg')]
    if not rust_gpg.is_dir():
        if rust_gpg.exists():
            rust_gpg.unlink()
        rust_gpg.mkdir(parents=True)
        print(f"Preparing GPG folder ('{rust_gpg}')... ", end='')
        lib.utils.chronic([*base_gpg_cmd, '--recv-keys', '85AB96E6FA1BE5FE'])
        print(SUCCESS, end='\n\n')

    print(f"Downloading {url} to {dst}... ", end='')
    lib.utils.curl(url, output=dst)
    print(SUCCESS, end='\n\n')

    print(f"Downloading GPG signature for {dst.name}... ", end='')
    gpg_url = f"{url}.asc"
    (gpg_dst := Path(dst.parent, f"{dst.name}.asc")).unlink(missing_ok=True)
    lib.utils.curl(gpg_url, output=gpg_dst)
    print(SUCCESS, end='\n\n')

    print(f"Verifying {dst.name} with GPG signature... ", end='')
    lib.utils.chronic([*base_gpg_cmd, '--verify', gpg_dst, dst])
    print(SUCCESS, end='\n\n')
    gpg_dst.unlink()


def prepare_rust_components(toml, target):
    pkgs = [
        'cargo',
        'clippy-preview',
        'rustc',
        'rustfmt-preview',
        'rust-std',
        'rust-src',
    ]
    scripts = []

    for pkg in pkgs:
        # rust-src is target-agnostic, so it uses '*'
        idx = target if target in (pkg_targets := toml['pkg'][pkg]['target']) else '*'

        pkg_url, pkg_hash = pkg_targets[idx]['url'], pkg_targets[idx]['hash']
        pkg_name = pkg_url.rsplit('/', 1)[1]

        if not (dst := Path(RUST, pkg_name.rsplit('.', 2)[0])).exists():
            download_and_verify(pkg_url, pkg_tarball := Path(RUST, pkg_name))

            print(f"Validating {pkg_name} against hash ('{pkg_hash}')... ", end='')
            if (calc_hash := hashlib.sha256(pkg_tarball.read_bytes()).hexdigest()) != pkg_hash:
                print(f"{FAILED} (calculated hash: '{calc_hash}')")
                pkg_tarball.unlink()
                sys.exit(1)
            print(SUCCESS)

            print(f"Extracting {pkg_name} to {dst}... ", end='')
            lib.utils.chronic(['tar', '-C', RUST, '-xzf', pkg_tarball])
            print(SUCCESS, end='\n\n')

            pkg_tarball.unlink()
            print()

        scripts.append(Path(dst, 'install.sh'))

    return scripts


def generate_rust_toml(version):
    toml_url = f"https://static.rust-lang.org/dist/channel-rust-{version}.toml"
    if not (toml_dst := Path(RUST, toml_url.rsplit('/', 1)[1])).exists():
        download_and_verify(toml_url, toml_dst)
        print()

    # This pylint warning cannot tell that if we cannot import tomllib above,
    # the script exits.
    # pylint: disable-next=possibly-used-before-assignment
    return tomllib.loads(toml_dst.read_text(encoding='utf-8'))


def get_rust_target_from_tarball(tarball_path):
    # "llvm-<version>-<arch>.tar.<suffix>" -> ["llvm", "<version>", "<arch>.tar.<suffix>"]
    if len(name_parts := tarball_path.name.split('-')) != 3:
        raise RuntimeError(f"Unexpected name ('{tarball_path.name}') for tarball?")

    # "<arch>.tar.<suffix>" -> ["<arch>", "tar.<suffix>"] -> "<arch>"
    if (arch := name_parts[2].split('.', 1)[0]) not in ('aarch64', 'x86_64'):
        raise RuntimeError(f"Unexpected architecture ('{arch}') found?")

    return f"{arch}-unknown-linux-gnu"


def parse_arguments():
    parser = ArgumentParser(description='Install Rust toolchain into an LLVM toolchain tarball')

    parser.add_argument('version', help='Rust version to install')
    parser.add_argument('llvm_tarballs',
                        help='Toolchain tarball(s) to install Rust into',
                        nargs='+',
                        type=Path)

    for item in (arguments := parser.parse_args()).llvm_tarballs:
        if not item.exists():
            raise FileNotFoundError(f"Provided LLVM tarball ('{item}') does not exist?")

    return arguments


def generate_llvm_rust_tarball(scripts, llvm_tarball, rust_version):
    # "llvm-<llvm_version>-<arch>.<ext>" -> ["llvm", "<llvm_version>", "<arch>.<ext>"]
    tarball_parts = llvm_tarball.name.split('-')
    # ["llvm", "<llvm_version>", "<arch>.<ext>"] -> ["llvm", "<llvm_version>", "rust", "<rust_version>", "<arch>.<ext>"]
    tarball_parts[-1:-1] = ['rust', rust_version]
    llvm_rust_tarball = llvm_tarball.resolve().parent.joinpath('-'.join(tarball_parts))

    tar_cmd = ['tar']
    # If original LLVM tarball is compressed, we will need to pass in the
    # compression flag into both the extract command and the repackage command
    if (suffix := llvm_tarball.suffix) in ('.gz', '.xz', '.zstd'):
        tar_cmd.append('--gzip' if suffix == '.gz' else f"--{suffix.replace('.', '')}")
        # If llvm_rust_tarball were
        #   .../llvm-<llvm_ver>-rust-<rust_ver>-<arch>.tar.<ext>
        # llvm_rust_tarball.stem would give us
        #   llvm-<llvm_ver>-rust-<rust_ver>-<arch>.tar
        # but we want just
        #   llvm-<llvm_ver>-rust-<rust_ver>-<arch>
        prefix_name = llvm_rust_tarball.name.replace(f".tar{suffix}", '')
    elif suffix == '.tar':
        prefix_name = llvm_rust_tarball.stem
    else:
        raise RuntimeError(
            f"Destination tarball ('{llvm_rust_tarball}') does not have a suitable tarball extension?",
        )

    # Make sure we are working with a fresh prefix
    if (prefix := llvm_rust_tarball.parent.joinpath(prefix_name)).exists():
        shutil.rmtree(prefix)
    prefix.mkdir(parents=True)

    # Extract LLVM tarball into prefix
    lib.utils.run([
        *tar_cmd,
        '--directory',
        prefix,
        '--extract',
        '--file',
        llvm_tarball,
        '--strip-components=1',
    ])

    # Install Rust components into prefix
    for script in scripts:
        # Use '--disable-ldconfig' as the prefix is not '/usr/local'
        lib.utils.run([script, '--disable-ldconfig', f"--prefix={prefix}"])

    # Repackage prefix into LLVM+Rust tarball
    lib.utils.run([
        *tar_cmd,
        '--create',
        '--directory',
        prefix.parent,
        '--file',
        llvm_rust_tarball,
        prefix.name,
    ])
    shutil.rmtree(prefix)

    print(f"Modified tarball is now available at {llvm_rust_tarball}")


if __name__ == '__main__':
    args = parse_arguments()

    RUST.mkdir(exist_ok=True, parents=True)

    rust_toml = generate_rust_toml(args.version)

    for tarball in args.llvm_tarballs:
        # pylint only flags this variable, which is dumb.
        # pylint: disable-next=invalid-name
        rust_target = get_rust_target_from_tarball(tarball)

        install_scripts = prepare_rust_components(rust_toml, rust_target)

        generate_llvm_rust_tarball(install_scripts, tarball, args.version)

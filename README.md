# env

This repository contains my shell environment scripts and configurations. The layout is as follows:

* `bash/`: Files written for `bash`, mostly aimed at bootstrapping environments from the `root` user.
* `configs/`: Configuration files, such as for terminal programs, editors, and `tmux`.
* `fish/`: Files written for `fish`, my primary shell program.
* `pkgbuilds/`: My collection of PKGBUILD files for Arch Linux.
* `podman/`: My collection of container build files, mainly for use with `podman`.

## Container packages

I maintain [several container images](https://github.com/users/nathanchance/packages?repo_name=env) in this repo, mostly for my kernel development work, where I often need access to a wide variety of compilers. They include all the tools to build kernels for a variety of architectures.

A typical use case might look like:

```
$ podman run \
    --interactive \
    --rm \
    --tty \
    --volume=$PWD:/linux \
    --workdir=/linux \
    ghcr.io/nathanchance/gcc-11 \
    make -skj"$(nproc)" CROSS_COMPILE=x86_64-linux- defconfig all
```

They generally include QEMU as well, so that kernels can be easily boot tested (such as with [boot-utils](https://github.com/ClangBuiltLinux/boot-utils)):

```
$ podman run \
    --interactive \
    --rm \
    --tty \
    --volume=...:/boot-utils \
    --volume=$PWD:/linux \
    ghcr.io/nathanchance/gcc-11 \
    /boot-utils/boot-qemu.py -a x86_64 -k /linux -t 30s
...
[    0.000000] Linux version 5.16.0-rc8 (root@a729a83685d2) (gcc (Ubuntu 11.2.0-7ubuntu2) 11.2.0, GNU ld (GNU Binutils for Ubuntu) 2.37) #1 SMP PREEMPT Wed Jan 5 23:36:38 UTC 2022
...
```

## Support

You can take and use anything in this repo freely, as it is licensed under the MIT License. However, if you have any issues with using them, I do not provide any type of support, as I tailor everything in this repo entirely for my own set up and use cases. I have done my best to comment everything so it can easily be understood. I will accept pull requests if you feel something could be better!

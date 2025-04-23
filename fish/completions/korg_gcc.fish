set -l commands install latest folder var

function __korg_gcc_get_kmake_arch
    set tokens (commandline -cx)
    if test "$tokens[1]" != kmake
        return 1
    end

    for token in $tokens[2..]
        if string match -qr -- '^ARCH=(?<value>.*)$' $token
            echo $value
            return 0
        end
    end

    return 1
end

function __korg_gcc_get_targets
    PYTHONPATH=$PYTHON_SCRIPTS_FOLDER python3 -c "from korg_tc import GCCManager
print('\n'.join(GCCManager.TARGETS))"
end

function __korg_gcc_get_targets_for_var
    if set arch (__korg_gcc_get_kmake_arch)
        echo $arch
    else
        __korg_gcc_get_targets
    end
end

function __korg_gcc_get_versions
    PYTHONPATH=$PYTHON_SCRIPTS_FOLDER python3 -c "from korg_tc import GCCManager
print('\n'.join(map(str, GCCManager.VERSIONS)))"
end

function __korg_gcc_seen_target
    set targets (__korg_gcc_get_targets)
    for token in (commandline -xpc)
        if contains $token $targets
            return 0
        end
    end
    return 1
end

complete -c korg_gcc -f
complete -c korg_gcc -f -s h -l help -d "Show help message and exit"
complete -c korg_gcc -n "not __fish_seen_subcommand_from $commands" -f -d Subcommand -a "
    install\t'Download and/or extact kernel.org GCC tarballs to disk'
    latest\t'Print the latest stable release of a particular toolchain major version'
    folder\t'Print toolchain folder values for use in other contexts'
    var\t'Print toolchain variable for use with make'"

complete -c korg_gcc -n "__fish_seen_subcommand_from folder" -f -s b -l bin -d "Print {prefix}/bin"
complete -c korg_gcc -n "__fish_seen_subcommand_from folder" -f -s p -l prefix -d "Print {prefix}"

complete -c korg_gcc -n "__fish_seen_subcommand_from install" -f -s c -l clean-up-old-versions -d "Clean up older version of toolchains"
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -x -s H -l host-arch -d "The host architecture to download/install toolchains for" -a 'aarch64 x86_64'
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -x -s t -l targets -d "Toolchain targets to download" -a '(__korg_gcc_get_targets)'
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -x -s v -l versions -d "Toolchain versions to download" -a '(__korg_gcc_get_versions)'
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -x -l download-folder -d "Folder to store downloaded tarballs" -a '(__fish_complete_directories)'
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -x -l install-folder -d "Folder to store extracted toolchains for use" -a '(__fish_complete_directories)'
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -f -l cache -d "Save downloaded toolchain tarballs to disk"
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -f -l no-cache -d "Do not save downloaded toolchain tarballs to disk"
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -f -l extract -d "Unpack downloaded toolchain tarballs to disk"
complete -c korg_gcc -n "__fish_seen_subcommand_from install" -f -l no-extract -d "Do not unpack downloaded toolchain tarballs to disk"

complete -c korg_gcc -n "__fish_seen_subcommand_from latest" -f -d "Major version" -a '(__korg_gcc_get_versions)'

complete -c korg_gcc -n "__fish_seen_subcommand_from var; and not __korg_gcc_seen_target" -f -d Target -a '(__korg_gcc_get_targets_for_var)'
complete -c korg_gcc -n "__fish_seen_subcommand_from var; and __korg_gcc_seen_target" -f -d Version -a '(__korg_gcc_get_versions)'

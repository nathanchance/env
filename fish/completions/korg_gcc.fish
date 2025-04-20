set -l commands install latest folder var

function __korg_gcc_get_targets
    PYTHONPATH=$PYTHON_SCRIPTS_FOLDER python3 -c "from korg_tc import GCCManager
print('\n'.join(GCCManager.TARGETS))"
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

complete -f -c korg_gcc
complete -f -c korg_gcc -s h -l help -d "Show help message and exit"
complete -f -c korg_gcc -n "not __fish_seen_subcommand_from $commands" -d Subcommand -a "
    install\t'Download and/or extact kernel.org GCC tarballs to disk'
    latest\t'Print the latest stable release of a particular toolchain major version'
    folder\t'Print toolchain folder values for use in other contexts'
    var\t'Print toolchain variable for use with make'"

complete -f -c korg_gcc -n "__fish_seen_subcommand_from folder" -s b -l bin -d "Print {prefix}/bin"
complete -f -c korg_gcc -n "__fish_seen_subcommand_from folder" -s p -l prefix -d "Print {prefix}"

complete -f -c korg_gcc -n "__fish_seen_subcommand_from install" -s c -l clean-up-old-versions -d "Clean up older version of toolchains"
complete -x -c korg_gcc -n "__fish_seen_subcommand_from install" -s H -l host-arch -d "The host architecture to download/install toolchains for" -a 'aarch64 x86_64'
complete -x -c korg_gcc -n "__fish_seen_subcommand_from install" -s t -l targets -d "Toolchain targets to download" -a '(__korg_gcc_get_targets)'
complete -x -c korg_gcc -n "__fish_seen_subcommand_from install" -s v -l versions -d "Toolchain versions to download" -a '(__korg_gcc_get_versions)'
complete -x -c korg_gcc -n "__fish_seen_subcommand_from install" -l download-folder -d "Folder to store downloaded tarballs" -a '(__fish_complete_directories (commandline -ct))'
complete -x -c korg_gcc -n "__fish_seen_subcommand_from install" -l install-folder -d "Folder to store extracted toolchains for use" -a '(__fish_complete_directories (commandline -ct))'
complete -f -c korg_gcc -n "__fish_seen_subcommand_from install" -l cache -d "Save downloaded toolchain tarballs to disk"
complete -f -c korg_gcc -n "__fish_seen_subcommand_from install" -l no-cache -d "Do not save downloaded toolchain tarballs to disk"
complete -f -c korg_gcc -n "__fish_seen_subcommand_from install" -l extract -d "Unpack downloaded toolchain tarballs to disk"
complete -f -c korg_gcc -n "__fish_seen_subcommand_from install" -l no-extract -d "Do not unpack downloaded toolchain tarballs to disk"

complete -f -c korg_gcc -n "__fish_seen_subcommand_from latest" -d "Major version" -a '(__korg_gcc_get_versions)'

complete -f -c korg_gcc -n "__fish_seen_subcommand_from var; and not __korg_gcc_seen_target" -d Target -a '(__korg_gcc_get_targets)'
complete -f -c korg_gcc -n "__fish_seen_subcommand_from var; and __korg_gcc_seen_target" -d Version -a '(__korg_gcc_get_versions)'

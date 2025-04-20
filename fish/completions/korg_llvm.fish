set -l commands install latest folder var

function __korg_llvm_get_versions
    PYTHONPATH=$PYTHON_SCRIPTS_FOLDER python3 -c "from korg_tc import LLVMManager
print('\n'.join(map(str, LLVMManager.VERSIONS)))"
end

complete -c korg_llvm -f
complete -c korg_llvm -f -s h -l help -d "Show help message and exit"
complete -c korg_llvm -n "not __fish_seen_subcommand_from $commands" -f -d Subcommand -a "
    install\t'Download and/or extact kernel.org LLVM tarballs to disk'
    latest\t'Print the latest stable release of a particular toolchain major version'
    folder\t'Print toolchain folder values for use in other contexts'
    var\t'Print toolchain variable for use with make'"

complete -c korg_llvm -n "__fish_seen_subcommand_from folder" -f -s b -l bin -d "Print {prefix}/bin"
complete -c korg_llvm -n "__fish_seen_subcommand_from folder" -f -s p -l prefix -d "Print {prefix}"

complete -c korg_llvm -n "__fish_seen_subcommand_from install" -f -s c -l clean-up-old-versions -d "Clean up older version of toolchains"
complete -c korg_llvm -n "__fish_seen_subcommand_from install" -x -s H -l host-arch -d "The host architecture to download/install toolchains for" -a 'aarch64 x86_64'
complete -c korg_llvm -n "__fish_seen_subcommand_from install" -x -s v -l versions -d "Toolchain versions to download" -a '(__korg_llvm_get_versions)'
complete -c korg_llvm -n "__fish_seen_subcommand_from install" -x -l download-folder -d "Folder to store downloaded tarballs" -a '(__fish_complete_directories (commandline -ct))'
complete -c korg_llvm -n "__fish_seen_subcommand_from install" -x -l install-folder -d "Folder to store extracted toolchains for use" -a '(__fish_complete_directories (commandline -ct))'
complete -c korg_llvm -n "__fish_seen_subcommand_from install" -f -l cache -d "Save downloaded toolchain tarballs to disk"
complete -c korg_llvm -n "__fish_seen_subcommand_from install" -f -l no-cache -d "Do not save downloaded toolchain tarballs to disk"
complete -c korg_llvm -n "__fish_seen_subcommand_from install" -f -l extract -d "Unpack downloaded toolchain tarballs to disk"
complete -c korg_llvm -n "__fish_seen_subcommand_from install" -f -l no-extract -d "Do not unpack downloaded toolchain tarballs to disk"

complete -c korg_llvm -n "__fish_seen_subcommand_from latest" -f -d "Major version" -a '(__korg_llvm_get_versions)'

complete -c korg_llvm -n "__fish_seen_subcommand_from var" -f -d "Major version" -a '(__korg_llvm_get_versions)'
complete -c korg_llvm -n "__fish_seen_subcommand_from var" -f -s s -l split -d "Split toolchain variable for use with kmake"

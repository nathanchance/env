set -l commands install latest folder var

function __korg_llvm_get_versions
    PYTHONPATH=$PYTHON_SCRIPTS_FOLDER python3 -c "from korg_tc import LLVMManager
print('\n'.join(map(str, LLVMManager.VERSIONS)))"
end

complete -f -c korg_llvm
complete -f -c korg_llvm -s h -l help -d "Show help message and exit"
complete -f -c korg_llvm -n "not __fish_seen_subcommand_from $commands" -a "$commands"

complete -f -c korg_llvm -n "__fish_seen_subcommand_from folder" -s b -l bin -d "Print {prefix}/bin"
complete -f -c korg_llvm -n "__fish_seen_subcommand_from folder" -s p -l prefix -d "Print {prefix}"

complete -f -c korg_llvm -n "__fish_seen_subcommand_from install" -s c -l clean-up-old-versions -d "Clean up older version of toolchains"
complete -x -c korg_llvm -n "__fish_seen_subcommand_from install" -s H -l host-arch -d "The host architecture to download/install toolchains for" -a 'aarch64 x86_64'
complete -x -c korg_llvm -n "__fish_seen_subcommand_from install" -s v -l versions -d "Toolchain versions to download" -a '(__korg_llvm_get_versions)'
complete -x -c korg_llvm -n "__fish_seen_subcommand_from install" -l download-folder -d "Folder to store downloaded tarballs" -a '(__fish_complete_directories (commandline -ct))'
complete -x -c korg_llvm -n "__fish_seen_subcommand_from install" -l install-folder -d "Folder to store extracted toolchains for use" -a '(__fish_complete_directories (commandline -ct))'
complete -f -c korg_llvm -n "__fish_seen_subcommand_from install" -l cache -d "Save downloaded toolchain tarballs to disk"
complete -f -c korg_llvm -n "__fish_seen_subcommand_from install" -l no-cache -d "Do not save downloaded toolchain tarballs to disk"
complete -f -c korg_llvm -n "__fish_seen_subcommand_from install" -l extract -d "Unpack downloaded toolchain tarballs to disk"
complete -f -c korg_llvm -n "__fish_seen_subcommand_from install" -l no-extract -d "Do not unpack downloaded toolchain tarballs to disk"

complete -f -c korg_llvm -n "__fish_seen_subcommand_from latest" -d "Major version" -a '(__korg_llvm_get_versions)'

complete -f -c korg_llvm -n "__fish_seen_subcommand_from var" -d "Major version" -a '(__korg_llvm_get_versions)'
complete -f -c korg_llvm -n "__fish_seen_subcommand_from var" -s s -l split -d "Split toolchain variable for use with kmake"

function __cbl_bld_krnl_vm_get_arch
    # Check if '-a' / '--arch' was found on the command line
    set tokens (commandline -xpc)
    if set index (contains -i -- -a $tokens); or set index (contains -i -- --arch $tokens)
        set arch $tokens[(math $index + 1)]
    else
        set arch (uname -m)
    end
    switch $arch
        case arm64
            echo aarch64
        case armv7l
            echo arm
        case '*'
            echo $arch
    end
end

function __cbl_bld_krnl_vm_get_tc_args
    string join \n -- gcc-$GCC_VERSIONS_KERNEL llvm-$LLVM_VERSIONS_KERNEL
end

complete -c cbl_bld_krnl_vm -f -s h -l help -d "Show help message and exit"
complete -c cbl_bld_krnl_vm -x -s a -l arch -d "Architecture to build and boot" -a "arm armv7l aarch64 arm64 x86_64"
complete -c cbl_bld_krnl_vm -x -s c -l config -d "Use custom configuration target"
complete -c cbl_bld_krnl_vm -x -s C -l directory -d "Path to kernel source" -a '(__fish_complete_directories)'
complete -c cbl_bld_krnl_vm -f -s m -l menuconfig -d "Run menuconfig after localyesconfig"
complete -c cbl_bld_krnl_vm -x -s n -l vm-name -d "Name of virtual machine" -a '(path basename $VM_FOLDER/(__cbl_bld_krnl_vm_get_arch)/*)'
complete -c cbl_bld_krnl_vm -x -s t -l toolchain -d Toolchain -a '(__cbl_bld_krnl_vm_get_tc_args)'
complete -c cbl_bld_krnl_vm -x -l additional-targets -d "Call target before 'all' target"

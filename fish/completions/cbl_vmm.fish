set -l run_commands remove run setup
set -l valid_arches aarch64 arm64 arm armv7l i386 i686 x86_64

function __cbl_vmm_get_arch
    set tokens (commandline -xpc) (commandline -ct)
    if set index (contains -i -- -a $tokens) (contains -i -- --architecture $tokens)
        echo $tokens[(math $index + 1)]
    else
        echo (uname -m)
    end
end

function __cbl_vmm_ssh_ports
    for base in (seq 8022 8032)
        if not lsof -i :$base
            break
        end
    end
    seq $base (math $base + 8)
end

function __cbl_vmm_get_vms
    set arch (__cbl_vmm_get_arch)
    switch $arch
        case arm64
            set arch aarch64
        case armv7l
            set arch arm
        case i686
            set arch i386
    end
    path basename $VM_FOLDER/$arch/*
end

complete -f -c cbl_vmm
complete -f -c cbl_vmm -s h -l help -d "Show help message and exit"
complete -f -c cbl_vmm -n "not __fish_seen_subcommand_from list $run_commands" -d Subcommand -a "
    list\t'List virtual machines that can be run'
    remove\t'Remove virtual machine files'
    run\t'Run virtual machine after setup'
    setup\t'Run virtual machine for first time'"

complete -x -c cbl_vmm -n "__fish_seen_subcommand_from list run remove" -s a -l architecture -d "Architecture of virtual machine" -a '(path basename $VM_FOLDER/* | string match -v iso)'
complete -x -c cbl_vmm -n "__fish_seen_subcommand_from setup" -s a -l architecture -d "Architecture of virtual machine" -a "$valid_arches"

complete -x -c cbl_vmm -n "__fish_seen_subcommand_from run remove" -s n -l name -d "Name of virtual machine" -a '(__cbl_vmm_get_vms)'
complete -x -c cbl_vmm -n "__fish_seen_subcommand_from setup" -s n -l name -d "Name of virtual machine"

complete -x -c cbl_vmm -n "__fish_seen_subcommand_from $run_commands" -s c -l cores -d "Number of cores for virtual machine"
complete -x -c cbl_vmm -n "__fish_seen_subcommand_from $run_commands" -s m -l memory -d "Amount of memory in gigabytes to allocate to virtual machine"
complete -x -c cbl_vmm -n "__fish_seen_subcommand_from $run_commands" -s p -l ssh-port -d "Port to forward ssh on" -a '(__cbl_vmm_ssh_ports)'
complete -x -c cbl_vmm -n "__fish_seen_subcommand_from $run_commands" -s P -l profile -d "Choose a specific profile, which customizes the default ratio of cores and memory" -a "regular build"

complete -x -c cbl_vmm -n "__fish_seen_subcommand_from setup" -s i -l iso -d "Path or URL of .iso to boot from"
complete -x -c cbl_vmm -n "__fish_seen_subcommand_from setup" -s s -l size -d "Size of virtual machine disk image in gigabytes"

complete -x -c cbl_vmm -n "__fish_seen_subcommand_from run" -s C -l cmdline -d "Kernel cmdline string"
complete -f -c cbl_vmm -n "__fish_seen_subcommand_from run" -s g -l gdb -d "Start QEMU with '-s -S' for debugging with gdb"
complete -x -c cbl_vmm -n "__fish_seen_subcommand_from run" -s i -l initrd -d "Path to initrd"
complete -x -c cbl_vmm -n "__fish_seen_subcommand_from run" -s k -l kernel -d "Path to kernel image or kernel build directory"

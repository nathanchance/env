complete -c cbl_upd_krnl -f
complete -c cbl_upd_krnl -f -s r -l reboot -d "Reboot system after updating kernel"
if test (__get_distro) = arch
    complete -c cbl_upd_krnl -f -s k -l kexec -d "Kexec system after updating kernel"

    set -l valid_arch_krnls {linux-,}{debug,{mainline,next}-llvm}
    complete -c cbl_upd_krnl -x -n "not __fish_seen_argument $valid_arch_krnls" -d Kernel -a "$valid_arch_krnls"
end

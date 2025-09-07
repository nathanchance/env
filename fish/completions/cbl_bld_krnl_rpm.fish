complete -c cbl_bld_krnl_rpm -f -l cfi -d "Enable CONFIG_CFI"
complete -c cbl_bld_krnl_rpm -f -l cfi-permissive -d "Enable CONFIG_CFI_PERMISSIVE"
complete -c cbl_bld_krnl_rpm -f -l debug -d "Force enable debug info"
complete -c cbl_bld_krnl_rpm -f -l lto -d "Enable CONFIG_LTO_CLANG_THIN"
complete -c cbl_bld_krnl_rpm -f -l no-debug -d "Force disable debug info"
complete -c cbl_bld_krnl_rpm -f -l no-werror -d "Disable CONFIG_WERROR"
complete -c cbl_bld_krnl_rpm -f -l slim-arm64-platforms -d "Disable unnecessary arm64 platforms for slimmer build"
complete -c cbl_bld_krnl_rpm -f -s g -l gcc -d "Build with GCC instead of LLVM"
complete -c cbl_bld_krnl_rpm -f -s l -l localmodconfig -d "Call localmodconfig during configuration"
complete -c cbl_bld_krnl_rpm -f -s m -l menuconfig -d "Call menuconfig during configuration"
complete -c cbl_bld_krnl_rpm -f -s n -l no-config -d "Do not automatically create configuration"

function __cbl_bld_krnl_rpm_pos_args
    set -l valid_architectures aarch64 arm64 amd64 x86_64
    string join \n -- $valid_architectures\t"Kernel architecture"
end
complete -c cbl_bld_krnl_rpm -f -d "Positional arguments" -a '(__cbl_bld_krnl_rpm_pos_args)'

complete -c cbl_bld_krnl_pkg -f -l cfi -d "Enable CONFIG_CFI"
complete -c cbl_bld_krnl_pkg -f -l cfi-permissive -d "Enable CONFIG_CFI_PERMISSIVE"
complete -c cbl_bld_krnl_pkg -f -l lto -d "Enable CONFIG_LTO_CLANG_THIN"
complete -c cbl_bld_krnl_pkg -f -s g -l gcc -d "Build with GCC instead of LLVM"
complete -c cbl_bld_krnl_pkg -f -s l -l localmodconfig -d "Call localmodconfig during configuration"
complete -c cbl_bld_krnl_pkg -f -s m -l menuconfig -d "Call menuconfig during configuration"
complete -c cbl_bld_krnl_pkg -f -l no-werror -d "Disable CONFIG_WERROR"
complete -c cbl_bld_krnl_pkg -x -s R -l ref -d "Reference to base kernel tree on"
complete -c cbl_bld_krnl_pkg -f -d "Positional arguments" -a '(string join \n -- $VALID_ARCH_KRNLS\t"Kernel package")'

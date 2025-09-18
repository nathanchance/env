function __cbl_bld_llvm_korg_gen_vers
    PYTHONPATH=$PYTHON_FOLDER/pgo-llvm-builder python3 -c 'from build import LLVM_VERSIONS
for ver in LLVM_VERSIONS:
    print(ver)'
end

complete -c cbl_bld_llvm_korg -f -s b -l build-env -d "Build environment with mkosi"
complete -c cbl_bld_llvm_korg -f -s r -l reset -d "Delete outputs of previous runs"
complete -c cbl_bld_llvm_korg -f -s s -l skip-tests -d "Skip running tests"
complete -c cbl_bld_llvm_korg -f -l slim-pgo -d "Perform slim PGO instead of full PGO"
complete -c cbl_bld_llvm_korg -f -s t -l test-linux -d "Build Linux with toolchain"
complete -c cbl_bld_llvm_korg -x -d "LLVM version" -a '(__cbl_bld_llvm_korg_gen_vers)'

function __kmake_get_srctree
    # Check if '-C' / '--directory' was found on the command line
    set tokens (commandline -xpc)
    if set index (contains -i -- -C $tokens); or set index (contains -i -- --directory $tokens)
        path resolve $tokens[(math $index + 1)]
    else
        echo $PWD
    end
end

function __kmake_get_srcarch
    # Check if ARCH is already set from the command line
    for token in (commandline -xpc)
        if string match -qr -- '^ARCH=' $token
            set arch (string split -f 2 = $token)
            switch $arch
                case i386 x86_64
                    set srcarch x86
                case '*'
                    set srcarch $arch
            end
            break
        end
    end
    # If ARCH= was not found, look at the host machine
    if not set -q srcarch
        switch $UTS_MACH
            case arm64 aarch64'*'
                set srcarch arm64
            case x86_64
                set srcarch x86
        end
    end
    echo $srcarch
end

function __kmake_handle_make_var
    string match -qr -- "(?<name>.+)=(?<value>.*)" (commandline -ct)
    or return

    switch $name
        case ARCH
            set desc architecture

            # sub-directories under arch/
            set srctree (__kmake_get_srctree)
            set -a vals (path filter -d $srctree/arch/* | path basename)
            # architectures hard-coded in the top Makefile
            set -a vals i386 x86_64 sparc32 sparc64 parisc64

        case CROSS_COMPILE
            set desc toolchain

            set -a vals (path filter -x $PATH/*elfedit | path basename | string replace elfedit '' | path sort -u)

            if test -n "$value"
                set file_comps (complete -C "__fish_command_without_completions $value")
                set possible_vals (string match -er 'elfedit$' $file_comps | string replace elfedit '' | path sort -u)
                if test -n "$possible_vals"
                    set -a vals $possible_vals
                else
                    set -a vals $file_comps
                end
            end

        case LLVM
            set desc toolchain

            set dash_vals -(path filter -x $PATH/ld.lld-* | path basename | path sort -u | string replace ld.lld- '')

            if test -n "$value"
                if string match -qr '^-' -- $value
                    set -a vals $dash_vals
                else
                    set -a vals (complete -C "__fish_command_without_completions $value")
                end
            else
                set -a vals 1
                set -a vals (path filter -x $PATH/clang | path resolve | path dirname | path sort -u)/
                set -a vals $dash_vals
            end
    end

    string join \n -- $name=$vals\t$desc
end

function __kmake_pos_args
    set srctree (__kmake_get_srctree)
    # obviously not in a kernel tree, do not suggest anything
    if not test -e $srctree/Makefile
        return 0
    end
    set srcarch (__kmake_get_srcarch)

    for token in (commandline -xpc)
        if set var (string split -f 1 -- = $token)
            set -a defined_vars $var
        end
    end

    # Dynamic variables (not exhaustive)
    set possible_dynamic_vars \
        ARCH \
        CROSS_COMPILE \
        KCONFIG_ALLCONFIG \
        LLVM \
        O \
        V \
        W \
        INSTALL{,_MOD,_HDR,_DTBS}_PATH
    for var in $possible_dynamic_vars
        if not contains $var $defined_vars
            set -a dynamic_vars $var
        end
    end

    # Static variables that only have one option
    set possible_static_vars \
        LLVM_IAS
    for var in $possible_static_vars
        if contains $var $defined_vars
            continue
        end

        switch $var
            case LLVM_IAS
                if test -e $srctree/scripts/Makefile.clang
                    set -a static_vars LLVM_IAS=0
                else
                    set -a static_vars LLVM_IAS=1
                end
        end
    end

    # Targets
    set targets \
        all help \
        clean mrproper distclean \
        clang-{tidy,analyzer} compile_commands.json \
        coccicheck \
        dtbs{,_check,_install} dt_binding_{check,schemas} \
        headers{,_install} \
        vmlinux install \
        modules{,_prepare,_install,_sign} \
        vdso_install \
        tags TAGS cscope gtags \
        rust{available,fmt,fmtcheck} \
        kernel{version,release} image_name \
        kselftest{,-all,-install,-clean,-merge}
    # Include common architecture image targets
    switch $srcarch
        case arm
            set -a targets zImage
        case arm64
            set -a targets Image{.gz,}
        case loongarch
            set -a targets vmlinuz.efi
        case powerpc
            set -a targets zImage.epapr
        case riscv
            set -a targets Image
        case s390 x86
            set -a targets bzImage
    end

    set configs \
        {,old,olddef,sync,def,savedef,rand,listnew,helpnew,test,tiny}config \
        {,build_}{menu,n,g,x}config \
        local{mod,yes}config \
        all{no,yes,mod,def}config \
        {yes2mod,mod2yes,mod2no}config
    for cfg in (path basename $srctree/{arch/$srcarch,kernel}/configs/*)
        if not contains $cfg $configs
            set -a configs $cfg
        end
    end
    if test "$srcarch" = powerpc; and test -e $srctree/arch/powerpc/Makefile
        # Account for https://git.kernel.org/linus/22db99d673641d37c4e184ca8cff95d8441986af
        set -a configs (string match -gr 'generated_configs \+= (.*)$' <$srctree/arch/powerpc/Makefile
                        or string match -gr 'PHONY \+= (.*config)$' <$srctree/arch/powerpc/Makefile)
    end

    set docs \
        {html,textinfo,info,latex,pdf,epub,xml,linkcheck,refcheck,clean}docs

    set packages \
        {,bin,src}{rpm,deb}-pkg \
        {pacman,dir,tar}-pkg \
        tar{,gz,bz2,xz,zst}-pkg \
        perf-tar{,gz,bz2,xz,zst}-src-pkg

    string join \n -- \
        $dynamic_vars=\t'make variable' \
        $static_vars\t'make variable' \
        $configs\t'config target' \
        $targets\t'build target'

    # We do not care about potential targets in:
    #   Documentation
    #   scripts
    #   tools
    # and we only care about targets for the current srcarch.
    set top_level_dirs (path filter -f $srctree/*/Makefile | path dirname | path basename | string match -erv "^(?:Documentation|scripts|tools)") arch/$srcarch

    # First, see if we have started a token already
    set token (commandline -ct)
    if test -z "$token"
        # If not, just show the available top level directories, as there
        # is not much else that makes sense to suggest at this point.
        string join \n -- $top_level_dirs/\t'directory target'
    else
        # If we have started a token, check to see if it contains a slash
        # yet (implicitly through the return code of 'string split') and
        # that the first part is a part of the valid top level directories,
        # as we may be completing a configuration value.
        if set base_top_level_dir (string split -f 1 -- / $token); and contains $base_top_level_dir $top_level_dirs arch
            # If it does, only show the next level of directory options. More
            # could produce too much output for little gain in selections.
            set token_limit (math (string split -- / $token | count) + 1)

            # fd to quickly find Makefiles in directories that could be reched
            # with the current selection. By sorting by dirname, we can bail
            # out of the for loop as soon as we encounter an item longer than
            # our limit.
            fd -g Makefile (path filter -d $srctree/$token*) | string replace $srctree/ '' | path dirname | path sort --key dirname | while read -l possible_folder
                if test (string split -- / $possible_folder | count) -gt $token_limit
                    break
                end
                echo $possible_folder/\t'directory target'
            end

            # Show any possible .o targets (typically from .c and .S files)
            # that could be built with the current selection
            string join \n -- (path filter -f $srctree/$token*.{c,S} | string replace $srctree/ '' | path change-extension .o)\t'object target'
        else
            # Filter top level directories to only ones that can be matched with current selection
            string join \n -- (string match -er -- "^$token" $top_level_dirs)/\t'directory target'
        end
    end

    string join \n -- \
        $docs\t'docs target' \
        $packages\t'package target'
end

# Options
complete -c kmake -x -s h -l help -d "Show help message and exit"
complete -c kmake -x -s C -l directory -d "Mirrors the equivalent make argument" -a '(__fish_complete_directories)'
complete -c kmake -f -l no-ccache -d "Disable the use of ccache"
complete -c kmake -f -l omit-hostldflags -d "Avoid default use of HOSTLDFLAGS="
complete -c kmake -f -l omit-o-arg -d "Avoid default use of O="
complete -c kmake -x -s p -l prepend-to-path -d "Prepend specified directory to PATH" -a '(__fish_complete_directories)'
complete -c kmake -x -s j -l jobs -d "Number of jobs"
complete -c kmake -f -l use-time -d "Call 'time -v' for time tracking"
complete -c kmake -x -s v -l verbose -d "Do a more verbose build"

# Positional arguments
complete -c kmake -n 'not string match -eq = -- (commandline -ct)' -f -k -a '(__kmake_pos_args)'
complete -c kmake -n 'string match -eq = -- (commandline -ct)' -f -a '(__kmake_handle_make_var)'

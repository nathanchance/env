function __kmake_get_srctree
    set tokens (commandline -xpc)
    if set index (contains -i -- -C $tokens) (contains -i -- --directory $tokens)
        echo $tokens[(math $index + 1)]
    else
        echo $PWD
    end
end

function __kmake_get_srcarch
    for token in (commandline -xpc)
        if string match -qr -- '^ARCH=' $token
            set arch (string split -f 2 = $token)
            switch $srcarch
                case i386 x86_64
                    set srcarch x86
                case '*'
                    set srcarch $arch
            end
        end
    end
    if not set -q srcarch
        switch (uname -m)
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
            # sub-directories under arch/
            set srctree (__kmake_get_srctree)
            set -a vals (path filter -t dir $srctree/arch/* | path basename)
            # architectures hard-coded in the top Makefile
            set -a vals i386 x86_64 sparc32 sparc64 parisc64

        case LLVM
            set -a vals 1
            for val in $PATH/clang
                if test -e $val
                    set val (path dirname $val | path resolve)/
                    if not contains $val $vals
                        set -a vals $val
                    end
                end
            end
    end

    set vals (string match -er -- "^$value" $vals)
    string join \n -- $name=$vals
end

function __kmake_pos_args
    set srctree (__kmake_get_srctree)
    set srcarch (__kmake_get_srcarch)

    # Variables (not exhaustive)
    set vars \
        ARCH \
        CROSS_COMPILE \
        KCONFIG_ALLCONFIG \
        LLVM \
        O \
        V \
        W \
        INSTALL{,_MOD,_HDR,_DTBS}_PATH

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

    set docs \
        {html,textinfo,info,latex,pdf,epub,xml,linkcheck,refcheck,clean}docs

    set packages \
        {,bin,src}{rpm,deb}-pkg \
        {pacman,dir,tar}-pkg \
        tar{,gz,bz2,xz,zst}-pkg \
        perf-tar{,gz,bz2,xz,zst}-src-pkg

    string join \n -- $vars= $targets $configs $docs $packages
end

# Options
complete -f -c kmake -s h -l help -d "Show help message and exit"
complete -x -c kmake -s C -l directory -d "Mirrors the equivalent make argument" -a '(__fish_complete_directories (commandline -ct))'
complete -f -c kmake -l no-ccache -d "Disable the use of ccache"
complete -f -c kmake -l omit-o-arg -d "Avoid default use of O="
complete -x -c kmake -s p -l prepend-to-path -d "Prepend specified directory to PATH" -a '(__fish_complete_directories (commandline -ct))'
complete -x -c kmake -s j -l jobs -d "Number of jobs"
complete -f -c kmake -l use-time -d "Call 'time -v' for time tracking"
complete -f -c kmake -s v -l verbose -d "Do a more verbose build"

# Positional arguments
complete -f -c kmake -n 'not string match -eq = -- (commandline -ct)' -a '(__kmake_pos_args)' -f
complete -f -c kmake -n 'string match -eq = -- (commandline -ct)' -a '(__kmake_handle_make_var)' -f

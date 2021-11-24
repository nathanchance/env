#!/usr/bin/env fish

function error
    printf '\n%bERROR: %s%b\n\n' '\033[01;31m' $argv '\033[0m'
    exit 1
end

function check_user
    if test "$USER" != build
        error "This script should be run as a build user"
    end
end

function setup_gpg
    set gpg_dir $HOME/.gnupg
    set gpg_conf $gpg_dir/gpg.conf

    mkdir $HOME/.gnupg
    echo "keyserver-options auto-key-retrieve" >$gpg_conf
end

function build_cvise
    # First, build and install python-pebble
    set python_pebble $HOME/python-pebble
    git clone https://aur.archlinux.org/python-pebble.git $python_pebble; or exit
    cd $python_pebble; or exit
    makepkg -irs --noconfirm; or exit

    # Next, fetch cvise PKGBUILD
    set cvise $HOME/cvise
    mkdir $cvise
    cd $cvise; or exit
    curl -LSsO https://github.com/nathanchance/env/raw/main/pkgbuilds/cvise/PKGBUILD
    makepkg -irs --noconfirm
end

check_user
setup_gpg
build_cvise

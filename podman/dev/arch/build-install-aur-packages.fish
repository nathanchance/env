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
    cd $HOME/pkgbuilds/python-pebble; or exit
    makepkg -irs --noconfirm; or exit

    cd $HOME/pkgbuilds/cvise; or exit
    makepkg -irs --noconfirm
end

check_user
setup_gpg
build_cvise

#!/usr/bin/env fish

__in_container_msg -h
or return

set ltp $SRC_FOLDER/ltp
if not test -e $ltp
    mkdir -p (path dirname $ltp)
    git clone https://github.com/linux-test-project/ltp $ltp
    or return
end
git -C $ltp urh
or return

set base_podman_cmd \
    podman run \
    --interactive \
    --pull newer \
    --rm \
    --tty \
    --volume $SRC_FOLDER/ltp:/ltp:z \
    --workdir /ltp
set image_shell_cmd \
    docker.io/alpine:edge \
    /bin/sh -c 'apk upgrade &&
apk add autoconf automake gcc git linux-headers make musl-dev pkgconf &&
git clean -fxdq &&
make -skj"$(nproc)" autotools &&
./configure LDFLAGS=-static &&
cd testcases/kernel/fs/read_all &&
make -j"$(nproc)" &&
strip read_all'

$base_podman_cmd $image_shell_cmd
or return

set src_read_all $ltp/testcases/kernel/fs/read_all/read_all
set dst_read_all $ENV_FOLDER/bin/$UTS_MACH/read_all

if __is_location_primary
    cp -v $src_read_all $dst_read_all
else
    scp $src_read_all nathan@(get_ip main):(string replace $MAIN_FOLDER /home/$USER $dst_read_all)
end
or return

if test "$UTS_MACH" = aarch64
    $base_podman_cmd --arch arm $image_shell_cmd
    or return

    scp $src_read_all nathan@(get_ip main):(string replace $MAIN_FOLDER /home/$USER $dst_read_all | string replace aarch64 armv7l)
    or return
end

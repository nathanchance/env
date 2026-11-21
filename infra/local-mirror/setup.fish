#!/usr/bin/env fish

set src_dir (status dirname | path resolve)
set container_name (path basename $src_dir)
set nspawn_file /etc/systemd/nspawn/$container_name.nspawn
set host_data_dir /srv/$container_name
set container_data_dir /srv/mirror

run_mkosi build $src_dir
or return

set nspawn_bind_val $host_data_dir:$container_data_dir:idmap
set old_nspawn_file_text (cat $nspawn_file 2>/dev/null)
set new_nspawn_file_text "[Exec]
Boot=yes
Hostname=$container_name
PrivateUsers=pick

[Files]
Bind=$nspawn_bind_val
PrivateUsersOwnership=auto

[Network]
VirtualEthernet=no"
if not test -e $nspawn_file; or test (echo "$old_nspawn_file_text" | tr -d "[:space:]") != (echo "$new_nspawn_file_text" | tr -d "[:space:]")
    header "Updating "(path basename $nspawn_file)

    echo "$new_nspawn_file_text" | run0 tee $nspawn_file
    or return
end

if not test -d $host_data_dir
    header "Preparing $host_data_dir"

    run0 mkdir -v $host_data_dir
    or return
end

header "Running systemd-spawn for initial setup"
run0 systemd-nspawn \
    --machine=$container_name \
    --register=no \
    --quiet \
    --settings=no \
    --as-pid2 \
    --private-users=pick \
    --bind=$nspawn_bind_val \
    --bind-ro=$src_dir/setup_container.py:/setup_container.py \
    --private-users-ownership=auto \
    /usr/bin/python3 /setup_container.py
or return

# 500 is the UID of our nginx user
run0 chown -R 500:500 $host_data_dir

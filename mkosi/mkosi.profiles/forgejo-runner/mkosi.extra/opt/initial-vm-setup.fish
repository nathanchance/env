#!/usr/bin/env fish

read -P 'Token from https://codeberg.org/user/settings/actions/runners: ' token
if test -z "$token"
    echo Token is empty?
    return 1
end

pushd /var/lib/forgejo-runner
or return

set label_name docker
if test (nproc) -gt 8
    set label_name $label_name-build
end
set label $label_name:docker://data.forgejo.org/oci/node:lts

forgejo-runner register \
    --config /etc/forgejo-runner/config.y* \
    --instance https://codeberg.org/ \
    --labels $label \
    --name $hostname \
    --no-interactive \
    --token $token
or return

chown forgejo-runner:forgejo-runner .runner
or return

systemctl start forgejo-runner.service
or return

popd

begin
    umask 077
    and mkdir -p $HOME/.ssh
    and curl -fLSs https://codeberg.org/nathanchance.keys >$HOME/.ssh/authorized_keys
end
or return

rm /opt/initial-vm-setup.fish

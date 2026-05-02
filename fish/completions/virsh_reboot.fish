complete -c virsh_reboot -x -d domain -a '(__virsh_get_running_domains) all'
complete -c virsh_reboot -f -s a -l all -d 'Reboot all domains'

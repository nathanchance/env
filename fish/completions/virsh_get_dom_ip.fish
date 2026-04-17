function __get_running_virsh_domains
    virsh list --name --state-running | string match -rv '^$'
end
complete -c virsh_get_dom_ip -x -d domain -a '(__get_running_virsh_domains)'

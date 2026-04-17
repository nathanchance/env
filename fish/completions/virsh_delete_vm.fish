function __get_all_virsh_domains
    virsh list --all --name | string match -rv '^$'
end
complete -c virsh_delete_vm -x -a '(__get_all_virsh_domains)'

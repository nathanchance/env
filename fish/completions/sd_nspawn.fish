complete -c sd_nspawn -f
complete -c sd_nspawn -f -s h -l help -d "Show help message and exit"
complete -c sd_nspawn -f -s e -l ephemeral -d "Run container with snapshot of root directory, and remove it after exit"
complete -c sd_nspawn -f -s i -l install -d "Install .nspawn files"
complete -c sd_nspawn -x -s r -l run -d "Run command in container"
complete -c sd_nspawn -x -s R -l reset -d "Remove requested files" -a "machine setup all"
complete -c sd_nspawn -f -s -u -l update -d "Enter inactive container to update"
complete -c sd_nspawn -f -l is-running -d "Check if machine is running"
complete -c sd_nspawn -x -s n -l name -d Machine -a '(__fish_systemd_machine_images)'

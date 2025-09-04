complete -c upd -f -d "Update target" -a '(type upd | string match -gr "^\s+case ([a-zA-Z0-9][a-zA-Z0-9\- ]+)" | string match -rv "^(arm|aarch|x86)" | string split " " | path sort -u)'
complete -c upd -f -s f -l force -d "Install package locally even if already installed via distro"
complete -c upd -f -s y -l yes -d "Answer package manager prompts non-interactively"

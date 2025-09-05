complete -c cbl_clone_repo -x -d "Repo to clone" -a '(type cbl_clone_repo | string match -gr "^            case ([\w|\-|\s]+)" | string split " ")'

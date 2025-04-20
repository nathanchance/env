complete -c msh -f -d "Special host" -a '(type msh | string match -gr "^        case ([a-zA-Z0-9\- ]+)" | string split " ")'

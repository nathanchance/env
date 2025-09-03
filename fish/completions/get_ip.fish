complete -c get_ip -f -d "Special host" -a '(type get_ip | string match -gr "^        case ([a-zA-Z0-9\- ]+)" | string split " ")'

complete -c msh -f -d "Special host" -a '(type msh | string match -gr "^            case ([a-zA-Z0-9][a-zA-Z0-9\- ]+)" | string split " " | path sort)'
complete -c msh -f -s t -l tailscale -d "Connect to device using Tailscale"

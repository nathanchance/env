complete -c cbl_gcmt -x -d "Type of commit" -a '(type cbl_gcmt | string match -gr "^            case ([^\']+)\$" | string split " ")'

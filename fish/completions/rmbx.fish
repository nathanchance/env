complete -c rmbx -f -s u -l update -d "Update mailbox file before reading"
complete -c rmbx -x -d Mailbox -a "(path filter -d $MAIL_FOLDER/* | path basename)"

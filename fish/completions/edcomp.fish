function __edcomp_gen_args
    path filter -f $ENV_FOLDER/fish/completions/* | path basename | path change-extension "" | string match -er (commandline -ct) | while read -l item
        if test -e $ENV_FOLDER/fish/functions/$item.fish
            set desc (functions -Dv $item | tail -n1)
        else if test -e $PYTHON_BIN_FOLDER/$item
            set desc ($item -h | string match -er '^[A-Z]')
        else
            set desc 'external command'
        end
        echo $item\t$desc
    end
end

complete -c edcomp -x -a "(__edcomp_gen_args)"
complete -c edcomp -f -s r -l reload -d "Reload fish files after editing function"
complete -c edcomp -f -s f -l fzf -d "Select functions to edit using fzf"

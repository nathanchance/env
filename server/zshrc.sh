#!/usr/bin/env zsh

{
    echo
    echo "[[ -f \${HOME}/scripts/env/common ]] && source \"\${HOME}/scripts/env/common\""
    echo "type shell_setup &>/dev/null && shell_setup"
} >> ~/.zshrc

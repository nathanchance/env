#!/usr/bin/env bash

{
    echo
    echo "[[ -f \${HOME}/scripts/os/common ]] && source \"\${HOME}/scripts/os/common\""
    echo "type -p bash_setup && bash_setup"
} >> ~/.bashrc

#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function add_hetzner_mirror_to_repos -d "Add Hetzner's internal Arch Linux mirror to /etc/pacman.conf"
    set program "import arch
from pathlib import Path
import sys

# Not using pacman, bail out gracefully
if not (pacman_conf := Path('/etc/pacman.conf')).exists():
    sys.exit(0)

orig_pacman_conf_txt = pacman_conf.read_text(encoding='utf-8')
new_pacman_conf_txt = arch.add_hetzner_mirror_to_repos(orig_pacman_conf_txt)

if orig_pacman_conf_txt != new_pacman_conf_txt:
    pacman_conf.write_text(new_pacman_conf_txt, encoding='utf-8')"

    if test (count $argv) -eq 0
        sudo env PYTHONPATH=$PYTHON_SETUP_FOLDER python -c "$program"
        return
    end

    for arg in $argv
        switch $arg
            case -p --print-container-routine
                printf '\n%s\n%s\n%s%s%s\n%s\n' \
                    '# Import Hetzner mirror from the host configuration if using pacman' \
                    'if command -v python3 >/dev/null 2>&1; then' \
                    '    PYTHONPATH=/run/host'$PYTHON_SETUP_FOLDER' python3 -c "' \
                    "$program" \
                    '" || exit' \
                    fi

            case '*'
                print_error "Unknown argument: $arg"
                return 1
        end
    end
end

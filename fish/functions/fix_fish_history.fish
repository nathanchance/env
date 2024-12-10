#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function fix_fish_history -d "Remove NUL bytes to workaround https://github.com/fish-shell/fish-shell/issues/10300"
    python3 -c "from pathlib import Path
fish_history = Path.home() / '.local/share/fish/fish_history'
history_bytes = fish_history.read_bytes()
if (nul := b'\x00') in history_bytes:
    fish_history.write_bytes(history_bytes.replace(nul, b''))"
end

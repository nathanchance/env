#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function tg_msg -d "Send a Telegram message to FlashBox Notifier"
    if is_github_actions
        return 0
    end

    set botinfo $HOME/.botinfo
    if not test -f $botinfo
        print_error "$botinfo could not be found!"
        return 1
    end

    set chat_id (head -1 $botinfo)
    set token (tail -1 $botinfo)
    set host (uname -n)

    curl -s -X POST https://api.telegram.org/bot$token/sendMessage \
        -d chat_id=$chat_id \
        -d parse_mode=Markdown \
        -d text="From $host:

$argv" \
        -o /dev/null
end

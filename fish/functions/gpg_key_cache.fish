#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function gpg_key_cache -d "Prompt for GPG password so that it is cached by the agent"
    gpg_key_usable; or return 0
    status is-interactive; or return 0
    set num (gpg-connect-agent 'keyinfo --list' /bye 2>/dev/null | awk 'BEGIN{CACHED=0} /^S/ {if($7==1){CACHED=1}} END{if($0!=""){print CACHED} else {print "none"}}')
    if test "$num" = none || test "$num" = 0
        echo | gpg --pinentry-mode loopback --clearsign --output /dev/null
    end
end

#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function git_aliases -d "Configure git aliases"
    if gpg_key_usable
        set gpg_sign " --gpg-sign"
    end
    git config --global alias.aa 'add --all'
    git config --global alias.ac "commit$gpg_sign --all --signoff --verbose" # add and commit
    git config --global alias.ama 'am --abort'
    git config --global alias.amc 'am --continue'
    git config --global alias.ams "am$gpg_sign --signoff" # am signoff
    git config --global alias.ap 'apply -3 -v'
    git config --global alias.b 'branch --verbose'
    git config --global alias.bd 'branch --delete --force'
    git config --global alias.bn 'rev-parse --abbrev-ref HEAD' # branch name
    git config --global alias.bm 'branch --move'
    git config --global alias.bu 'branch --unset-upstream'
    git config --global alias.c "commit$gpg_sign --signoff --verbose"
    git config --global alias.ca "commit$gpg_sign --amend --signoff --verbose" # commit ammend
    git config --global alias.cad "!git commit$gpg_sign --amend --signoff --date=\"\$(date)\" --verbose" # commit amend date
    git config --global alias.cb 'rev-parse --abbrev-ref HEAD' # current branch
    git config --global alias.cf 'diff --name-only --diff-filter=U' # conflicts
    git config --global alias.ch checkout
    git config --global alias.cl 'clean -fxd'
    git config --global alias.cp "cherry-pick$gpg_sign --signoff"
    git config --global alias.cpa 'cherry-pick --abort'
    git config --global alias.cpc 'cherry-pick --continue'
    git config --global alias.cpe 'cherry-pick --edit --signoff'
    git config --global alias.cpq 'cherry-pick --quit'
    git config --global alias.cps 'cherry-pick --skip'
    git config --global alias.dc 'describe --contains'
    git config --global alias.dfs 'diff --stat'
    git config --global alias.dfss 'diff --shortstat'
    git config --global alias.dh 'diff HEAD'
    git config --global alias.dhc 'reset --hard HEAD^' # delete head commit
    git config --global alias.f fetch
    git config --global alias.fa 'fetch --all'
    git config --global alias.fixes 'show -s --format="Fixes: %h (\"%s\")"'
    git config --global alias.fm "commit$gpg_sign --file /tmp/mrg-msg" # finish merge
    git config --global alias.fp format-patch
    git config --global alias.fpk 'format-patch --add-header="X-Patchwork-Bot: notify"'
    git config --global alias.kf 'show -s --format="%h (\"%s\")"' # kernel format
    git config --global alias.korg 'show -s --format="Link: https://git.kernel.org/linus/%H"' # link to a kernel.org commit for cherry-picks
    git config --global alias.lo 'log --oneline'
    git config --global alias.ma 'merge --abort'
    git config --global alias.mc 'merge --continue'
    # shellcheck disable=SC2016
    git config --global alias.mfc '!git log --format=%H --committer="$(git config --get user.name) <$(git config --get user.email)>" "$(git log --format=%H -n 150 | tail -n1)".. | tail -n1'
    git config --global alias.pr pull-request
    git config --global alias.psu 'push --set-upstream'
    # shellcheck disable=SC2016
    git config --global alias.rb "rebase$gpg_sign"
    git config --global alias.rba 'rebase --abort'
    git config --global alias.rbc 'rebase --continue'
    git config --global alias.rbs 'rebase --skip'
    git config --global alias.rh 'reset --hard'
    git config --global alias.rma 'remote add'
    # https://lore.kernel.org/lkml/20190624144924.GE29120@arrakis.emea.arm.com/
    # shellcheck disable=SC2016
    git config --global alias.send-rmk-email '!git send-email --add-header=\"KernelVersion: $(git describe --abbrev=0)\" --no-thread --suppress-cc=all --to="patches@arm.linux.org.uk"'
    git config --global alias.sha 'show -s --format=%H'
    git config --global alias.stbl 'show -s --format="commit %H upstream."'
    git config --global alias.rmsu 'remote set-url'
    git config --global alias.rmv 'remote -v'
    git config --global alias.root 'rev-parse --show-toplevel'
    git config --global alias.rs 'reset --soft'
    git config --global alias.ru 'remote update'
    git config --global alias.rv "revert$gpg_sign --signoff"
    git config --global alias.s 'status --short --branch'
    git config --global alias.sf status
    git config --global alias.sh 'show --first-parent'
    git config --global alias.shf 'show --first-parent --format=fuller'
    git config --global alias.shm 'show --no-patch'
    git config --global alias.shmf 'show --format=fuller --no-patch'
    git config --global alias.sw switch
    git config --global alias.us 'reset HEAD'

    # fish git aliases
    # no arguments
    for alias in af dmb swf sync ra
        git config --global alias.$alias "!fish -c git_$alias"
    end
    # with arguments
    for alias in rfl
        git config --global alias.$alias '!fish -c "git_'$alias' $@"'
    end
    git config --global alias.rf '!fish -c "git_rf -q $@"'

    # Set up merge aliases based on availability of '--signoff'
    if test (git --version | head -n 1 | cut -d . -f 2) -ge 15
        set signoff " --signoff"
    end
    git config --global alias.m "merge$gpg_sign$signoff"
    git config --global alias.ml "merge$gpg_sign$signoff --log=500"
    git config --global alias.pl "pull$gpg_sign$signoff"
    git config --global alias.pll "pull$gpg_sign$signoff --log=500"
end

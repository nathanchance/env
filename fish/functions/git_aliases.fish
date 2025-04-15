#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function git_aliases -d "Configure git aliases"
    if gpg_key_usable
        set gpg_sign " --gpg-sign"
    end

    # git add
    git config --global alias.aa 'add --all'

    # git am
    git config --global alias.ama 'am --abort'
    git config --global alias.amc 'am --continue'
    git config --global alias.ams "am$gpg_sign --signoff" # am signoff

    # git apply
    git config --global alias.ap 'apply -3 -v'

    # git branch
    git config --global alias.b 'branch --verbose'
    git config --global alias.bd 'branch --delete --force'
    git config --global alias.bm 'branch --move'
    git config --global alias.bu 'branch --unset-upstream'
    git config --global alias.bv 'branch --verbose --verbose'

    # git checkout
    git config --global alias.ch checkout

    # git cherry-pick
    git config --global alias.cp "cherry-pick$gpg_sign --signoff"
    git config --global alias.cpa 'cherry-pick --abort'
    git config --global alias.cpc 'cherry-pick --continue'
    git config --global alias.cpe 'cp --edit'
    git config --global alias.cpq 'cherry-pick --quit'
    git config --global alias.cps 'cherry-pick --skip'

    # git clean
    git config --global alias.cl 'clean -fxd'
    git config --global alias.cln 'cl -n'
    git config --global alias.clq 'cl -q'

    # git commit
    git config --global alias.ac "c --all" # add and commit
    git config --global alias.c "commit$gpg_sign --signoff --verbose"
    git config --global alias.ca "c --amend" # commit amend
    git config --global alias.cad '!git ca --date="$(date)"' # commit amend date

    # git describe
    git config --global alias.dc 'describe --contains'

    # git diff
    git config --global alias.cf 'diff --name-only --diff-filter=U' # conflicts
    git config --global alias.dfs 'diff --stat'
    git config --global alias.dfss 'diff --shortstat'
    git config --global alias.dh 'diff HEAD'

    # git fetch
    git config --global alias.f fetch
    git config --global alias.fa 'f --all'

    # git format-patch
    git config --global alias.fp format-patch

    # git log
    git config --global alias.l 'log --oneline'
    git config --global alias.lp 'log --patch'
    # shellcheck disable=SC2016
    git config --global alias.mfc '!git log --format=%H --committer="$(git config --get user.name) <$(git config --get user.email)>" "$(git log --format=%H -n 150 | tail -n1)".. | tail -n1'

    # git merge
    git config --global alias.m "merge$gpg_sign --signoff"
    git config --global alias.ma 'merge --abort'
    git config --global alias.mc 'merge --continue'
    git config --global alias.ml "m --log=500"

    # git pull
    git config --global alias.pl "pull$gpg_sign --signoff"
    git config --global alias.pll "pl --log=500"

    # git push
    git config --global alias.psu 'push --set-upstream'

    # git rebase
    git config --global alias.rb "rebase$gpg_sign"
    git config --global alias.rba 'rebase --abort'
    git config --global alias.rbc 'rebase --continue'
    git config --global alias.rbi 'rebase --interactive'
    git config --global alias.rbs 'rebase --skip'

    # git remote
    git config --global alias.rma 'remote add'
    git config --global alias.rmsu 'remote set-url'
    git config --global alias.rmv 'remote -v'
    git config --global alias.ru 'remote update'

    # git reset
    git config --global alias.dhc 'rh HEAD^' # delete head commit
    git config --global alias.rh 'reset --hard'
    git config --global alias.rs 'reset --soft'

    # git revert
    git config --global alias.rv "revert$gpg_sign --signoff"

    # git rev-parse
    git config --global alias.bn 'rev-parse --abbrev-ref HEAD' # name of current branch
    git config --global alias.root 'rev-parse --show-toplevel'

    # git send-email
    # https://lore.kernel.org/lkml/20190624144924.GE29120@arrakis.emea.arm.com/
    git config --global alias.send-rmk-email '!git send-email --add-header="KernelVersion: $(git describe --abbrev=0)" --no-thread --suppress-cc=all --to=patches@arm.linux.org.uk'

    # git show
    git config --global alias.cite 'shm --format="%h (\"%s\")"' # kernel format
    git config --global alias.citegh 'shm --format="[%h](https://git.kernel.org/linus/%H) (\"%s\")"' # kernel format for GitHub
    git config --global alias.fixes 'shm --format="Fixes: %h (\"%s\")"'
    git config --global alias.korg 'shm --format="Link: https://git.kernel.org/linus/%H"' # link to a kernel.org commit for cherry-picks
    git config --global alias.sh 'show --first-parent'
    git config --global alias.shf 'sh --format=fuller'
    git config --global alias.shm 'sh --no-patch'
    git config --global alias.shmf 'shm --format=fuller'
    git config --global alias.sha 'shm --format=%H'
    git config --global alias.stbl 'shm --format="commit %H upstream."'

    # git status
    git config --global alias.s 'sf --short --branch'
    git config --global alias.sf status

    # git switch
    git config --global alias.swc 'switch -c'

    # git worktree
    git config --global alias.w worktree
    git config --global alias.wa 'worktree add'
    git config --global alias.wl 'worktree list'
    git config --global alias.wm 'worktree move'
    git config --global alias.wr 'worktree remove'

    # fish git aliases
    # no arguments
    for alias in bf cpi dmb
        git config --global alias.$alias "!fish -c git_$alias"
    end
    # with arguments
    for alias in rn sw sync
        git config --global alias.$alias '!f() { fish -c "'git_$alias' $*"; }; f'
    end
    git config --global alias.rf '!f() { fish -c "git_rf -q $*"; }; f'
    git config --global alias.urbi '!f() { fish -c "git_ua rbi $*"; }; f'
    git config --global alias.urh '!f() { fish -c "git_ua rh $*"; }; f'

    # forgit aliases
    git config --global alias.ai '!f() { fish -c "git-forgit add $*"; }; f'
    git config --global alias.bdi '!f() { fish -c "git-forgit branch_delete $*"; }; f'
    git config --global alias.di '!f() { fish -c "git-forgit diff $*"; }; f'
    git config --global alias.dhi '!f() { fish -c "git-forgit diff HEAD"; }; f'
    git config --global alias.fu '!f() { fish -c "git-forgit fixup $*"; }; f'
    git config --global alias.li '!f() { fish -c "git-forgit log $*"; }; f'
    git config --global alias.ri '!f() { fish -c "git-forgit checkout_file $*"; }; f'
    git config --global alias.rbii '!f() { fish -c "git-forgit rebase $*"; }; f'
    git config --global alias.rvi '!f() { fish -c "git-forgit revert_commit $*"; }; f'
    git config --global alias.st '!f() { fish -c "git-forgit stash_show $*"; }; f'
    git config --global alias.us '!f() { fish -c "git-forgit reset_head $*"; }; f'
end

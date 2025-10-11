#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function kgen_pr -d "Generate a pull request for Linus from tag in specified repository"
    set base $argv[1]
    if test -z "$base"
        __print_error "No base provided?"
        return 1
    end

    set tag $argv[2]
    if test -z "$tag"
        __print_error "No tag provided?"
        return 1
    end

    set subject $argv[3]
    if test -z "$subject"
        __print_error "No email subject provided?"
        return 1
    end

    if not git rev-parse --is-inside-work-tree &>/dev/null
        __print_error "Not inside a git repository?"
        return 1
    end

    if git remote | string match -qr ^linus
        echo fetching linus...
        git fetch linus
    end

    set -g pr_file (mktemp -d)/COMMIT_EDITMSG
    set origin_url (git remote get-url origin)

    if not kcheck_commits $base..$tag
        while read -P 'Check failures found, ignore? [y/n] ' input
            switch $input
                case n
                    return 1
                case y
                    break
                case '*'
                    echo "invalid option: $input"
            end
        end
    end

    set remote_tags (git ls-remote --refs $origin_url | string match -gr 'refs/tags/v?(.*)$')
    if not contains $tag $remote_tags
        __print_error "Tag ('$tag') does not exist on remote?"
        return 1
    end

    # Linus prefers git://, do it after 'git request-pull' to avoid insteadOf in .gitconfig
    git request-pull $base $origin_url $tag | string replace git@gitolite.kernel.org: git://git.kernel.org/ >$pr_file

    while read -P 'What would you like to do? [e/q/s] ' input
        switch $input
            case e
                vim $pr_file

            case q
                break

            case s
                set to "Linus Torvalds <torvalds@linux-foundation.org>"
                set cc linux-kernel@vger.kernel.org
                if string match -qr ^kbuild $tag
                    set -a cc "Nicolas Schier <nsc@kernel.org>"
                    set -a cc linux-kbuild@vger.kernel.org
                else
                    __print_error "Don't know how to handle sending tag ('$tag')?"
                    return 1
                end

                set mutt_cmd mutt -s "[GIT PULL] $subject"
                for item in $cc
                    set -a mutt_cmd -c $item
                end
                set -a mutt_cmd -- $to

                printf 'Will execute\n\n\t'
                print_cmd $mutt_cmd "<$pr_file"
                echo
                while read -P "Proceed? [y/n] " input
                    switch $input
                        case y
                            $mutt_cmd <$pr_file
                            return
                        case n
                            return 1
                        case '*'
                            echo "invalid option: $input"
                    end
                end

            case '*'
                echo "invalid option: $input"
        end
    end
end

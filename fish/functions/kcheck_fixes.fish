#!/usr/bin/env fish
# fish-ified version of check_fixes from Stephen Rothwell
# https://lore.kernel.org/20210928104341.31521fb0@canb.auug.org.au/

function kcheck_fixes -d "Check Fixes: in commit range"
    if test (count $argv) -lt 1
        print_error (status function)" <commit_range>"
        return 1
    end
    set ret 0

    git rev-list --no-merges -i --grep="^[[:space:]]*Fixes:" $argv | while read -l commit
        set -l commit_msg "In commit

  "(git log -1 --format='%h ("%s")' $commit)"

"

        git log -1 --format=%B $commit | string match -er "^[[:space:]]*Fixes:" | string trim | while read -l fixes_line
            set -l fixes_msg "Fixes tag

  $fixes_line

has these problem(s):
"

            if not string match -qr '^[Ff][Ii][Xx][Ee][Ss]:[[:space:]]*(?<fixes_val>.*)$' $fixes_line
                print_error "Failed to parse fixes lines ('$fixes_line')?"
                return 1
            end

            set -l msg
            if string match -qr '^(?<first>[Cc][Oo][Mm][Mm][Ii][Tt])?[[:space:]]*(?<sha>[[:xdigit:]]{5,})(?<spaces>[[:space:]]*)(?<subject>.*)$' $fixes_val
                if test -n "$first"
                    set msg "$msg
  - leading word '$first' unexpected"
                end
                if test -z "$subject"
                    set msg "$msg
  - missing subject"
                else if test -z "$spaces"
                    set msg "$msg
  - missing space between the SHA1 and the subject"
                end
            else
                printf '%s%s  - %s\n' $commit_msg $fixes_msg 'No SHA1 recognised'
                set ret 1
                continue
            end
            if not git rev-parse -q --verify $sha >/dev/null
                printf '%s%s  - %s\n' $commit_msg $fixes_msg 'Target SHA1 does not exist'
                set ret 1
                continue
            end

            if test (string length $sha) -lt 12
                set msg "$msg
  - SHA1 should be at least 12 digits long"
            end

            if string match -qr '^\((?<subject>.*)\)' $subject
            else if string match -qr '^\((?<subject>.*)' $subject
                set msg "$msg
  - Subject has leading but no trailing parentheses"
            end

            if string match -qr '^["“](?<subject>.*)["”]$' $subject
            else if string match -qr '^[\'‘](?<subject>.*)[\'’]$' $subject
            else if string match -qr '^[\"\'“‘](?<subject>.*)$' $subject
                set msg "$msg
  - Subject has leading but no trailing quotes"
            end

            set subject (string trim $subject)
            set target_subject (git log -1 --format='%s' $sha | string trim)
            if test "$subject" != "$target_subject"
                set msg "$msg
  - Subject does not match target commit subject"
            end

            set lsha (git -C $CBL_SRC_C/linux rev-parse -q --verify $sha)
            if test -z "$lsha"
                if test (git rev-list --count $sha..$commit) -eq 0
                    set msg "$msg
  - Target is not an ancestor of this commit"
                end
            end

            if test -n "$msg"
                printf '%s%s%s\n' $commit_msg $fixes_msg $msg
                set ret 1
            end
        end
    end
    return $ret
end

#!/usr/bin/env fish
# fish-ified version of check_fixes from Stephen Rothwell
# https://lore.kernel.org/20210928104341.31521fb0@canb.auug.org.au/
# with additional checks from Kees Cook

function kcheck_commits -d "Check commits in a pull request for several potential issues"
    if test (count $argv) -lt 1
        __print_error (status function)" <commit_range>"
        return 1
    end

    set commit_range $argv[1]

    if not string match -qr '\.\.' $commit_range
        __print_error "Commit range ('$commit_range') does not look like a git range?"
        return 1
    end

    set commits (git rev-list --no-merges $commit_range)
    if test -z "$commits"
        __print_error "No commits found from commit range ('$commit_range')?"
        return 1
    end

    header "Checking $commit_range..."
    git log --no-walk --format='%h ("%s")' $commits

    header "Checking fixes"
    if kcheck_fixes $commit_range
        echo "No problems found with Fixes"
    end

    for commit in $commits
        set author_email (git log -1 --format='<%ae>%n<%aE>%n %an %n %aN ' $commit | path sort -u | string trim -r)
        set committer_email (git log -1 --format='<%ce>%n<%cE>%n %cn %n %cN ' $commit | path sort -u | string trim -r)

        set commit_body (git log -1 --format=%b $commit)
        set signoffs (string match -gr '^\s*Signed-off-by:?\s*(.*)' -- $commit_body | string replace -r ^ ' ')

        if not string match -iqr (string escape --style regex "$author_email") -- $signoffs
            set -a authors_missing $commit
        end
        if not string match -iqr (string escape --style regex "$committer_email") -- $signoffs
            set -a committers_missing $commit
        end
        if string match -qr '^---$' -- $commit_body
            set -a sep_exists $commit
        end

        set files_added (git diff-tree -r --diff-filter=A --name-only --no-commit-id $commit '*.rej' '*.orig')
        if test (count $files_added) -gt 0
            header "Unexpected files"
            printf 'Commit\n\n'
            git log --no-walk --format='  %h ("%s")' $commit
            printf '\nadded unexpected files:\n\n'
            printf '  %s\n' $files_added
        end
    end

    if test (count $authors_missing) -gt 0
        header "Commits with missing author SOB"
        git log --no-walk --format='  %h ("%s")' $authors_missing
    end
    if test (count $committers_missing) -gt 0
        header "Commits with missing committer SOB"
        git log --no-walk --format='  %h ("%s")' $committers_missing
    end
    if test (count $sep_exists) -gt 0
        header "Commits with ---"
        git log --no-walk --format='  %h ("%s")' $sep_exists
    end
end

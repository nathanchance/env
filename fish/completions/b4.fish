function __b4_seen_prep_mutex_flag
    __fish_seen_argument \
        -s p -l format-patch \
        -l edit-cover \
        -l edit-deps \
        -l check-deps \
        -l check \
        -l show-revision \
        -l compare-to \
        -l manual-reroll \
        -l show-info \
        -l cleanup
end

function __b4_seen_send_mutex_flag
    __fish_seen_argument \
        -s d -l dry-run \
        -s o -l output-dir \
        -l preview-to \
        -l reflect
end

# this command never takes a file argument
complete -c b4 -f

# help is valid for main command and subcommands
complete -c b4 -f -s h -l help -d "Show help message and exit"

# subcommands
set -l subcommands mbox am shazam pr ty diff kr prep trailers send
complete -c b4 -n "not __fish_seen_subcommand_from $subcommands" -x -a "
    mbox\t'Download a thread as an mbox file'
    am\t'Create an mbox file that is ready to git-am'
    shazam\t'Like b4 am, but applies the series to your tree'
    pr\t'Fetch a pull request found in a message ID'
    ty\t'Generate thanks email when something gets merged/applied'
    diff\t'Show a range-diff to previous series revision'
    kr\t'Keyring operations'
    prep\t'Work on patch series to submit for mailing list review'
    trailers\t'Operate on trailers received for mailing list reviews'
    send\t'Submit your work for review on the mailing lists'"

# top level options
complete -c b4 -n "not __fish_seen_subcommand_from $subcommands" -f -l version -d "Show version number and exit"
complete -c b4 -n "not __fish_seen_subcommand_from $subcommands" -f -s d -l debug -d "Add more debugging info to the output"
complete -c b4 -n "not __fish_seen_subcommand_from $subcommands" -f -s q -l quiet -d "Output critical information only"
complete -c b4 -n "not __fish_seen_subcommand_from $subcommands" -f -s n -l no-interative -d "Do not ask any interactive questions"
complete -c b4 -n "not __fish_seen_subcommand_from $subcommands" -f -l offline-mode -d "Do not perform any network queries"
complete -c b4 -n "not __fish_seen_subcommand_from $subcommands" -f -l no-stdin -d "Disable TTY detection for stdin"
complete -c b4 -n "not __fish_seen_subcommand_from $subcommands" -x -s c -l config -d "Set config option NAME to VALUE"

# common 'am' and 'mbox' arguments
set -l mbox_subcmds mbox am
complete -c b4 -n "__fish_seen_subcommand_from $mbox_subcmds" -r -s o -l outdir -d "Output into this directory (or use - to output mailbox contents to stdout)"
complete -c b4 -n "__fish_seen_subcommand_from $mbox_subcmds" -f -s c -l check-newer-revisions -d "Check if newer patch revisions exist"
complete -c b4 -n "__fish_seen_subcommand_from $mbox_subcmds" -x -s n -l mbox-name -d "Filename to name the mbox destination"
complete -c b4 -n "__fish_seen_subcommand_from $mbox_subcmds" -f -s M -l save-as-maildir -d "Save as maildir (avoids mbox format ambiguities)"

# common "retrieval" options
set -l retrieval_subcmds $mbox_subcmds shazam kr trailers
complete -c b4 -n "__fish_seen_subcommand_from $retrieval_subcmds" -r -s m -l use-local-mbox -d "Instead of grabbing a thread from lore, process this mbox file (or - for stdin)" -a '(__fish_complete_suffix .mbx)'
complete -c b4 -n "__fish_seen_subcommand_from $retrieval_subcmds" -x -l stdin-pipe-sep -d "When accepting messages on stdin, split using this pipe separator string"
complete -c b4 -n "__fish_seen_subcommand_from $retrieval_subcmds" -f -s C -l no-cache -d "Do not use local cache"
complete -c b4 -n "__fish_seen_subcommand_from $retrieval_subcmds" -f -l single-message -d "Only retrieve the message matching the msgid and ignore the rest of the thread"

# common "am" options
set -l am_subcmds {,shaz}am
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -x -s v -l use-version -d "Get a specific version of the patch/series"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -f -s S -l sloppy-trailers -d "Apply trailers without email address match checking"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -f -s T -l no-add-trailer -d "Do not add any trailers from follow-up messages"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -f -s s -l add-my-sob -d "Add your own signed-off-by to every patch"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -x -s P -l cherry-pick -d "Cherry-pick a subset of patches"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -f -s k -l check -d "Run local checks for every patch (e.g. checkpatch)"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -f -l cc-trailers -d "Copy all Cc'd addresses into Cc: trailers"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -f -l no-parent -d "Break thread at the msgid specified and ignore any parent messages"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds" -f -l allow-unicode-control-chars -d "Allow unicode control characters (very rarely legitimate)"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds; and not __fish_seen_argument -s i -l add-message" -f -s l -l add-link -d "Add a Link: trailer with message-id lookup URL to every patch"
complete -c b4 -n "__fish_seen_subcommand_from $am_subcmds; and not __fish_seen_argument -s l -l add-link" -f -s i -l add-message-id -d "Add a Message-ID: trailer to every patch"

# several options take --gitdir
set -l gitdir_subcmds pr ty diff
complete -c b4 -n "__fish_seen_subcommand_from $gitdir_subcmds" -r -s g -l gitdir -d "Operate on this git tree instead of current dir" -a '(__fish_complete_directories)'

# b4 mbox
complete -c b4 -n "__fish_seen_subcommand_from mbox" -f -s f -l filter-dupes -d "When adding messages to existing maildir, filter out duplicates"
complete -c b4 -n "__fish_seen_subcommand_from mbox; and not __fish_seen_argument -l minimize" -x -s r -l refetch -d "Refetch all messages in specified mbox with their original headers"
complete -c b4 -n "__fish_seen_subcommand_from mbox; and not __fish_seen_argument -s r -l refetch" -f -l minimize -d "Attempt to generate a minimal thread to simplify review"

# b4 am
complete -c b4 -n "__fish_seen_subcommand_from am" -f -s Q -l quilt-ready -d "Save patches in a quilt-ready folder"
complete -c b4 -n "__fish_seen_subcommand_from am" -f -s g -l guess-base -d "Try to guess the base of the series (if not specified)"
complete -c b4 -n "__fish_seen_subcommand_from am; and __fish_seen_argument -s g -l guess-base" -x -s b -l guess-branch -d "When guessing base, restrict to this branch (use with -g)"
complete -c b4 -n "__fish_seen_subcommand_from am; and __fish_seen_argument -s g -l guess-base" -x -l guess-lookback -d "When guessing base, go back this many days from the patch date"
complete -c b4 -n "__fish_seen_subcommand_from am" -f -s 3 -l prep-3way -d "Prepare for a 3-way merge (tries to ensure that all index blobs exist by making a fake commit range)"
complete -c b4 -n "__fish_seen_subcommand_from am" -f -l no-cover -d "Do not save the cover letter (on by default when using -o -)"
complete -c b4 -n "__fish_seen_subcommand_from am" -f -l no-partial-reroll -d "Do not reroll partial series when detected"

# b4 shazam
complete -c b4 -n "__fish_seen_subcommand_from shazam; and not __fish_seen_argument -s M -l merge" -f -s H -l make-fetch-head -d "Attempt to treat series as a pull request and fetch it into FETCH_HEAD"
complete -c b4 -n "__fish_seen_subcommand_from shazam; and not __fish_seen_argument -s H -l make-fetch-head" -f -s M -l merge -d "Attempt to merge series as if it were a pull request (execs git-merge)"
complete -c b4 -n "__fish_seen_subcommand_from shazam; and __fish_seen_argument -s H -s M -l merge -l make-fetch-head" -x -l guess-lookback -d "When guessing base, go back this many days from the patch date"
complete -c b4 -n "__fish_seen_subcommand_from shazam; and __fish_seen_argument -s H -s M -l merge -l make-fetch-head" -x -l merge-base -d "Force this base when merging"

# b4 pr
complete -c b4 -n "__fish_seen_subcommand_from pr" -x -s b -l branch -d "Check out FETCH_HEAD into this branch after fetching"
complete -c b4 -n "__fish_seen_subcommand_from pr" -f -s c -l check -d "Check if pull request has already been applied"
complete -c b4 -n "__fish_seen_subcommand_from pr" -f -s e -l explode -d "Convert a pull request into an mbox full of patches"
complete -c b4 -n "__fish_seen_subcommand_from pr" -r -s o -l output-mbox -d "Save exploded messages into this mailbox" -a '(__fish_complete_suffix .mbx)'
complete -c b4 -n "__fish_seen_subcommand_from pr; and __fish_seen_argument -s e -l explode" -x -s f -l from-addr -d "Use this From: in exploded messages"
complete -c b4 -n "__fish_seen_subcommand_from pr; and __fish_seen_argument -s e -l explode" -x -s s -l send-as-identity -d "Use git-send-email to send exploded series"
complete -c b4 -n "__fish_seen_subcommand_from pr; and __fish_seen_argument -s s -l send-as-indentity" -l dry-run -d "Force a --dry-run on git-send-email invocation"

# b4 ty
complete -c b4 -n "__fish_seen_subcommand_from ty" -r -s o -l outdir -d "Write thanks files into this dir" -a '(__fish_complete_directories)'
complete -c b4 -n "__fish_seen_subcommand_from ty" -f -s l -l list -d "List pull requests and patch series you have retrieved"
complete -c b4 -n "__fish_seen_subcommand_from ty" -x -s t -l thank-for -d "Generate thankyous for specific entries from -l"
complete -c b4 -n "__fish_seen_subcommand_from ty" -x -s d -l discard -d "Discard specific messages from -l"
complete -c b4 -n "__fish_seen_subcommand_from ty" -f -s a -l auto -d "Use the Auto-Thankanator to figure out what got applied/merged"
complete -c b4 -n "__fish_seen_subcommand_from ty" -x -s b -l branch -d "The branch to check against, instead of current"
complete -c b4 -n "__fish_seen_subcommand_from ty" -f -l since -d "The --since option to use when auto-matching patches"
complete -c b4 -n "__fish_seen_subcommand_from ty" -f -s S -l sendemail -d "Send email instead of writing out .thanks files"
complete -c b4 -n "__fish_seen_subcommand_from ty" -l dry-run -d "Print out emails instead of sending them"
complete -c b4 -n "__fish_seen_subcommand_from ty; and __fish_seen_argument -s a -l auto -s d -l discard -s t -l thank-for" -x -l pw-set-state -d "Set this patchwork state instead of default"

# b4 diff
complete -c b4 -n "__fish_seen_subcommand_from diff" -f -s C -l no-cache -d "Do not use local cache"
complete -c b4 -n "__fish_seen_subcommand_from diff" -x -s v -l compare-versions -d "Compare specific versions instead of latest and one before that"
complete -c b4 -n "__fish_seen_subcommand_from diff" -f -s n -l no-diff -d "Do not generate a diff, just show the command to do it"
complete -c b4 -n "__fish_seen_subcommand_from diff" -r -s o -l output-diff -d "Save diff into this file instead of outputting to stdout"
complete -c b4 -n "__fish_seen_subcommand_from diff" -f -s c -l color -d "Force color output even when writing to file"
complete -c b4 -n "__fish_seen_subcommand_from diff" -f -s m -l compare-am-mboxes -d "Compare two mbx files prepared with 'b4 am'"
complete -c b4 -n "__fish_seen_subcommand_from diff" -x -l range-diff-opts -d "Arguments passed to git range-diff"

# b4 kr
complete -c b4 -n "__fish_seen_subcommand_from kr" -f -l show-keys -d "Show all developer keys found in a thread"

# b4 prep
complete -c b4 -n "__fish_seen_subcommand_from prep" -f -s c -l auto-to-cc -d "Automatically populate cover letter trailers with To and Cc addresses"
complete -c b4 -n "__fish_seen_subcommand_from prep" -x -l force-revision -d "Force revision to be this number instead"
complete -c b4 -n "__fish_seen_subcommand_from prep" -x -l set-prefixes -d "Prefixes to include after [PATCH]"
complete -c b4 -n "__fish_seen_subcommand_from prep" -x -l add-prefixes -d "Additional prefixes to add to those already defined"
complete -c b4 -n "__fish_seen_subcommand_from prep" -f -s C -l no-cache -d "Do not use local cache"

complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -r -s p -l format-patch -d "Output prep-tracked commits as patches" -a '(__fish_complete_directories)'
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -f -l edit-cover -d "Edit the cover letter in your defined $EDITOR (or core.editor)"
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -f -l edit-deps -d "Edit the series dependencies in your defined $EDITOR (or core.editor)"
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -f -l check-deps -d "Run checks for any defined series dependencies"
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -f -l check -d "Run checks on the series"
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -f -l show-revision -d "Show current series revision number"
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -x -l compare-to -d "Display a range-diff to previously sent revision N"
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -x -l manual-reroll -d "Mark current revision as sent and reroll"
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -f -l show-info -d "Show series info in a format that can be passed to other commands" -a '(b4 prep --show-info 2>/dev/null | string split -f 1 :)'
complete -c b4 -n "__fish_seen_subcommand_from prep; and not __b4_seen_prep_mutex_flag" -f -l cleanup -d "Archive and remove a prep-tracked branch and all its sent/ tags"

complete -c b4 -n "__fish_seen_subcommand_from prep" -x -s n -l new -d "Create a new branch for working on a patch series"
complete -c b4 -n "__fish_seen_subcommand_from prep" -x -s f -l fork-point -d "When creating a new branch, use this fork point instead of HEAD"
complete -c b4 -n "__fish_seen_subcommand_from prep" -x -s F -l from-thread -d "When creating a new branch, use this thread"
complete -c b4 -n "__fish_seen_subcommand_from prep" -x -s e -l enroll -d "Enroll current branch, using its configured upstream branch as fork base, or the passed tag, branch, or commit"

# b4 trailers
complete -c b4 -n "__fish_seen_subcommand_from trailers" -f -s u -l update -d "Update branch commits with latest received trailers"
complete -c b4 -n "__fish_seen_subcommand_from trailers" -f -s S -l sloppy-trailers -d "Apply trailers without email address match checking"
complete -c b4 -n "__fish_seen_subcommand_from trailers" -x -s F -l trailers-from -d "Look for trailers in the thread with this msgid instead of using the series change-id"
complete -c b4 -n "__fish_seen_subcommand_from trailers" -x -l since -d "The --since option to use with git-log when auto-matching patches"
complete -c b4 -n "__fish_seen_subcommand_from trailers" -x -l since-commit -d "Look for any new trailers for commits starting with this one"

# b4 send
complete -c b4 -n "__fish_seen_subcommand_from send; and not __b4_seen_send_mutex_flag" -f -s d -l dry-run -d "Do not send, just dump out raw smtp messages to the stdout"
complete -c b4 -n "__fish_seen_subcommand_from send; and not __b4_seen_send_mutex_flag" -r -s o -l output-dir -d "Do not send, write raw messages to this directory (forces --dry-run)" -a '(__fish_complete_directories)'
complete -c b4 -n "__fish_seen_subcommand_from send; and not __b4_seen_send_mutex_flag" -x -l preview-to -d "Send everything for a pre-review to specified addresses instead of actual recipients"
complete -c b4 -n "__fish_seen_subcommand_from send; and not __b4_seen_send_mutex_flag" -f -l reflect -d "Send everything to yourself instead of the actual recipients"
complete -c b4 -n "__fish_seen_subcommand_from send" -f -l no-trailer-to-cc -d "Do not add any addresses found in the cover or patch trailers to To: or Cc:"
complete -c b4 -n "__fish_seen_subcommand_from send" -x -l to -d "Addresses to add to the To: list"
complete -c b4 -n "__fish_seen_subcommand_from send" -x -l cc -d "Addresses to add to the Cc: list"
complete -c b4 -n "__fish_seen_subcommand_from send" -f -l not-me-too -d "Remove yourself from the To: or Cc: list"
complete -c b4 -n "__fish_seen_subcommand_from send" -f -l resend -d "Resend a previously sent version of the series"
complete -c b4 -n "__fish_seen_subcommand_from send" -f -l no-sign -d "Do not add the cryptographic attestation signature header"
complete -c b4 -n "__fish_seen_subcommand_from send" -f -l use-web-endpoint -d "Force going through the web endpoint"
complete -c b4 -n "__fish_seen_subcommand_from send" -f -l web-auth-new -d "Initiate a new web authentication request"
complete -c b4 -n "__fish_seen_subcommand_from send" -x -l web-auth-verify -d "Submit the token received via verification email"

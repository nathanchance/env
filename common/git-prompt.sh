#!/usr/bin/env bash

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" || return
curl -LSso "${HOME}"/.git-prompt.sh https://github.com/git/git/raw/master/contrib/completion/git-prompt.sh
patch --no-backup-if-mismatch -d "${HOME}" -p1 -s < git-prompt.patch || die ".git-prompt.sh patch might need to be refreshed!"
sed -i 's/__git_ps1/__git_ps1_custom/g' "${HOME}"/.git-prompt.sh

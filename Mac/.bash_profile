#
# .bash_profile for my MacBook Pro
#
# Copyright (C) 2017 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

# git bash completion
source ~/.git-prompt.sh

# Cool prompt
PS1='\[\033[01;31m\]\u@\h \[\033[01;33m\]\w\[\033[01;36m\]$(__git_ps1 " (%s)") \[\033[39m\]\$ '

# For Homebrew
export PATH=/usr/local/sbin:${PATH}

# Add Scripts directory to PATH
export PATH=${PATH}:${HOME}/Documents/Repos/Scripts

# Export ANDROID_HOME for gradlew
export ANDROID_HOME=${HOME}/Library/Android/SDK

# Export build tools to path
# 26.0.0-rc2 first
export PATH=${PATH}:${HOME}/Library/Android/SDK/build-tools/26.0.0-rc2
# Then 25.0.3
export PATH=${PATH}:${HOME}/Library/Android/SDK/build-tools/25.0.3

# Export NDK to PATH
export PATH=${PATH}:${HOME}/Library/Android/SDK/ndk-bundle

# Setting PATH for Python 3.6
export PATH=/Library/Frameworks/Python.framework/Versions/3.6/bin:${PATH}

# aliases
alias sshfb='ssh nathan@nchancellor.net'
alias tmux='tmux -u'
alias vim='nvim'

# Try to attach via tmux
if [[ -z ${TMUX} ]] ;then
    ID=$( tmux ls | grep -vm1 attached | cut -d: -f1 ) # get the id of a deattached session
    if [[ -z ${ID} ]] ;then # if not available create a new one
        tmux -u new-session
    else
        tmux -u attach-session -t ${ID} # if available attach to it
    fi
fi

###############
# GIT ALIASES #
###############

# Alias hub to git
alias git='hub'

alias gf='git fetch'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpe='git cherry-pick --edit'
alias gcpc='git cherry-pick --continue'
alias gcpq='git cherry-pick --quit'

alias gph='git push'
alias gpo='git push origin'
alias gpf='git push --force'
alias gpsu='git push --set-upstream origin'

alias gpl='git pull'

alias ga='git add'
alias gaa='git add -A'

alias gam='git am'

alias gc='git commit'
alias gcs='git commit --signoff'
alias gca='git commit --amend'
alias gac='git commit --all'
alias gacs='git commit --all --signoff'
alias gaca='git commit --all --amend'

alias grhe='git reset HEAD'
alias grh='git reset --hard'
alias grs='git reset --soft'

alias glg='git log'
alias gl='git log --format=oneline'
alias gb='git branch -v'
alias gbd='git branch -D'

alias gs='git status'

alias grm='git remote'

alias gch='git checkout'
alias gcb='git checkout -b'

alias grb='git rebase'
alias grbi='git rebase -i'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'

alias gd='git diff'
alias gdh='git diff HEAD'
alias gdhh='git diff HEAD^..HEAD'
alias gdss='git diff --shortstat'
alias gdc='git diff --cached'

##################
# FOLDER ALIASES #
##################

export repodir="cd ${HOME}/Documents/Repos"
export subsdir="cd ${HOME}/Documents/Repos/Substratum"
export scriptsdir="cd ${HOME}/Documents/Repos/Scripts"
export miscdir="cd ${HOME}/Documents/Misc"

########
# MOTD #
########

function getOS() {
    prodVers=$( prodVers=$(sw_vers|grep ProductVersion);echo ${prodVers:15} )
    buildVers=$( buildVers=$(sw_vers|grep BuildVersion);echo ${buildVers:14} )
    echo "macOS ${prodVers} ${buildVers}"
}

function getUptime() {
	unset uptime
    boot=$(sysctl -n kern.boottime | cut -d "=" -f 2 | cut -d "," -f 1)
	now=$(date +%s)
	uptime=$(($now-$boot))

	if [[ -n ${uptime} ]]; then
		secs=$((${uptime}%60))
		mins=$((${uptime}/60%60))
		hours=$((${uptime}/3600%24))
		days=$((${uptime}/86400))
		uptime="${mins}m"
		if [ "${hours}" -ne "0" ]; then
			uptime="${hours}h ${uptime}"
		fi
		if [ "${days}" -ne "0" ]; then
			uptime="${days}d ${uptime}"
		fi
	fi
   echo ${uptime}
}

function getCPU() {
    cpu=$(machine)
    if [[ $cpu == "ppc750" ]]; then
        cpu="IBM PowerPC G3"
    elif [[ $cpu == "ppc7400" || $cpu == "ppc7450" ]]; then
        cpu="IBM PowerPC G4"
    elif [[ $cpu == "ppc970" ]]; then
        cpu="IBM PowerPC G5"
    else
        cpu=$(sysctl -n machdep.cpu.brand_string)
    fi

    REGEXP="-E"

    if [[ "${cpun}" -gt "1" ]]; then
        cpun="${cpun}x "
    else
        cpun=""
    fi
    if [ -z "$cpufreq" ]; then
        cpu="${cpun}${cpu}"
    else
        cpu="$cpu @ ${cpun}${cpufreq}"
    fi
    thermal="/sys/class/hwmon/hwmon0/temp1_input"
    if [ -e $thermal ]; then
        temp=$(bc <<< "scale=1; $(cat $thermal)/1000")
    fi
    if [ -n "$temp" ]; then
        cpu="$cpu [${temp}°C]"
    fi
    cpu=$(sed $REGEXP 's/\([tT][mM]\)|\([Rr]\)|[pP]rocessor|CPU//g' <<< "${cpu}" | xargs)

    echo ${cpu}
}

function getDiskUsage() {
	diskusage="Unknown"
	if type -p df >/dev/null 2>&1; then
        totaldisk=$(df -H / 2>/dev/null | tail -1)
        disktotal=$(awk '{print $2}' <<< "${totaldisk}")
        diskused=$(awk '{print $3}' <<< "${totaldisk}")
        diskusedper=$(awk '{print $5}' <<< "${totaldisk}")
	fi
   echo "${diskused} out of ${disktotal} (${diskusedper})"
}

function getMemUsage() {
    totalmem=$(echo "$(sysctl -n hw.memsize)" / 1024^2 | bc)
    wiredmem=$(vm_stat | grep wired | awk '{ print $4 }' | sed 's/\.//')
    activemem=$(vm_stat | grep ' active' | awk '{ print $3 }' | sed 's/\.//')
    compressedmem=$(vm_stat | grep occupied | awk '{ print $5 }' | sed 's/\.//')
    if [[ ! -z "$compressedmem | tr -d" ]]; then
        compressedmem=0
    fi
    usedmem=$(((${wiredmem} + ${activemem} + ${compressedmem}) * 4 / 1024))
    percent=$( echo $( echo "scale = 2; (${usedmem} / ${totalmem})" | bc -l | awk -F '.' '{print $2}' ) | sed s/^0*//g )
    if [[ -z ${percent} ]]; then
        percent=0
    fi
    echo "${usedmem} MiB out of ${totalmem} MiB (${percent}%)"
}

echo ""
echo ""
echo "   \$\$\$\$\$\$\$\$\ \$\$\        \$\$\$\$\$\$\   \$\$\$\$\$\$\  \$\$\   \$\$\       \$\$\$\$\$\$\$\$\  \$\$\$\$\$\$\  \$\$\$\$\$\$\$\  "
echo "   \$\$  _____|\$\$ |      \$\$  __\$\$\ \$\$  __\$\$\ \$\$ |  \$\$ |      \__\$\$  __|\$\$  __\$\$\ \$\$  __\$\$\ "
echo "   \$\$ |      \$\$ |      \$\$ /  \$\$ |\$\$ /  \__|\$\$ |  \$\$ |         \$\$ |   \$\$ /  \$\$ |\$\$ |  \$\$ |"
echo "   \$\$\$\$\$\    \$\$ |      \$\$\$\$\$\$\$\$ |\\$\$\$\$\$\$\  \$\$\$\$\$\$\$\$ |         \$\$ |   \$\$ |  \$\$ |\$\$\$\$\$\$\$  |"
echo "   \$\$  __|   \$\$ |      \$\$  __\$\$ | \____\$\$\ \$\$  __\$\$ |         \$\$ |   \$\$ |  \$\$ |\$\$  ____/ "
echo "   \$\$ |      \$\$ |      \$\$ |  \$\$ |\$\$\   \$\$ |\$\$ |  \$\$ |         \$\$ |   \$\$ |  \$\$ |\$\$ |      "
echo "   \$\$ |      \$\$\$\$\$\$\$\$\ \$\$ |  \$\$ |\\$\$\$\$\$\$  |\$\$ |  \$\$ |         \$\$ |    \$\$\$\$\$\$  |\$\$ |      "
echo "   \__|      \________|\__|  \__| \______/ \__|  \__|         \__|    \______/ \__|      "
echo ""
echo ""
echo "     Today's date      :  $( date "+%B %d, %Y (%A)" )"
echo "     Current time      :  $( date "+%I:%M %p %Z" )"
echo "     Operating system  :  $( getOS )"
echo "     Kernel version    :  $( uname -srm )"
echo "     Processor         :  $( getCPU )"
echo "     Memory usage      :  $( getMemUsage )"
echo "     Disk usage        :  $( getDiskUsage )"
echo "     Uptime            :  $( getUptime )"
echo ""
echo ""

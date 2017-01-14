#!/bin/bash
#
# MOTD for my build server
#
# Copyright (C) 2017 Nathan Chancellor
#
# CPU and memory usage functions taken from Screenfetch
# Copyright (c) 2010-2016 Brett Bohnenkamper <kittykatt@kittykatt.us>
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


function memUsage() {
	MEM_INFO=$( < /proc/meminfo )
	MEM_INFO=$( echo $( echo $( MEM_INFO=${MEM_INFO// /}; echo ${MEM_INFO//kB/}) ) )
	for M in $MEM_INFO; do
		case ${M//:*} in
			"MemTotal") MEM_USED=$((MEM_USED+=${M//*:})); MEM_TOTAL=${M//*:} ;;
			"ShMem") MEM_USED=$((MEM_USED+=${M//*:})) ;;
			"MemFree"|"Buffers"|"Cached"|"SReclaimable") MEM_USED=$((MEM_USED-=${M//*:})) ;;
		esac
	done
	MEM_USED=$((MEM_USED / 1024))
	MEM_TOTAL=$((MEM_TOTAL / 1024))

	echo "${MEM_USED} MB out of ${MEM_TOTAL} MB"
}

function cpu() {
	CPU=$( awk 'BEGIN{FS=":"} /model name/ { print $2; exit }' /proc/cpuinfo | awk 'BEGIN{FS="@"; OFS="\n"} { print $1; exit }' )
	CPUN=$( grep -c '^processor' /proc/cpuinfo )

	LOC="/sys/devices/system/cpu/cpu0/cpufreq"
	BL="${LOC}/bios_limit"
	SMF="${LOC}/scaling_max_freq"
	if [ -f "${BL}" ] && [ -r "${BL}" ]; then
		CPU_MHZ=$( awk '{print $1/1000}' "${BL}" )
	elif [ -f "${SMF}" ] && [ -r "${SMF}" ]; then
		CPU_MHZ=$( awk '{print $1/1000}' "${SMF}" )
	else
		CPU_MHZ=$( awk -F':' '/cpu MHz/{ print int($2+.5) }' /proc/cpuinfo | head -n 1 )
	fi
	if [ -n "${CPU_MHZ}" ]; then
		if [ $( echo ${CPU_MHZ} | cut -d . -f 1 ) -gt 999 ]; then
			CPU_GHZ=$( awk '{print $1/1000}' <<< "${CPU_MHZ}" )
			CPUFREQ="${CPU_GHZ}GHz"
		else
			CPUFREQ="${CPU_MHZ}MHz"
		fi
	fi

	if [[ "${CPUN}" -gt "1" ]]; then
		CPUN="${CPUN}x "
	else
		CPUN=""
	fi
	if [ -z "${CPUFREQ}" ]; then
		CPU="${CPUN}${CPU}"
	else
		CPU="${CPU} ${CPUN} @ ${CPUFREQ}"
	fi

	echo $( sed -r 's/\([tT][mM]\)|\([Rr]\)|[pP]rocessor|CPU//g' <<< "${CPU}" | xargs )
}

clear

echo ""
echo ""
echo ""
echo "   \$\$\$\$\$\$\$\$\ \$\$\        \$\$\$\$\$\$\   \$\$\$\$\$\$\  \$\$\   \$\$\       \$\$\$\$\$\$\$\   \$\$\$\$\$\$\  \$\$\   \$\$\ "
echo "   \$\$  _____|\$\$ |      \$\$  __\$\$\ \$\$  __\$\$\ \$\$ |  \$\$ |      \$\$  __\$\$\ \$\$  __\$\$\ \$\$ |  \$\$ |"
echo "   \$\$ |      \$\$ |      \$\$ /  \$\$ |\$\$ /  \__|\$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$ /  \$\$ |\\$\$\ \$\$  |"
echo "   \$\$\$\$\$\    \$\$ |      \$\$\$\$\$\$\$\$ |\\$\$\$\$\$\$\  \$\$\$\$\$\$\$\$ |      \$\$\$\$\$\$\$\ |\$\$ |  \$\$ | \\$\$\$\$  / "
echo "   \$\$  __|   \$\$ |      \$\$  __\$\$ | \____\$\$\ \$\$  __\$\$ |      \$\$  __\$\$\ \$\$ |  \$\$ | \$\$  \$\$<  "
echo "   \$\$ |      \$\$ |      \$\$ |  \$\$ |\$\$\   \$\$ |\$\$ |  \$\$ |      \$\$ |  \$\$ |\$\$ |  \$\$ |\$\$  /\\$\$\ "
echo "   \$\$ |      \$\$\$\$\$\$\$\$\ \$\$ |  \$\$ |\\$\$\$\$\$\$  |\$\$ |  \$\$ |      \$\$\$\$\$\$\$  | \$\$\$\$\$\$  |\$\$ /  \$\$ |"
echo "   \__|      \________|\__|  \__| \______/ \__|  \__|      \_______/  \______/ \__|  \__|"
echo ""
echo ""
echo "     Today's date      :  $( date "+%B %d, %Y (%A)" )"
echo "     Current time      :  $( date "+%I:%M %p %Z" )"
echo "     Operating system  :  $( source /etc/os-release; echo ${PRETTY_NAME} )"
echo "     Kernel version    :  $( uname -rv )"
echo "     Architecture      :  $( uname -m )"
echo "     Processor         :  $( cpu )"
echo "     Memory usage      :  $( memUsage )"
echo "     Disk usage        :  $( df -h | grep home | awk '{print $5}' ) ($( df -h | grep home | awk '{print $3}' ) out of $( df -h | grep home | awk '{print $2}' ))"
echo "     Package updates   :  $( pacman -Qu | grep -v ignored | wc -l )"
echo ""
echo ""

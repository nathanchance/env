#!/bin/bash
#
# Disk usage script
#
# Copyright (C) 2016 Nathan Chancellor
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



# du (disk usage)
# -c: report a grand total at the end
# -h: list as human readable
# -s: reports a sum for the usage of each directory

du -c -h -s .[!.]* *

# Alert the user their query is done
echo -e "\a"

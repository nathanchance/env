# du (disk usage)
# -c: report a grand total at the end
# -h: list as human readable
# -s: reports a sum for the usage of each directory
du -c -h -s .[!.]* *
echo -e "\a"

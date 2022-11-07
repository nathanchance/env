#!/usr/bin/env fish

in_container_msg -h; or return
dbx list &| grep -q (get_dev_img); or dbxc --yes; or return
dbxe -- true

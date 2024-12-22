#!/usr/bin/env fish

in_container_msg -h; or return
dbx list &| grep -q (dev_img); or dbxc --yes; or return
dbxe -- true

# Build scripts

These help with building various Android ROMs, kernels, and GApps. I use these on my build server/personal machine so they are tailored specifically to me but you are free to take these and modify them for your own needs.

To add all these folder to your PATH (allowing you to run them in any folder), add this to your .bashrc:

export PATH="${PATH}$(find <directory_to_script> -name '.*' -prune -o -type d -printf ':%p')"

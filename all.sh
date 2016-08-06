#!/bin/bash


#########
# GAPPS #
#########
. gapps.sh banks
. gapps.sh pn


########
# ROMS #
########
# PureNexus (Angler, Shamu, Bullhead, Hammerhead, Flo, Deb, and Flounder)
. rom.sh release pn
# PureNexus Mod (Angler, Shamu, Bullhead, and Hammerhead)
. rom.sh normal pn-mod
# Dirty Unicorns (Angler, Shamu, Bullhead, Hammerhead, and Mako)
. rom.sh normal du
. rom.sh du mako
# ResurrectionRemix (Shamu)
. rom.sh rr
# AOSiP (Angler, Shamu, Bullhead, Hammerhead, and Mako)
. rom.sh normal aosip
. rom.sh aosip mako
# Beltz (Angler, Shamu, Bullhead, and Hammerhead)
. rom.sh normal beltz

# Upload all of the log files
. upload.sh

# Exit the session
exit

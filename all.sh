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
. rom.sh normal pn mod
# Dirty Unicorns (Angler, Shamu, Bullhead, Hammerhead, and Mako)
. rom.sh normal du
. rom.sh du mako
# ResurrectionRemix (Shamu)
. rom.sh rr
# AOSiP (Angler, Shamu, and Bullhead)
. rom.sh aosip angler
. rom.sh aosip shamu
. rom.sh aosip bullhead
. rom.sh aosip mako

# Exit the session
exit

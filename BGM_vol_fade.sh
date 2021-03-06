#!/bin/bash

# A script to fade ALSA volume when starting or ending
# a Emulator by using amixer and MASTER/PCM Control.
#
# kill -19 pauses musicplayer, kill -18 continues musicplayer
#
# Place the script in runcommand-onstart.sh to fade-out
# Place the script in runcommand-onend.sh to fade-in
# For the onend script I recommend a line like this:
# (sleep 2 && $HOME/RetroPie/scripts/vol_fade.sh) &
#
# Status of musicplayer is determinated automatically
#
# by cyperghost
# 2018/10/31 - Halloween - Initial version
# 2018/11/01 - All saints' Day - Improved fadein, avoid 2nd script run
# 2018/11/03 - Detection of Playerstatus improved, code cleanup
# 2018/11/29 - Added commandline parameter force for -STOP and -CONT

# Reason: I like the pyscript for BGM but it has it flaws and caveeats
# so I recommend the mpg123 method brought by synack
# Read here how to setup https://retropie.org.uk/forum/topic/9133

# Setup Musicplayer and Channel you want to change volume here
readonly VOLUMECHANNEL="PCM"
readonly MUSICPLAYER="mpg123"

# Avoid multiple starts, so force wait till only one script is running
# This avoids overriding of volumes and reverse of fade-in and fade-out
while [[ "$(pgrep -c -f $(basename $0))" -gt 1 ]]; do
    sleep 1
done

# Get ALSA volume value and calculate step
VOLUMEALSA=$(amixer -M get $VOLUMECHANNEL | grep -o "...%]")
VOLUMEALSA=${VOLUMEALSA//[^[:alnum:].]/}
FADEVOLUME=
VOLUMESTEP=

# ALSA-Commands
VOLUMEZERO="amixer -q -M set $VOLUMECHANNEL 0%"
VOLUMERESET="amixer -q -M set $VOLUMECHANNEL $VOLUMEALSA%"

# Player-Status
PLAYERPID="$(pidof $MUSICPLAYER)"
PLAYERSTATUS=$(ps -ostate= -p $PLAYERPID 2> /dev/null)
[[ -n $PLAYERPID && -n $1 ]] && PLAYERSTATUS=$1

function set_step() {
    case $FADEVOLUME in
        [1-4][0-9]|50) VOLUMESTEP=5 ;;
        [5-7][0-9]|80) VOLUMESTEP=3 ;;
        [8-9][0-9]|100) VOLUMESTEP=1 ;;
        *) VOLUMESTEP=5 ;;
     esac
}

if [[ ${PLAYERSTATUS,,} == *s* || ${PLAYERSTATUS,,} == *r* ]]; then
    # Fading out and stop music
    FADEVOLUME=$VOLUMEALSA
    until [[ $FADEVOLUME -le 10 ]]; do
        set_step
        FADEVOLUME=$(($FADEVOLUME-$VOLUMESTEP))
        amixer -q -M set "$VOLUMECHANNEL" "${VOLUMESTEP}%-"
        sleep 0.1
    done

    $VOLUMEZERO
    kill -19 $PLAYERPID
    sleep 0.5
    $VOLUMERESET

elif [[ ${PLAYERSTATUS,,} == *t* ]]; then
    # Start music and fading in
    $VOLUMEZERO
    sleep 0.5
    kill -18 $PLAYERPID

    FADEVOLUME=10
    until [[ $FADEVOLUME -ge $VOLUMEALSA ]]; do
        set_step
        FADEVOLUME=$(($FADEVOLUME+$VOLUMESTEP))
        amixer -q -M set "$VOLUMECHANNEL" "${VOLUMESTEP}%+"
        sleep 0.2
    done
    $VOLUMERESET

elif [[ -z $PLAYERPID ]]; then
    echo "Musicplayer: $MUSICPLAYER is not running."; sleep 5

else
    echo "Unknown Error - PlayerStatus: $PLAYERSTATUS PID: $PLAYERPID"; sleep 5
fi


#!/bin/bash

WID=`xdotool search "Mozilla Firefox" | head -1`
xdotool windowactivate --sync $WID
xdotool key --clearmodifiers ctrl+l

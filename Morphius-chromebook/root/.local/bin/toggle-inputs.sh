#!/bin/bash

KEYBOARD_DEV="/dev/input/event13"   # Adjust as needed

# Keep track of evtest processes
#KBD_PID=""
KBD_LIGHT="100"

disable_inputs() {
    echo "Disabling keyboard"

    # Grab keyboard
    #evtest --grab "$KEYBOARD_DEV" >/dev/null &
    #KBD_PID=$!

	export KBD_LIGHT=$(/bin/ectool pwmgetkblight | awk '{print $NF}')
	echo $KBD_LIGHT
	
	/bin/ectool pwmsetkblight 0

	/root/.local/bin/toggle-gjs-osk.sh on

	mv /etc/keyd/cros.conf /etc/keyd/cros.conf.disabled
	mv /etc/keyd/tab.conf.disabled /etc/keyd/tab.conf

	keyd reload
}

enable_inputs() {
    echo "Enabling keyboard"

    # Kill grab processes
    #if [[ -n "$KBD_PID" ]]; then
    #    kill "$KBD_PID" 2>/dev/null
    #    wait "$KBD_PID" 2>/dev/null
    #    KBD_PID=""
    #fi

    /bin/ectool pwmsetkblight $KBD_LIGHT
    
    /root/.local/bin/toggle-gjs-osk.sh off

    mv /etc/keyd/tab.conf /etc/keyd/tab.conf.disabled
    mv /etc/keyd/cros.conf.disabled /etc/keyd/cros.conf

    keyd reload
}

trap enable_inputs EXIT

# Auto-disable on boot if already in tablet mode
if libinput debug-events --once | grep -q 'switch tablet-mode state 1'; then
    disable_inputs
fi

libinput debug-events | while read -r line; do
    if echo "$line" | grep -q 'switch tablet-mode state 1'; then
        disable_inputs
    elif echo "$line" | grep -q 'switch tablet-mode state 0'; then
        enable_inputs
    fi
done

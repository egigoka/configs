#!/usr/bin/env bash
# toggle-gjsosk.sh  Usage: toggle-gjsosk.sh USER {on|off|toggle}

USER="user"
ACTION="$1"

if ! id "$USER" &>/dev/null; then
  echo "User '$USER' not found" >&2; exit 1
fi

USERUID=$(id -u "$USER")
RUNTIME_DIR="/run/user/$USERUID"
DBUS_ADDR="unix:path=$RUNTIME_DIR/bus"

# decide new value
case "$ACTION" in
  on)    VAL="enable" ;;
  off)   VAL="disable" ;;
  *)
    echo "Usage: $0 {on|off}" >&2
    exit 1
    ;;
esac

# write new value
sudo -u "$USER" -H \
  env XDG_RUNTIME_DIR="$RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
  gnome-extensions "$VAL" gjsosk@vishram1123.com

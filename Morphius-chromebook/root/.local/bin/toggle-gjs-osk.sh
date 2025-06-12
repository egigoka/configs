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
DCONF_KEY="/org/gnome/shell/extensions/gjsosk/enable-tap-gesture"

# decide new value
case "$ACTION" in
  on)    VAL=1 ;;
  off)   VAL=0 ;;
  toggle)
    # read current
    CUR=$(sudo -u "$USER" -H \
      env XDG_RUNTIME_DIR="$RUNTIME_DIR" \
          DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
      dconf read "$DCONF_KEY")
    # strip quotes if any
    CUR=${CUR//\"/}
    [[ "$CUR" == "1" ]] && VAL=0 || VAL=1
    ;;
  *)
    echo "Usage: $0 {on|off|toggle}" >&2
    exit 1
    ;;
esac

# write new value
sudo -u "$USER" -H \
  env XDG_RUNTIME_DIR="$RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
  dconf write "$DCONF_KEY" "$VAL"

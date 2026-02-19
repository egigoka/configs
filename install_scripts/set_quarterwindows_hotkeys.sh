#!/usr/bin/env bash

if ! command -v dconf >/dev/null 2>&1; then
  echo "dconf not found, skipping quarter-windows keybindings"
elif [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  echo "No display server, skipping quarter-windows keybindings"
else
  base="/org/gnome/shell/extensions/com-troyready-quarterwindows"

  dconf write "$base/put-to-corner-ne" "['<Super>e']"
  dconf write "$base/put-to-corner-nw" "['<Super>q']"
  dconf write "$base/put-to-corner-se" "['<Super>c']"
  dconf write "$base/put-to-corner-sw" "['<Super>z']"
  dconf write "$base/put-to-half-n" "['<Super>w']"
  dconf write "$base/put-to-half-s" "['<Super>x']"
  dconf write "$base/put-to-half-e" "['<Super>d']"
  dconf write "$base/put-to-half-w" "['<Super>a']"
fi

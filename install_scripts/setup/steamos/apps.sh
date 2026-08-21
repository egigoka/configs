#!/usr/bin/env bash

# SteamOS Flatpak integration and gaming utilities.

setup_steamos_flatpak() {
  if command -v flatpak >/dev/null 2>&1; then
    flatpak override --user io.mpv.Mpv --filesystem="$CONFIGS_DIR/mpv"
    install_link "$CONFIGS_DIR/mpv" "$HOME/.var/app/io.mpv.Mpv/config/mpv"
    # Konsole flatpak: user fonts under ~/.local/share/fonts are symlinks into
    # $CONFIGS_DIR/fonts, which isn't mounted in the sandbox -- grant read access
    # so the symlinks resolve and fc-list picks the fonts up.
    if flatpak info org.kde.konsole >/dev/null 2>&1; then
      flatpak override --user org.kde.konsole --filesystem="$CONFIGS_DIR/fonts:ro"
    fi
  fi
}

setup_steamos_gaming_tools() {
  bash "$CONFIGS_DIR/install_scripts/install_decky.sh" || true

  # decky-launch-options runs inside Steam's environment, where PATH resolves
  # bare `python` to Nix Python and crashes before the game starts.
  dlo_run="$HOME/.dlo/run"
  if [ -f "$dlo_run" ] && grep -qF '/decky-launch-options/run.py' "$dlo_run"; then
    cat > "$dlo_run" <<'EOF'
#!/bin/bash
PYTHON=/usr/bin/python
[ -x "$PYTHON" ] || PYTHON=/usr/bin/python3
PLUGIN_RUN="$HOME/homebrew/plugins/decky-launch-options/run.py"

if [ -x "$PYTHON" ] && [ -f "$PLUGIN_RUN" ]; then
    "$PYTHON" "$PLUGIN_RUN" "$@"
else
    exec "$@"
fi
EOF
    chmod +x "$dlo_run"
  fi

  # KDiskMark disk benchmark: AppImage (not the sandboxed Flathub build, which
  # can't flush the OS cache -- see install_kdiskmark.sh for the why).
  sh "$CONFIGS_DIR/install_scripts/install_kdiskmark.sh" || true
}

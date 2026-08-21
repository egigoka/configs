#!/usr/bin/env bash

# Terminal and command-line application configuration.

setup_cli_configs() {
  # zellij
  install_link "$CONFIGS_DIR/zellij" "$HOME/.config/zellij"

  # mpv
  install_link "$CONFIGS_DIR/mpv" "$HOME/.config/mpv"
  [ -d "$HOME/.config/mpv/scripts/uosc" ] || bash "$CONFIGS_DIR/install_scripts/install_uosc.sh"
  # patch uosc to not disable mpv's native OSC (we use uosc only for its menu)
  [ -f "$HOME/.config/mpv/scripts/uosc/main.lua" ] && sed -i "s|^mp\.set_property('osc', 'no')|-- & -- patched: keep native OSC|" "$HOME/.config/mpv/scripts/uosc/main.lua"

  # konsole
  install_link "$CONFIGS_DIR/konsole/sessionui.rc" "$HOME/.local/share/kxmlgui5/konsole/sessionui.rc"
  install_link "$CONFIGS_DIR/konsole/konsoleui.rc" "$HOME/.local/share/kxmlgui5/konsole/konsoleui.rc"
  install_link "$CONFIGS_DIR/konsole/konsolerc" "$HOME/.config/konsolerc"
  install_link "$CONFIGS_DIR/konsole/GNOMETerminalLight.colorscheme" "$HOME/.local/share/konsole/GNOMETerminalLight.colorscheme"
  install_link "$CONFIGS_DIR/konsole/default.profile" "$HOME/.local/share/konsole/default.profile"

  # micro
  install_link "$CONFIGS_DIR/micro/bindings.json" "$HOME/.config/micro/bindings.json"
  install_link "$CONFIGS_DIR/micro/settings.json" "$HOME/.config/micro/settings.json"
  install_link "$CONFIGS_DIR/micro/colorschemes" "$HOME/.config/micro/colorschemes"

  # starship
  install_link "$CONFIGS_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
}

setup_file_listing_config() {
  install_link "$CONFIGS_DIR/lsd" "$HOME/.config/lsd"
}

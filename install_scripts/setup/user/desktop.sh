#!/usr/bin/env bash

# Fonts and Linux desktop environment configuration.

setup_desktop_configs() {
  # fonts
  install_link "$CONFIGS_DIR/fonts/Atkynson-Hyperlegible-Mono-NerdFont-Gapless-Braille" "$HOME/.local/share/fonts/Atkynson-Hyperlegible-Mono-NerdFont-Gapless-Braille"
  command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1

  # fontconfig
  install_link "$CONFIGS_DIR/fontconfig" "$HOME/.config/fontconfig/conf.d"

  # gnome quarter-windows keybindings
  sh "$CONFIGS_DIR/install_scripts/set_quarterwindows_hotkeys.sh"

  # virt-manager
  if command -v dconf >/dev/null 2>&1 && { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }; then
    dconf write /org/virt-manager/virt-manager/console/resize-guest 1
  fi

  # kde kwin scripts
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    for script_dir in "$CONFIGS_DIR"/kde-scripts/*/; do
      script_name=$(basename "$script_dir")
      if [ "$SETUP_PLATFORM" = steamos ]; then
        rm -rf "$HOME/.local/share/kwin/scripts/$script_name"
        mkdir -p "$HOME/.local/share/kwin/scripts"
        cp -a "$CONFIGS_DIR/kde-scripts/$script_name" "$HOME/.local/share/kwin/scripts/$script_name"
      else
        install_link "$CONFIGS_DIR/kde-scripts/$script_name" "$HOME/.local/share/kwin/scripts/$script_name"
      fi
      kwriteconfig6 --file kwinrc --group Plugins --key "${script_name}Enabled" true
    done
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowTopHalf "Meta+Ctrl+Alt+Shift+W,none,Tile Window to Top Half"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowRightHalf "Meta+Ctrl+Alt+Shift+D,none,Tile Window to Right Half"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowBottomHalf "Meta+Ctrl+Alt+Shift+X,none,Tile Window to Bottom Half"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowLeftHalf "Meta+Ctrl+Alt+Shift+A,none,Tile Window to Left Half"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowMaximize "Meta+Ctrl+Alt+Shift+S,none,Maximize Window Without Toggling"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowTopRight "Meta+Ctrl+Alt+Shift+E,none,Tile Window to Upper Right Quadrant"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowTopLeft "Meta+Ctrl+Alt+Shift+Q,none,Tile Window to Upper Left Quadrant"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowBottomLeft "Meta+Ctrl+Alt+Shift+Z,none,Tile Window to Lower Left Quadrant"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowBottomRight "Meta+Ctrl+Alt+Shift+C,none,Tile Window to Lower Right Quadrant"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Maximize" "none,Meta+PgUp,Maximize Window"
    qdbus org.kde.KWin /KWin reconfigure 2>/dev/null
  fi

  if command -v kwriteconfig6 >/dev/null 2>&1; then
    # Plasma Keyboard uses locale IDs and does not provide kk/emoji layouts here.
    kwriteconfig6 --file plasmakeyboardrc --group General --key enabledLocales "en_US,ru_RU,uk_UA"
    kwriteconfig6 --file plasmakeyboardrc --group General --key panelFillScreenWidth true
  fi
}

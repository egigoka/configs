#!/usr/bin/env bash

# macOS input, automation, terminal, and launchd integration.

setup_macos_integrations() {
  # karabiner
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
  fi

  # hammerspoon
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/hammerspoon/hammerspoon.lua" "$HOME/.hammerspoon/init.lua"
  fi

  # cmux
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/cmux/config.ghostty" "$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
    install_link "$CONFIGS_DIR/cmux/config.ghostty" "$HOME/Library/Application Support/cmux/config.ghostty"
  fi

  # helium tabs backup
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/scripts/helium-tabs-backup.py" "$HOME/.scripts/helium-tabs-backup.py"
    install_link "$CONFIGS_DIR/mac/com.egigoka.helium-tabs-backup.plist" "$HOME/Library/LaunchAgents/com.egigoka.helium-tabs-backup.plist"
    launchctl load "$HOME/Library/LaunchAgents/com.egigoka.helium-tabs-backup.plist" 2>/dev/null || true
  fi

  # Remove temporary unlocked SSH keys whenever the user's launchd session starts.
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/scripts/clean-unlocked-ssh-keys.sh" "$HOME/.scripts/clean-unlocked-ssh-keys.sh"
    install_link "$CONFIGS_DIR/mac/com.egigoka.clean-unlocked-ssh-keys.plist" "$HOME/Library/LaunchAgents/com.egigoka.clean-unlocked-ssh-keys.plist"
    launchctl bootout "gui/$(id -u)/com.egigoka.clean-unlocked-ssh-keys" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.egigoka.clean-unlocked-ssh-keys.plist"
  fi
}

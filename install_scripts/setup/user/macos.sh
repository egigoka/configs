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

  # xcode file templates (Clean Swift)
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/xcode-templates/Clean Swift" "$HOME/Library/Developer/Xcode/Templates/File Templates/Clean Swift"
  fi

  # xcode file templates (VIPER, Swift 6)
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/xcode-templates/VIPER" "$HOME/Library/Developer/Xcode/Templates/File Templates/VIPER"
  fi

  # xcode codesnippets
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/xcode-snippets" "$HOME/Library/Developer/Xcode/UserData/CodeSnippets"
  fi

  # xcode keybindings
  if [ "$(uname -s)" = "Darwin" ]; then
    install_link "$CONFIGS_DIR/xcode-keybindings" "$HOME/Library/Developer/Xcode/UserData/KeyBindings"
  fi

  # Remove temporary unlocked SSH keys whenever the user's launchd session starts.
  if [ "$(uname -s)" = "Darwin" ]; then
    local label=com.egigoka.clean-unlocked-ssh-keys fingerprint state_file
    state_file="$HOME/.local/state/configs/launchd/$label.sha256"
    fingerprint=$(shasum -a 256 "$CONFIGS_DIR/scripts/clean-unlocked-ssh-keys.sh" "$CONFIGS_DIR/mac/$label.plist") || return
    install_link "$CONFIGS_DIR/scripts/clean-unlocked-ssh-keys.sh" "$HOME/.scripts/clean-unlocked-ssh-keys.sh" || return
    install_link "$CONFIGS_DIR/mac/$label.plist" "$HOME/Library/LaunchAgents/$label.plist" || return
    # Links reflect edits immediately, so retain the content hashes from the last successful load.
    if [ "$fingerprint" = "$(cat "$state_file" 2>/dev/null)" ] && \
      launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
      return 0
    fi
    mkdir -p "${state_file%/*}" || return
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$label.plist" || return
    printf '%s\n' "$fingerprint" > "$state_file"
  fi
}

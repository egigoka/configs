#!/usr/bin/env bash

# Declarative NixOS setup.

setup_nixos_prerequisites() {
  echo "Packages needed (add to your NixOS configuration):"
  install fish
  install pay-respects
  install fzf
  install coreutils # dircolors
  install python3
  install autojump
  install bat
  install lsd
  install difftastic
  install gh
  install uv
  install starship
  install pstree
  echo
  install_link "$CONFIGS_DIR/fish" "$HOME/.config/fish"

  # dircolors-solarized
  [ -d "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized" ] || git clone https://github.com/seebi/dircolors-solarized "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized"

  install_virtualfish
}

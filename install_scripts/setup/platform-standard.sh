#!/usr/bin/env bash

# macOS and mutable Linux setup.

setup_standard_prerequisites() {
  # install micro editor
  install_if_missing micro || install_if_missing micro-editor

  # set micro as default editor on macOS (for current zsh session and persistent fish)
  if [ "$(uname -s)" = "Darwin" ]; then
    export EDITOR=micro
    fish -c "set -Ux EDITOR micro"
  fi

  # sponge: only purge history on shell exit (not after each command)
  fish -c "set -Ux sponge_purge_only_on_exit true"

  install_if_missing fish

  # setup default shell
  case "$(uname -s)" in
    Darwin) current_shell=$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}') ;;
    *)      current_shell=$(getent passwd "$USER" | cut -d: -f7) ;;
  esac
  if [ "$current_shell" != "$(which fish)" ]; then
    fish_path="$(which fish)"
    echo
    echo "$fish_path"
    echo
    if ! grep -qxF "$fish_path" /etc/shells; then
      echo "$fish_path" | sudo tee -a /etc/shells > /dev/null
    fi
    chsh -s "$fish_path" "$USER"
  fi

  # add homebrew to fish path on macOS
  if [ -d /opt/homebrew/bin ]; then
    fish -c "set -U fish_user_paths /opt/homebrew/bin \$fish_user_paths"
  fi

  # custom zsh plugins (still needed for dircolors-solarized)
  ZSH_CUSTOM="$CONFIGS_DIR/zsh/ZSH_CUSTOM" sh "$CONFIGS_DIR/zsh/ZSH_CUSTOM/install_themes_plugins.sh"

  # dircolors-solarized
  [ -d "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized" ] || git clone https://github.com/seebi/dircolors-solarized "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized"
  # zsh config
  #sh ~/configs/install_scripts/install_omz.sh
  #install_link ~/configs/zsh/.zshrc ~/.zshrc
  #install_link ~/configs/zsh/.p10k.zsh ~/.p10k.zsh

  # install fisher and fish plugins
  install_link "$CONFIGS_DIR/fish" "$HOME/.config/fish"
  FISH_PLUGINS=$(grep -v '^[[:space:]]*$' "$CONFIGS_DIR/fish/fish_plugins" | tr '\n' ' ')
  fish -c "cat $CONFIGS_DIR/install_scripts/install_fisher.fish | source && fisher install $FISH_PLUGINS"
  git -C "$CONFIGS_DIR" checkout fish/fish_plugins

  # apps that used in shell config
  command -v pay-respects >/dev/null 2>&1 || [ -x "$HOME/.local/bin/pay-respects" ] || sh "$CONFIGS_DIR/install_scripts/install_pay_respects.sh"
  install_if_missing fzf
  install_if_missing dircolors || install_if_missing coreutils
  install_if_missing python3
  command -v autojump >/dev/null 2>&1 || [ -d "$HOME/.autojump" ] || install_autojump
  install_if_missing bat
  install_if_missing lsd
  command -v difft >/dev/null 2>&1 || [ -x "$HOME/.local/bin/difft" ] || install_if_missing difftastic || sh "$CONFIGS_DIR/install_scripts/install_difftastic.sh"
  install_if_missing gh || install_if_missing github-cli
  command -v uv >/dev/null 2>&1 || install_if_missing uv || sh "$CONFIGS_DIR/install_scripts/install_uv.sh"
  install_if_missing starship
  install_if_missing pstree
  command -v node >/dev/null 2>&1 || install_if_missing nodejs || install_if_missing node
  command -v npm >/dev/null 2>&1 || install_if_missing npm

  uv tool install --force virtualfish
  "$HOME/.local/bin/vf" install
}

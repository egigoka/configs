#!/usr/bin/env bash

# macOS and mutable Linux setup.

setup_standard_prerequisites() {
  # install micro editor
  if ! command -v micro >/dev/null 2>&1; then
    case "${ID:-}" in
      opensuse-*) install_if_missing micro-editor || return ;;
      *) install_if_missing micro || return ;;
    esac
  fi
  command -v fish >/dev/null 2>&1 || install_if_missing fish || return

  # set micro as default editor on macOS (for current zsh session and persistent fish)
  if [ "$(uname -s)" = "Darwin" ]; then
    export EDITOR=micro
    fish --no-config -c "set -Ux EDITOR micro"
  fi

  # sponge: only purge history on shell exit (not after each command)
  fish --no-config -c "set -Ux sponge_purge_only_on_exit true"

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
    fish --no-config -c "set -U fish_user_paths /opt/homebrew/bin \$fish_user_paths"
  fi

  # custom zsh plugins (still needed for dircolors-solarized)
  ZSH_CUSTOM="$CONFIGS_DIR/zsh/ZSH_CUSTOM" sh "$CONFIGS_DIR/zsh/ZSH_CUSTOM/install_themes_plugins.sh" || return

  # dircolors-solarized
  [ -d "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized" ] || git clone https://github.com/seebi/dircolors-solarized "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized" || return
  # zsh config
  #sh ~/configs/install_scripts/install_omz.sh
  #install_link ~/configs/zsh/.zshrc ~/.zshrc
  #install_link ~/configs/zsh/.p10k.zsh ~/.p10k.zsh

  # install fisher and fish plugins
  install_link "$CONFIGS_DIR/fish" "$HOME/.config/fish" || return
  FISH_PLUGINS=$(grep -v '^[[:space:]]*$' "$CONFIGS_DIR/fish/fish_plugins" | tr '\n' ' ')
  fish -c "cat $CONFIGS_DIR/install_scripts/install_fisher.fish | source && fisher install $FISH_PLUGINS" || return
  git -C "$CONFIGS_DIR" checkout fish/fish_plugins

  # apps that used in shell config
  if ! command -v pay-respects >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/pay-respects" ]; then
    if [ "$SETUP_OS" = Linux ]; then
      command -v zstd >/dev/null 2>&1 || install_if_missing zstd || return
    fi
    sh "$CONFIGS_DIR/install_scripts/install_pay_respects.sh" || return
  fi
  command -v fzf >/dev/null 2>&1 || install_if_missing fzf || return
  command -v dircolors >/dev/null 2>&1 || install_if_missing coreutils || return
  command -v python3 >/dev/null 2>&1 || install_if_missing python3 || return
  command -v autojump >/dev/null 2>&1 || [ -d "$HOME/.autojump" ] || install_autojump || return
  command -v bat >/dev/null 2>&1 || install_if_missing bat || return
  command -v lsd >/dev/null 2>&1 || install_if_missing lsd || return
  command -v difft >/dev/null 2>&1 || [ -x "$HOME/.local/bin/difft" ] || install_if_missing difftastic || sh "$CONFIGS_DIR/install_scripts/install_difftastic.sh" || return
  if ! command -v gh >/dev/null 2>&1; then
    case "${ID:-}" in
      arch) install_if_missing github-cli || return ;;
      *) install_if_missing gh || return ;;
    esac
  fi
  command -v uv >/dev/null 2>&1 || install_if_missing uv || sh "$CONFIGS_DIR/install_scripts/install_uv.sh" || return
  install_starship || return
  if ! command -v pstree >/dev/null 2>&1; then
    case "$SETUP_OS" in
      Darwin) install_if_missing pstree || return ;;
      *) install_if_missing psmisc || return ;;
    esac
  fi
  command -v jq >/dev/null 2>&1 || install_if_missing jq || return
  install_cua_runtime_packages || return
  command -v node >/dev/null 2>&1 || install_if_missing nodejs || install_if_missing node || return
  command -v npm >/dev/null 2>&1 || install_if_missing npm || return

  uv tool install --force virtualfish || return
  "$HOME/.local/bin/vf" install
}

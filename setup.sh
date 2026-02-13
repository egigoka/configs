#!/bin/bash

# get product name
product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

# install command
CONFIGS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$CONFIGS_DIR/install_scripts/epm.sh"

# detect real user when running under sudo
if [ -n "$SUDO_USER" ]; then
  REAL_USER="$SUDO_USER"
  REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  as_user() { sudo -u "$REAL_USER" -- "$@"; }
else
  REAL_USER="$(whoami)"
  REAL_HOME="$HOME"
  as_user() { "$@"; }
fi

pkg_installed() {
  local pkg=$1
  case "$(uname -s)" in
    Linux)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          rocky) rpm -q "$pkg" >/dev/null 2>&1 ;;
          arch) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
          debian|ubuntu|droidian) dpkg -s "$pkg" >/dev/null 2>&1 ;;
          opensuse-tumbleweed|opensuse-leap) rpm -q "$pkg" >/dev/null 2>&1 ;;
          alpine) apk info -e "$pkg" >/dev/null 2>&1 ;;
          nixos)
            grep -q -F "$pkg" /etc/nixos/configuration.nix /etc/nixos/packages.nix 2>/dev/null
            ;;
          *) return 1 ;;
        esac
      else
        return 1
      fi
      ;;
    Darwin)
      brew list --formula "$pkg" >/dev/null 2>&1 || brew list --cask "$pkg" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

install_if_missing() {
  local pkg
  for pkg in "$@"; do
    if pkg_installed "$pkg"; then
      echo "$pkg already installed, skipping"
    else
      install "$pkg"
    fi
  done
}

# if no package
install_autojump() {
  pwd=$PWD
  shell=$SHELL
  git clone https://github.com/wting/autojump.git "$CONFIGS_DIR/autojump"
  cd "$CONFIGS_DIR/autojump"
  export SHELL=/bin/zsh
  as_user python3 "$CONFIGS_DIR/autojump/install.py"
  rm -rf "$CONFIGS_DIR/autojump"
  cd "$pwd"
  export SHELL=$shell
}

install_link() {
  if [ $# -ne 2 ]; then
    printf 'Usage: %s SRC DST\n' "${0##*/}" >&2
    return 1
  fi

  src=$1
  dst=$2

  parent=$(dirname -- "$dst")
  mkdir -p -- "$parent" || return

  dst="${dst%/}"  # strip slash at the end

  # already a correct symlink — nothing to do
  if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$src" ]; then
    return 0
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv -- "$dst" "$dst.preinstall" || return
  fi

  ln -s -- "$src" "$dst"
}

# install some packages
case "$(uname -s)" in
  Linux)
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
      	rocky)
          ;;
        arch)
          ;;
        debian|ubuntu|droidian)
          ;;
        opensuse-tumbleweed|opensuse-leap)
          ;;
        alpine)
          install_if_missing git
          install_if_missing shadow # chsh
          install_if_missing ncurses # tput in omz
          install_if_missing tar # GNU tar (busybox tar lacks zstd)
          install_if_missing zstd
          ;;
        nixos)
          ;;
        *)
         echo "Unknown Linux distribution"
         exit
          ;;
      esac
    else
      echo "Unknown Linux distribution"
      exit
    fi
    ;;
  Darwin)
    
    ;;
  *)
  	echo Unsupported OS
  	exit
    ;;
esac

is_nixos=false
if [ -f /etc/os-release ]; then
  . /etc/os-release
  [ "$ID" = "nixos" ] && is_nixos=true
fi

if [ "$is_nixos" = true ]; then
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
  install virtualfish
  echo
  install_link "$CONFIGS_DIR/fish" "$REAL_HOME/.config/fish"
else
  # install shell
  #install zsh
  install_if_missing fish

  # setup default shell
  case "$(uname -s)" in
    Darwin) current_shell=$(dscl . -read "/Users/$REAL_USER" UserShell | awk '{print $2}') ;;
    *)      current_shell=$(getent passwd "$REAL_USER" | cut -d: -f7) ;;
  esac
  if [ "$current_shell" != "$(which fish)" ]; then
    echo
    echo $(which fish)
    echo
    chsh "$REAL_USER"
  fi

  # custom zsh plugins (still needed for dircolors-solarized)
  ZSH_CUSTOM="$CONFIGS_DIR/zsh/ZSH_CUSTOM" sh "$CONFIGS_DIR/zsh/ZSH_CUSTOM/install_themes_plugins.sh"

  # zsh config
  #sh ~/configs/install_scripts/install_omz.sh
  #install_link ~/configs/zsh/.zshrc ~/.zshrc
  #install_link ~/configs/zsh/.p10k.zsh ~/.p10k.zsh

  # install fisher and fish plugins
  install_link "$CONFIGS_DIR/fish" "$REAL_HOME/.config/fish"
  as_user fish -c "cat $CONFIGS_DIR/install_scripts/install_fisher.fish | source && fisher install jorgebucaran/fisher && fisher update"

  # apps that used in shell config
  command -v pay-respects >/dev/null 2>&1 || [ -x "$REAL_HOME/.local/bin/pay-respects" ] || install_if_missing pay-respects || as_user sh "$CONFIGS_DIR/install_scripts/install_pay_respects.sh"
  install_if_missing fzf
  install_if_missing dircolors || install_if_missing coreutils
  install_if_missing python3
  install_if_missing autojump || install_autojump
  install_if_missing bat
  install_if_missing lsd
  install_if_missing difftastic
  install_if_missing gh || install_if_missing github-cli
  install_if_missing uv

  as_user uv tool install virtualfish
  as_user "$REAL_HOME/.local/bin/vf" install
    
  # git config
  git config --global pull.rebase true
fi

# my chromebook
if [ "$product_name" = "Morphius" ]; then
  install_link "$CONFIGS_DIR/Morphius-chromebook/root/.local/bin/toggle-inputs.sh" /root/.local/bin/toggle-inputs.sh
  install_link "$CONFIGS_DIR/Morphius-chromebook/root/.local/bin/toggle-gjs-osk-extension.sh" /root/.local/bin/toggle-gjs-osk-extension.sh
  install_link "$CONFIGS_DIR/Morphius-chromebook/etc/keyd/tab.conf.disabled" /etc/keyd/tab.conf.disabled
  install_link "$CONFIGS_DIR/Morphius-chromebook/etc/keyd/cros.conf" /etc/keyd/cros.conf
  install_link "$CONFIGS_DIR/Morphius-chromebook/bin/ectool" /bin/ectool
fi

# mpv
install_link "$CONFIGS_DIR/mpv" "$REAL_HOME/.config/mpv"

# konsole
install_link "$CONFIGS_DIR/konsole/sessionui.rc" "$REAL_HOME/.local/share/kxmlgui5/konsole/sessionui.rc"
install_link "$CONFIGS_DIR/konsole/konsoleui.rc" "$REAL_HOME/.local/share/kxmlgui5/konsole/konsoleui.rc"
install_link "$CONFIGS_DIR/konsole/konsolerc" "$REAL_HOME/.config/konsolerc"
install_link "$CONFIGS_DIR/konsole/GNOMETerminalLight.colorscheme" "$REAL_HOME/.local/share/konsole/GNOMETerminalLight.colorscheme"
install_link "$CONFIGS_DIR/konsole/default.profile" "$REAL_HOME/.local/share/konsole/default.profile"

# micro
install_link "$CONFIGS_DIR/micro/bindings.json" "$REAL_HOME/.config/micro/bindings.json"
install_link "$CONFIGS_DIR/micro/settings.json" "$REAL_HOME/.config/micro/settings.json"
install_link "$CONFIGS_DIR/micro/colorschemes" "$REAL_HOME/.config/micro/colorschemes"

# starship
install_link "$CONFIGS_DIR/starship/starship.toml" "$REAL_HOME/.config/starship.toml"

# opencode
install_link "$CONFIGS_DIR/opencode/kv.json" "$REAL_HOME/.local/state/opencode/kv.json"
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$REAL_HOME/.config/opencode/AGENTS.md"

# claude code
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$REAL_HOME/.claude/CLAUDE.md"

# codex
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$REAL_HOME/.codex/AGENTS.md"

# lsd
install_link "$CONFIGS_DIR/lsd" "$REAL_HOME/.config/lsd"

# fontconfig
install_link "$CONFIGS_DIR/fontconfig" "$REAL_HOME/.config/fontconfig/conf.d"

# gnome quarter-windows keybindings
sh ~/configs/install_scripts/set_quarterwindows_hotkeys.sh

# virt-manager
dconf write /org/virt-manager/virt-manager/console/resize-guest 1

# launch shell
exec fish

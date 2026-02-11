#!/bin/bash

# get product name
product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

# install command
shopt -s expand_aliases
source ~/configs/install_scripts/epm.sh

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
  git clone https://github.com/wting/autojump.git ~/configs/autojump
  cd ~/configs/autojump
  export SHELL=/bin/zsh
  python3 ~/configs/autojump/install.py
  rm -rf ~/configs/autojump
  cd $pwd
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
  install uv
  install virtualfish
  echo
  install_link ~/configs/fish ~/.config/fish
else
  # install shell
  #install zsh
  install_if_missing fish

  # setup default shell
  case "$(uname -s)" in
    Darwin) current_shell=$(dscl . -read /Users/$(whoami) UserShell | awk '{print $2}') ;;
    *)      current_shell=$(getent passwd $(whoami) | cut -d: -f7) ;;
  esac
  if [ "$current_shell" != "$(which fish)" ]; then
    echo
    echo $(which fish)
    echo
    chsh $(whoami)
  fi

  # custom zsh plugins (still needed for dircolors-solarized)
  ZSH_CUSTOM="$HOME/configs/zsh/ZSH_CUSTOM" sh ~/configs/zsh/ZSH_CUSTOM/install_themes_plugins.sh

  # zsh config
  #sh ~/configs/install_scripts/install_omz.sh
  #install_link ~/configs/zsh/.zshrc ~/.zshrc
  #install_link ~/configs/zsh/.p10k.zsh ~/.p10k.zsh

  # install fisher
  fish -c "cat ~/configs/install_scripts/install_fisher.fish | source && fisher install jorgebucaran/fisher"
  install_link ~/configs/fish ~/.config/fish

  # apps that used in shell config
  install_if_missing pay-respects || sh ~/configs/install_scripts/install_pay_respects.sh
  install_if_missing fzf
  install_if_missing dircolors || install_if_missing coreutils
  install_if_missing python3
  install_if_missing autojump || install_autojump
  install_if_missing bat
  install_if_missing lsd
  install_if_missing difftastic
  install_if_missing uv
  uv tool install virtualfish
  vf install
  # install zoxide
fi

# my chromebook
if [ "$product_name" = "Morphius" ]; then
  install_link ~/configs/Morphius-chromebook/root/.local/bin/toggle-inputs.sh /root/.local/bin/toggle-inputs.sh
  install_link ~/configs/Morphius-chromebook/root/.local/bin/toggle-gjs-osk-extension.sh /root/.local/bin/toggle-gjs-osk-extension.sh
  install_link ~/configs/Morphius-chromebook/etc/keyd/tab.conf.disabled /etc/keyd/tab.conf.disabled
  install_link ~/configs/Morphius-chromebook/etc/keyd/cros.conf /etc/keyd/cros.conf
  install_link ~/configs/Morphius-chromebook/bin/ectool /bin/ectool
fi

# mpv
install_link ~/configs/mpv ~/.config/mpv

# konsole
install_link "$HOME/configs/konsole/sessionui.rc" "$HOME/.local/share/kxmlgui5/konsole/sessionui.rc"
install_link "$HOME/configs/konsole/konsoleui.rc" "$HOME/.local/share/kxmlgui5/konsole/konsoleui.rc"
install_link "$HOME/configs/konsole/konsolerc" "$HOME/.config/konsolerc"

# micro
install_link ~/configs/micro/bindings.json ~/.config/micro/bindings.json
install_link ~/configs/micro/settings.json ~/.config/micro/settings.json
install_link ~/configs/micro/colorschemes ~/.config/micro/colorschemes

# starship
install_link ~/configs/starship/starship.toml ~/.config/starship.toml

# lsd
install_link ~/configs/lsd ~/.config/lsd

# fontconfig
install_link ~/configs/fontconfig ~/.config/fontconfig/conf.d

# launch shell
exec fish

#!/bin/sh

# get product name
product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

# install command
source ~/configs/install_scripts/epm.sh

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
          install git
          install shadow # chsh
          install ncurses # tput in omz
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
  install fish

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
  install pay-respects || sh ~/configs/install_scripts/install_pay_respects.sh
  install fzf
  install dircolors || install coreutils
  install python3
  install autojump || install_autojump
  install bat
  install lsd
  install difftastic
  install uv
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

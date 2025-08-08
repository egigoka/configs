#!/bin/sh

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

# install shell
install zsh
install fish

# setup default shell
echo
echo $(which zsh)
echo $(which fish)
echo
chsh $(whoami)

# custom plugins
ZSH_CUSTOM="$HOME/configs/zsh/ZSH_CUSTOM" sh ~/configs/zsh/ZSH_CUSTOM/install_themes_plugins.sh

# zsh config
sh ~/configs/install_scripts/install_omz.sh
install_link ~/configs/zsh/.zshrc ~/.zshrc
install_link ~/configs/zsh/.p10k.zsh ~/.p10k.zsh

# fish config
fish -c "cat ~/configs/install_scripts/install_fisher.fish | source && fisher install jorgebucaran/fisher"

# apps that used in shell config
install pay-respects || sh ~/configs/install_scripts/install_pay_respects.sh
install fzf
install dircolors || install coreutils
install python3
install autojump || install_autojump
install uv
uv tool install virtualfish
vf install
# install zoxide

# my chromebook
if [ "$product_name" = "Morphius" ]; then
  echo "This is Morphius"
  install_link ~/configs/Morphius-chromebook/root/.local/bin/toggle-inputs.sh /root/.local/bin/toggle-inputs.sh
  install_link ~/configs/Morphius-chromebook/root/.local/bin/toggle-gjs-osk-extension.sh /root/.local/bin/toggle-gjs-osk-extension.sh
  install_link ~/configs/Morphius-chromebook/etc/keyd/tab.conf.disabled /etc/keyd/tab.conf.disabled
  install_link ~/configs/Morphius-chromebook/etc/keyd/cros.conf /etc/keyd/cros.conf
  install_link ~/configs/Morphius-chromebook/bin/ectool /bin/ectool
else
  echo "Not Morphius (it's $product_name)"
fi

# mpv
install_link ~/configs/mpv ~/.config/mpv

# konsole
install_link ~/configs/konsole/sessionui.rc ~/.local/share/kxmlgui5/konsole/sessionui.rc
install_link ~/configs/konsole/konsoleui.rc ~/.local/share/kxmlgui5/konsole/konsoleui.rc

# fish
install_link ~/configs/fish ~/.configs/fish

# micro
install_link ~/configs/micro/bindings.json ~/.config/micro/bindings.json

# starship
install_link ~/configs/starship/starship.toml ~/.config/starship.toml

# launch shell
exec zsh --login

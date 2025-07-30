
# easy packet management
case "$(uname -s)" in
  Linux)
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        rocky)
          alias updateall="dnf clean all && dnf makecache && dnf upgrade -y"
          alias install="dnf install -y"
          alias uninstall="dnf remove -y"
          ;;
        arch)
          alias updateall='yay -Syu --devel --timeupdate; yay -Sc'
          alias install="yay -S"
          alias uninstall="yay -Rns"
          alias updatemirrors="cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak; rate-mirrors arch | sudo tee /etc/pacman.d/mirrorlist; sudo pacman -Syy"
          ;;
        debian|ubuntu|droidian)
          alias updateall='apt update && apt upgrade && apt dist-upgrade'
          alias install="apt install"
          alias uninstall="apt -y remove"
          ;;
        opensuse-tumbleweed|opensuse-leap)
          alias updateall='zypper refresh && zypper dup'
          alias install="zypper -n install"
          alias uninstall="zypper -n remove"
          ;;
        alpine)
          alias updateall='apk upgrade --available'
          alias install='apk add'
          alias uninstall='apk del'
          ;;
        *)
          alias updateall='echo "Unknown Linux distribution"'
          alias install='echo "Unknown Linux distribution"'
          alias uninstall='echo "Unknown Linux distribution"'
          ;;
      esac
    else
      alias updateall='echo "Unknown Linux distribution"'
      alias install='echo "Unknown Linux distribution"'
      alias uninstall='echo "Unknown Linux distribution"'
    fi
    ;;
  Darwin)
    alias updateall='brew update; brew upgrade --no-quarantine --greedy; brew cleanup --prune=all'
    alias install='brew install --no-quarantine'
    alias uninstall='brew remove'
    ;;
  *)
    alias updateall='echo "Unknown operating system"'
    alias install='echo "Unknown operating system"'
    alias uninstall='echo "Unknown operating system"'
    ;;
esac

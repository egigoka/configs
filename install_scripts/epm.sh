#!/usr/bin/env bash

# easy packet management
case "$(uname -s)" in
  Linux)
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        rocky)
          updateall() { dnf clean all && dnf makecache && dnf upgrade -y; }
          install() { dnf install -y "$@"; }
          uninstall() { dnf remove -y "$@"; }
          ;;
        arch)
          updateall() { yay -Syu --devel --timeupdate; yay -Sc; }
          install() { yay -S "$@"; }
          uninstall() { yay -Rns "$@"; }
          updatemirrors() { cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak; rate-mirrors arch | sudo tee /etc/pacman.d/mirrorlist; sudo pacman -Syy; }
          ;;
        debian|ubuntu|droidian)
          updateall() { apt update && apt upgrade && apt dist-upgrade; }
          install() { apt install "$@"; }
          uninstall() { apt -y remove "$@"; }
          ;;
        opensuse-tumbleweed|opensuse-leap)
          if [[ $UID != 0 && $EUID != 0 ]]; then
            _zypper() { sudo zypper "$@"; }
          else
            _zypper() { zypper "$@"; }
          fi
          updateall() { _zypper refresh && _zypper dup; }
          install() { _zypper -n install "$@"; }
          uninstall() { _zypper -n remove "$@"; }
          ;;
        alpine)
          updateall() { apk upgrade --available; }
          install() { apk add "$@"; }
          uninstall() { apk del "$@"; }
          ;;
        nixos)
          updateall() { echo "Use NixOS configuration to manage packages"; }
          install() { echo "  $*"; }
          uninstall() { echo "Use NixOS configuration to manage packages"; }
          ;;
        *)
          updateall() { echo "Unknown Linux distribution"; }
          install() { echo "Unknown Linux distribution"; }
          uninstall() { echo "Unknown Linux distribution"; }
          ;;
      esac
    else
      updateall() { echo "Unknown Linux distribution"; }
      install() { echo "Unknown Linux distribution"; }
      uninstall() { echo "Unknown Linux distribution"; }
    fi
    ;;
  Darwin)
    updateall() { brew update; brew upgrade --no-quarantine --greedy; brew cleanup --prune=all; }
    install() { brew install --no-quarantine "$@"; }
    uninstall() { brew remove "$@"; }
    ;;
  *)
    updateall() { echo "Unknown operating system"; }
    install() { echo "Unknown operating system"; }
    uninstall() { echo "Unknown operating system"; }
    ;;
esac

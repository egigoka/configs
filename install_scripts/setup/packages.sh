#!/usr/bin/env bash

# Package discovery and cross-platform package preparation.

pkg_installed() {
  local pkg=$1
  case "$(uname -s)" in
    Linux)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          rocky) rpm -q "$pkg" >/dev/null 2>&1 || command -v "$pkg" >/dev/null 2>&1 ;;
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
  local previous_dir=$PWD
  local previous_shell=$SHELL

  git clone https://github.com/wting/autojump.git "$CONFIGS_DIR/autojump" || return
  cd "$CONFIGS_DIR/autojump" || return
  export SHELL=/bin/zsh
  python3 "$CONFIGS_DIR/autojump/install.py"
  rm -rf "$CONFIGS_DIR/autojump"
  cd "$previous_dir" || return
  export SHELL=$previous_shell
}

install_usage_tui() {
  if ! command -v usage >/dev/null 2>&1; then
    uv tool install git+https://github.com/egigoka/usage
  fi
}

install_virtualfish() {
  if ! command -v vf >/dev/null 2>&1; then
    uv tool install virtualfish
  fi

  if command -v vf >/dev/null 2>&1; then
    vf install
  elif [ -x "$HOME/.local/bin/vf" ]; then
    "$HOME/.local/bin/vf" install
  else
    echo "vf not found; skipping virtualfish setup" >&2
  fi
}

install_usage() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "uv not found; skipping usage install" >&2
    return 0
  fi

  uv tool install --force --refresh "git+https://github.com/egigoka/usage.git@main"
}

prepare_host_packages() {
  case "$SETUP_OS" in
    Linux)
      if [ ! -f /etc/os-release ]; then
        printf 'Cannot identify this Linux distribution\n' >&2
        return 1
      fi

      # shellcheck source=/etc/os-release
      . /etc/os-release
      case "$ID" in
        rocky|arch|debian|ubuntu|droidian|opensuse-tumbleweed|opensuse-leap|nixos|steamos)
          ;;
        alpine)
          install_if_missing git
          install_if_missing shadow # chsh
          install_if_missing ncurses # tput in omz
          install_if_missing tar # GNU tar, BusyBox tar lacks zstd
          install_if_missing zstd
          ;;
        *)
          printf 'Unsupported Linux distribution: %s\n' "$ID" >&2
          return 1
          ;;
      esac
      ;;
    Darwin)
      ;;
    *)
      printf 'Unsupported OS: %s\n' "$SETUP_OS" >&2
      return 1
      ;;
  esac

  return 0
}

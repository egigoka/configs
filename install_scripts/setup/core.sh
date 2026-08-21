#!/usr/bin/env bash

# Shared setup context and filesystem helpers.

initialize_setup_context() {
  CONFIGS_DIR=${CONFIGS_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
  SETUP_OS=$(uname -s)
  USER=$(whoami)

  case "$SETUP_OS" in
    Darwin)
      SETUP_PLATFORM=standard
      OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-macos"
      ;;
    Linux)
      if grep -q '^ID=steamos$' /etc/os-release 2>/dev/null; then
        SETUP_PLATFORM=steamos
        OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-steamos"
      elif grep -q '^ID=nixos$' /etc/os-release 2>/dev/null; then
        SETUP_PLATFORM=nixos
        OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-other"
      else
        SETUP_PLATFORM=standard
        OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-other"
      fi
      ;;
    *)
      SETUP_PLATFORM=unsupported
      OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-other"
      ;;
  esac

  # C.UTF-8 works with both system and Nix glibc. Nix glibc does not ship
  # en_US.UTF-8, even when the host lists that locale.
  export LANG=C.UTF-8 LC_ALL=C.UTF-8
  unset LC_COLLATE LC_CTYPE LC_TIME LC_PAPER LC_MEASUREMENT LC_NUMERIC LANGUAGE
}

install_link() {
  local src dst parent

  if [ $# -ne 2 ]; then
    printf 'Usage: %s SRC DST\n' "${0##*/}" >&2
    return 1
  fi

  src=$1
  dst=$2

  parent=$(dirname -- "$dst")
  mkdir -p -- "$parent" || return

  dst="${dst%/}"  # strip slash at the end

  # A correct symlink needs no work.
  if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$src" ]; then
    return 0
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -e "$dst.preinstall" ]; then
      rm -rf "$dst"
    else
      mv -- "$dst" "$dst.preinstall" || return
    fi
  fi

  ln -s -- "$src" "$dst"
}

#!/usr/bin/env bash

set -eu -o pipefail

if [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
  echo "Decky Loader: run as the deck user, not root." >&2
  exit 1
fi

INSTALLER_URL="https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh"
target_user="${SUDO_USER:-$(id -un)}"
target_home="$(getent passwd "$target_user" | cut -d: -f6)"
PLUGIN_LOADER="$target_home/homebrew/services/PluginLoader"

if [ -z "$target_home" ]; then
  echo "Decky Loader: could not resolve home for $target_user." >&2
  exit 1
fi

if [ -x "$PLUGIN_LOADER" ] && systemctl is-enabled plugin_loader >/dev/null 2>&1; then
  if ! systemctl is-active --quiet plugin_loader 2>/dev/null; then
    sudo systemctl start plugin_loader >/dev/null 2>&1 || true
  fi
  echo "Decky Loader already installed, skipping."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Decky Loader: curl not found; skipping." >&2
  exit 1
fi

tmp="$(mktemp)"
ro_disabled=false
trap 'rm -f "$tmp"; [ "$ro_disabled" = true ] && sudo steamos-readonly enable >/dev/null 2>&1 || true' EXIT

echo "Downloading Decky Loader installer..."
curl --proto '=https' --tlsv1.2 -sSf -L "$INSTALLER_URL" -o "$tmp"
chmod +x "$tmp"

if command -v steamos-readonly >/dev/null 2>&1; then
  ro="$(steamos-readonly status 2>/dev/null || true)"
  if [ "$ro" = enabled ]; then
    sudo steamos-readonly disable
    ro_disabled=true
  fi
fi

echo "Installing Decky Loader..."
run_installer() {
  if [ "$(id -u)" -eq 0 ]; then
    env "SUDO_USER=$target_user" "PATH=$PATH" bash "$tmp"
  else
    sudo env "SUDO_USER=$target_user" "PATH=$PATH" bash "$tmp"
  fi
}

if command -v jq >/dev/null 2>&1; then
  run_installer
elif command -v nix >/dev/null 2>&1; then
  nix shell --extra-experimental-features "nix-command flakes" nixpkgs#jq -c \
    bash -c 'if [ "$(id -u)" -eq 0 ]; then env "SUDO_USER=$1" "PATH=$PATH" bash "$2"; else sudo env "SUDO_USER=$1" "PATH=$PATH" bash "$2"; fi' bash "$target_user" "$tmp"
else
  echo "Decky Loader: jq not found; install jq or Nix, then re-run setup." >&2
  exit 1
fi

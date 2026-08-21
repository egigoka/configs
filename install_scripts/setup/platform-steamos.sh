#!/usr/bin/env bash

STEAMOS_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install_scripts/setup/steamos/nix.sh
source "$STEAMOS_SETUP_DIR/steamos/nix.sh"
# shellcheck source=install_scripts/setup/steamos/system.sh
source "$STEAMOS_SETUP_DIR/steamos/system.sh"
# shellcheck source=install_scripts/setup/steamos/network.sh
source "$STEAMOS_SETUP_DIR/steamos/network.sh"
# shellcheck source=install_scripts/setup/steamos/apps.sh
source "$STEAMOS_SETUP_DIR/steamos/apps.sh"
unset STEAMOS_SETUP_DIR

setup_steamos_prerequisites() {
  setup_steamos_nix
}

setup_steamos_integrations() {
  setup_steamos_shell_startup
  setup_steamos_sshd_sudoers
  setup_steamos_locale
  setup_steamos_ssh
  setup_steamos_wireguard
  setup_steamos_flatpak
  setup_steamos_tailscale
  setup_steamos_gaming_tools
}

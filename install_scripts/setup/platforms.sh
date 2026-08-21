#!/usr/bin/env bash

PLATFORM_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install_scripts/setup/platform-steamos.sh
source "$PLATFORM_SETUP_DIR/platform-steamos.sh"
# shellcheck source=install_scripts/setup/platform-nixos.sh
source "$PLATFORM_SETUP_DIR/platform-nixos.sh"
# shellcheck source=install_scripts/setup/platform-standard.sh
source "$PLATFORM_SETUP_DIR/platform-standard.sh"
unset PLATFORM_SETUP_DIR

setup_platform_prerequisites() {
  case "$SETUP_PLATFORM" in
    steamos) setup_steamos_prerequisites ;;
    nixos) setup_nixos_prerequisites ;;
    standard) setup_standard_prerequisites ;;
    *)
      printf 'Unsupported OS: %s\n' "$SETUP_OS" >&2
      return 1
      ;;
  esac
}

setup_platform_integrations() {
  case "$SETUP_PLATFORM" in
    steamos)
      configure_git_defaults
      setup_steamos_integrations
      ;;
    standard)
      configure_git_defaults
      ;;
    nixos)
      ;;
  esac
}

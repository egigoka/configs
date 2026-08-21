#!/bin/bash

CONFIGS_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_DIR="$CONFIGS_DIR/install_scripts/setup"

# Load implementation modules.
# shellcheck source=install_scripts/epm.sh
source "$CONFIGS_DIR/install_scripts/epm.sh"
# shellcheck source=install_scripts/setup/core.sh
source "$SETUP_DIR/core.sh"
# shellcheck source=install_scripts/setup/packages.sh
source "$SETUP_DIR/packages.sh"
# shellcheck source=install_scripts/setup/agents.sh
source "$SETUP_DIR/agents.sh"
# shellcheck source=install_scripts/setup/platforms.sh
source "$SETUP_DIR/platforms.sh"
# shellcheck source=install_scripts/setup/user-config.sh
source "$SETUP_DIR/user-config.sh"

initialize_setup_context

if [ "${1:-}" = "--codex-only" ]; then
  configure_codex
  exit 0
fi

prepare_host_packages || exit 1
setup_platform_prerequisites || exit 1
install_agent_tools
setup_platform_integrations

install_usage
setup_cli_configs
setup_macos_integrations
setup_agent_configs || exit 1
setup_file_listing_config
setup_desktop_configs

exec fish

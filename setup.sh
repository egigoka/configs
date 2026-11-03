#!/bin/bash

CONFIGS_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_DIR="$CONFIGS_DIR/install_scripts/setup"

# Load implementation modules.
# shellcheck source=install_scripts/epm.sh
source "$CONFIGS_DIR/install_scripts/epm.sh"
# shellcheck source=install_scripts/setup/core.sh
source "$SETUP_DIR/core.sh"
# shellcheck source=install_scripts/setup/progress.sh
source "$SETUP_DIR/progress.sh"
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
  setup_progress_init 1 || exit 1
  setup_step "Codex configuration" configure_codex || exit 1
  setup_progress_finish
  exit 0
fi

setup_progress_init 9 || exit 1
setup_step "Host packages" prepare_host_packages || exit 1
setup_step "Platform prerequisites" setup_platform_prerequisites || exit 1
setup_step "Agent tools" install_agent_tools || exit 1
setup_step "Platform integrations" setup_platform_integrations

setup_step "CLI configuration" setup_cli_configs
setup_step "macOS integrations" setup_macos_integrations
setup_step "Agent configuration" setup_agent_configs || exit 1
setup_step "File listing configuration" setup_file_listing_config
setup_step "Desktop configuration" setup_desktop_configs
setup_progress_finish

exec fish

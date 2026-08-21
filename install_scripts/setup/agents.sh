#!/usr/bin/env bash

AGENT_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install_scripts/setup/agents/codex.sh
source "$AGENT_SETUP_DIR/agents/codex.sh"
# shellcheck source=install_scripts/setup/agents/opencode.sh
source "$AGENT_SETUP_DIR/agents/opencode.sh"
# shellcheck source=install_scripts/setup/agents/configs.sh
source "$AGENT_SETUP_DIR/agents/configs.sh"
unset AGENT_SETUP_DIR

install_agent_tools() {
  install_opencode_tools
  install_usage_tui
}

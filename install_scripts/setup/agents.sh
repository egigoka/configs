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
  export PATH="$HOME/.local/bin:$PATH"
  setup_parallel "Agent utilities" --foreground install_opencode_tools \
    configure_graphify_agent install_usage install_cua_driver
}

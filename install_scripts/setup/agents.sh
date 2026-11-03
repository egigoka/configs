#!/usr/bin/env bash

AGENT_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install_scripts/setup/agents/codex.sh
source "$AGENT_SETUP_DIR/agents/codex.sh"
# shellcheck source=install_scripts/setup/agents/opencode.sh
source "$AGENT_SETUP_DIR/agents/opencode.sh"
# shellcheck source=install_scripts/setup/agents/configs.sh
source "$AGENT_SETUP_DIR/agents/configs.sh"
unset AGENT_SETUP_DIR

prepare_external_agent_skills() {
  configure_graphify_agent || return
  bash "$CONFIGS_DIR/install_scripts/update_swiftui_expert_skill.sh" "$OPENCODE_CONFIG_DIR"
}

install_agent_tools() {
  export PATH="$HOME/.local/bin:$PATH"
  setup_parallel "Agent utilities" --foreground install_opencode_tools \
    prepare_external_agent_skills install_usage install_cua_driver
}

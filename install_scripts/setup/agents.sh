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
  bash "$CONFIGS_DIR/install_scripts/update_swiftui_expert_skill.sh" "$OPENCODE_CONFIG_DIR" || return
  update_setup_caveman
}

update_setup_vendor_skills() {
  update_setup_unslop_skill || return
  update_setup_selected_skills || return
  update_setup_apple_skills
}

install_agent_packages() {
  install_opencode_tools || return
  install_cua_driver
}

install_agent_builds() (
  # Existing credentials work without terminal input. Retry failures in the
  # foreground after workers finish, so private repositories can still prompt.
  export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=false SSH_ASKPASS=false GCM_INTERACTIVE=Never
  export SSH_ASKPASS_REQUIRE=force
  export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-${GIT_SSH:-ssh}} -oBatchMode=yes"
  if ! install_opencode_builds >"$SETUP_LOG_DIR/opencode-builds.log" 2>&1; then
    touch "$SETUP_LOG_DIR/opencode-builds.retry" || return
  fi
  install_usage
)

install_agent_tools() {
  export PATH="$HOME/.local/bin:$PATH"
  SETUP_AGENT_SKILLS_READY=0
  prepare_opencode_tools || return
  rm -f "$SETUP_LOG_DIR/opencode-builds.retry" || return
  if [ "$SETUP_JOBS" -eq 1 ]; then
    # Sequential mode retains terminal access for every build.
    install_agent_packages || return
    install_opencode_builds || return
    install_usage || return
    prepare_external_agent_skills || return
    update_setup_vendor_skills || return
  else
    setup_parallel "Agent updates" --foreground install_agent_packages \
      install_agent_builds prepare_external_agent_skills update_setup_vendor_skills || return
    if [ -f "$SETUP_LOG_DIR/opencode-builds.retry" ]; then
      cat "$SETUP_LOG_DIR/opencode-builds.log" >&2
      printf 'Retrying OpenCode builds in foreground; log: %s/opencode-builds.log\n' "$SETUP_LOG_DIR" >&2
      install_opencode_builds || return
    fi
  fi
  SETUP_AGENT_SKILLS_READY=1
}

#!/usr/bin/env bash

# Final links and updates shared by the installed coding agents.

setup_agent_configs() {
  # opencode
  bash "$CONFIGS_DIR/install_scripts/update_unslop_skill.sh" "$CONFIGS_DIR" || return
  bash "$CONFIGS_DIR/install_scripts/update_selected_agent_skills.sh" "$CONFIGS_DIR" || return
  bash "$CONFIGS_DIR/install_scripts/update_caveman.sh" "$OPENCODE_CONFIG_DIR"
  configure_caveman_session_models "$OPENCODE_CONFIG_DIR"
  bash "$CONFIGS_DIR/install_scripts/update_ponytail.sh" "$OPENCODE_CONFIG_DIR"
  bash "$CONFIGS_DIR/install_scripts/update_frontend_design_skill.sh" "$OPENCODE_CONFIG_DIR"
  bash "$CONFIGS_DIR/install_scripts/update_swiftui_expert_skill.sh" "$OPENCODE_CONFIG_DIR"
  install_link "$OPENCODE_CONFIG_DIR/kv.json" "$HOME/.local/state/opencode/kv.json"
  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$OPENCODE_CONFIG_DIR/AGENTS.md"
  install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/opencode"
  install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/kilo"

  # forgecode
  install_link "$CONFIGS_DIR/forgecode/permissions.yaml" "$HOME/.config/forge/permissions.yaml"

  # claude code
  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  install_link "$CONFIGS_DIR/claude/settings.json" "$HOME/.claude/settings.json"

  # codex
  configure_codex

  # forge (two-account setup: ~/forge1 + ~/forge2, symlinked via ~/forge)
  if [ -d "$HOME/forge" ] && [ ! -L "$HOME/forge" ]; then
    mv "$HOME/forge" "$HOME/forge1"
  fi
  mkdir -p "$HOME/forge1" "$HOME/forge2"
  install_link "$HOME/forge1" "$HOME/forge"
  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/forge1/AGENTS.md"
  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/forge2/AGENTS.md"
}

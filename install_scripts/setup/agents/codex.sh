#!/usr/bin/env bash

# Codex homes, agents, and shared skills.

configure_codex_home() {
  local codex_home=$1
  local skill agent legacy_ultragoogle

  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$codex_home/AGENTS.md"
  install_link "$CONFIGS_DIR/codex/codex.toml" "$codex_home/config.toml"

  legacy_ultragoogle="$codex_home/skills/ultragoogle"
  if [ -L "$legacy_ultragoogle" ] && [ "$(readlink -- "$legacy_ultragoogle")" = "$CONFIGS_DIR/opencode/skills/ultragoogle" ]; then
    rm -- "$legacy_ultragoogle"
  fi

  for skill in \
    caveman \
    caveman-commit \
    caveman-compress \
    caveman-help \
    caveman-review \
    frontend-design \
    swiftui-expert-skill \
    ultrabrowser
  do
    install_link "$OPENCODE_CONFIG_DIR/skills/$skill" "$codex_home/skills/$skill"
  done

  install_link "$CONFIGS_DIR/codex/skills/cavecrew" "$codex_home/skills/cavecrew"

  for agent in "$CONFIGS_DIR"/codex/agents/*.toml; do
    install_link "$agent" "$codex_home/agents/$(basename "$agent")"
  done
}

configure_codex() {
  local codex_home

  for codex_home in "$HOME/.codex" "$HOME/.codex-2" "$HOME/.codex-3"; do
    configure_codex_home "$codex_home"
  done
}

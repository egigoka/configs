#!/usr/bin/env bash

# Codex homes, agents, and shared skills.

configure_codex_home() {
  local codex_home=$1
  local skill agent legacy_ultragoogle legacy_target legacy_resolved

  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$codex_home/AGENTS.md"
  install_link "$CONFIGS_DIR/codex/codex.toml" "$codex_home/config.toml"

  legacy_ultragoogle="$codex_home/skills/ultragoogle"
  if [ -L "$legacy_ultragoogle" ]; then
    legacy_target=$(readlink -- "$legacy_ultragoogle" 2>/dev/null) || legacy_target=""
    case "$legacy_target" in
      "$CONFIGS_DIR/opencode/skills/ultragoogle") rm -- "$legacy_ultragoogle" ;;
      *)
        # Also match relative form (../../.../configs/opencode/skills/ultragoogle).
        legacy_resolved=$(python3 -c 'import os.path,sys; p=sys.argv[1]; print(os.path.normpath(os.path.join(sys.argv[2], p)) if not os.path.isabs(p) else p)' "$legacy_target" "$(dirname -- "$legacy_ultragoogle")" 2>/dev/null) || legacy_resolved=""
        [ -n "$legacy_resolved" ] && [ "$legacy_resolved" = "$CONFIGS_DIR/opencode/skills/ultragoogle" ] && rm -- "$legacy_ultragoogle"
        ;;
    esac
  fi

  for skill in \
    caveman \
    caveman-commit \
    caveman-compress \
    caveman-help \
    caveman-review \
    frontend-design \
    swiftui-expert-skill \
    ultrabrowser \
    iphone-duo \
    adopt-c-bounds-safety \
    app-intents-specialist \
    app-intents-whats-new-27 \
    audit-xcode-security-settings \
    building-document-based-swiftui-applications \
    device-interaction \
    modernize-tests \
    swiftui-specialist \
    swiftui-whats-new-27 \
    uikit-app-modernization
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

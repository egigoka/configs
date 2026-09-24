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
  bash "$CONFIGS_DIR/install_scripts/update_apple_agent_skills.sh" "$CONFIGS_DIR" || return
  install_link "$OPENCODE_CONFIG_DIR/kv.json" "$HOME/.local/state/opencode/kv.json"
  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$OPENCODE_CONFIG_DIR/AGENTS.md"
  install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/opencode"
  install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/kilo"

  # forgecode
  install_link "$CONFIGS_DIR/forgecode/permissions.yaml" "$HOME/.config/forge/permissions.yaml"

  # claude code
  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  install_link "$CONFIGS_DIR/claude/settings.json" "$HOME/.claude/settings.json"

  # claude skills/commands/agents: canonical mapping lives in configs/claude/
  # (symlinks into opencode), live homes link to the repo copies.
  local repo_entry entry_name
  mkdir -p "$CONFIGS_DIR/claude/skills" "$CONFIGS_DIR/claude/commands" "$CONFIGS_DIR/claude/agents"
  for repo_entry in "$OPENCODE_CONFIG_DIR"/skills/*/; do
    entry_name=$(basename "$repo_entry")
    install_link "$OPENCODE_CONFIG_DIR/skills/$entry_name" "$CONFIGS_DIR/claude/skills/$entry_name"
  done
  for repo_entry in "$OPENCODE_CONFIG_DIR"/commands/*.md; do
    entry_name=$(basename "$repo_entry")
    install_link "$OPENCODE_CONFIG_DIR/commands/$entry_name" "$CONFIGS_DIR/claude/commands/$entry_name"
  done
  for repo_entry in "$OPENCODE_CONFIG_DIR"/agents/*.md; do
    entry_name=$(basename "$repo_entry")
    install_link "$OPENCODE_CONFIG_DIR/agents/$entry_name" "$CONFIGS_DIR/claude/agents/$entry_name"
  done
  # prune repo links whose opencode source is gone (keep real dirs like sentry-cli)
  for repo_entry in "$CONFIGS_DIR"/claude/skills/* "$CONFIGS_DIR"/claude/commands/* "$CONFIGS_DIR"/claude/agents/*; do
    [ -L "$repo_entry" ] && [ ! -e "$repo_entry" ] && rm -- "$repo_entry"
  done
  for repo_entry in "$CONFIGS_DIR"/claude/skills/* "$CONFIGS_DIR"/claude/commands/* "$CONFIGS_DIR"/claude/agents/*; do
    entry_name=$(basename "$repo_entry")
    case "$repo_entry" in
      */skills/*)
        install_link "$repo_entry" "$HOME/.claude/skills/$entry_name"
        install_link "$repo_entry" "$HOME/.agents/skills/$entry_name"
        ;;
      */commands/*) install_link "$repo_entry" "$HOME/.claude/commands/$entry_name" ;;
      */agents/*) install_link "$repo_entry" "$HOME/.claude/agents/$entry_name" ;;
    esac
  done

  # claude MCP servers (mirror opencode.json "mcp"); user scope persists in ~/.claude.json
  if command -v claude >/dev/null 2>&1; then
    claude mcp get cua-driver >/dev/null 2>&1 || claude mcp add -s user cua-driver -- cua-driver mcp || return
    claude mcp get xcode >/dev/null 2>&1 || claude mcp add -s user xcode -- xcrun mcpbridge || return
    claude mcp get mobile-mcp >/dev/null 2>&1 || claude mcp add -s user mobile-mcp -e MOBILEMCP_DISABLE_TELEMETRY=1 -- mcp-server-mobile || return
    claude mcp get xcodebuild-mcp >/dev/null 2>&1 || claude mcp add -s user xcodebuild-mcp -e XCODEBUILDMCP_SENTRY_DISABLED=true -- xcodebuildmcp mcp || return
    claude mcp get safari-mcp >/dev/null 2>&1 || claude mcp add -s user safari-mcp -- /usr/bin/safaridriver --mcp || return
    claude mcp get sentry >/dev/null 2>&1 || claude mcp add -s user -t http sentry https://mcp.sentry.dev/mcp || return
  fi

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

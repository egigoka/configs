#!/usr/bin/env bash

# Final links and updates shared by the installed coding agents.

update_setup_unslop_skill() {
  bash "$CONFIGS_DIR/install_scripts/update_unslop_skill.sh" "$CONFIGS_DIR"
}

update_setup_selected_skills() {
  bash "$CONFIGS_DIR/install_scripts/update_selected_agent_skills.sh" "$CONFIGS_DIR"
}

update_setup_apple_skills() {
  bash "$CONFIGS_DIR/install_scripts/update_apple_agent_skills.sh" "$CONFIGS_DIR"
}

update_setup_caveman() {
  bash "$CONFIGS_DIR/install_scripts/update_caveman.sh" "$OPENCODE_CONFIG_DIR"
}

claude_mcp_server_present() {
  local name=$1 user_servers=$2
  case " $user_servers " in
    *" $name "*) return 0 ;;
  esac
  claude mcp get "$name" >/dev/null 2>&1
}

configure_claude_mcp_servers() {
  command -v claude >/dev/null 2>&1 || return 0

  # Existing user registrations need no CLI process. Missing entries still use
  # the CLI, which also checks project and local scopes before adding a server.
  local user_servers
  user_servers=
  if [ -z "${CLAUDE_CONFIG_DIR:-}" ]; then
    user_servers=$(python3 - "$HOME/.claude.json" <<'PY'
import json
import sys

names = ("cua-driver", "xcode", "mobile-mcp", "xcodebuild-mcp", "safari-mcp", "sentry")

def registered(server):
    if not isinstance(server, dict):
        return False
    transport = server.get("type", "stdio")
    field = "command" if transport == "stdio" else "url"
    return (transport in ("stdio", "http", "sse")
            and isinstance(server.get(field), str) and bool(server[field]))

try:
    with open(sys.argv[1]) as source:
        document = json.load(source)
    servers = document.get("mcpServers", {})
    print(" ".join(name for name in names if registered(servers.get(name))))
except (OSError, ValueError, AttributeError):
    sys.exit(1)
PY
    ) || user_servers=
  fi

  claude_mcp_server_present cua-driver "$user_servers" || claude mcp add -s user cua-driver -- cua-driver mcp || return
  claude_mcp_server_present xcode "$user_servers" || claude mcp add -s user xcode -- xcrun mcpbridge || return
  claude_mcp_server_present mobile-mcp "$user_servers" || claude mcp add -s user mobile-mcp -e MOBILEMCP_DISABLE_TELEMETRY=1 -- mcp-server-mobile || return
  claude_mcp_server_present xcodebuild-mcp "$user_servers" || claude mcp add -s user xcodebuild-mcp -e XCODEBUILDMCP_SENTRY_DISABLED=true -- xcodebuildmcp mcp || return
  claude_mcp_server_present safari-mcp "$user_servers" || claude mcp add -s user safari-mcp -- /usr/bin/safaridriver --mcp || return
  claude_mcp_server_present sentry "$user_servers" || claude mcp add -s user -t http sentry https://mcp.sentry.dev/mcp || return
}

setup_agent_configs() {
  # opencode
  setup_parallel "Shared skills" --foreground update_setup_caveman \
    update_setup_unslop_skill update_setup_selected_skills update_setup_apple_skills || return
  configure_caveman_session_models "$OPENCODE_CONFIG_DIR"
  bash "$CONFIGS_DIR/install_scripts/update_ponytail.sh" "$OPENCODE_CONFIG_DIR"
  bash "$CONFIGS_DIR/install_scripts/update_frontend_design_skill.sh" "$OPENCODE_CONFIG_DIR"
  bash "$CONFIGS_DIR/install_scripts/update_rea.sh" "$CONFIGS_DIR" || return
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
    entry_name=${repo_entry%/}
    entry_name=${entry_name##*/}
    install_link "$OPENCODE_CONFIG_DIR/skills/$entry_name" "$CONFIGS_DIR/claude/skills/$entry_name"
  done
  for repo_entry in "$OPENCODE_CONFIG_DIR"/commands/*.md; do
    entry_name=${repo_entry##*/}
    install_link "$OPENCODE_CONFIG_DIR/commands/$entry_name" "$CONFIGS_DIR/claude/commands/$entry_name"
  done
  for repo_entry in "$OPENCODE_CONFIG_DIR"/agents/*.md; do
    entry_name=${repo_entry##*/}
    install_link "$OPENCODE_CONFIG_DIR/agents/$entry_name" "$CONFIGS_DIR/claude/agents/$entry_name"
  done
  # prune repo links whose opencode source is gone (keep real dirs like sentry-cli)
  for repo_entry in "$CONFIGS_DIR"/claude/skills/* "$CONFIGS_DIR"/claude/commands/* "$CONFIGS_DIR"/claude/agents/*; do
    [ -L "$repo_entry" ] && [ ! -e "$repo_entry" ] && rm -- "$repo_entry"
  done
  for repo_entry in "$CONFIGS_DIR"/claude/skills/* "$CONFIGS_DIR"/claude/commands/* "$CONFIGS_DIR"/claude/agents/*; do
    entry_name=${repo_entry##*/}
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
  configure_claude_mcp_servers || return

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

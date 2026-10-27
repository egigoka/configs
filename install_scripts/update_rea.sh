#!/usr/bin/env bash
# Install/update REA (rea-agents) CLI and register it with repo-managed agents
# (opencode, claude code, codex). Skill installs with each registration by default.
set -u

configs_dir=${1:-"$(cd "$(dirname "$0")/.." && pwd)"}
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

if [ "$(uname -s)" = Darwin ]; then
  opencode_dir="$configs_dir/opencode-macos"
else
  opencode_dir="$configs_dir/opencode-other"
fi

have_rea() { command -v rea >/dev/null 2>&1 && rea --version >/dev/null 2>&1; }

if ! have_rea; then
  echo "Installing rea-agents..."
  npm install --global 'rea-agents@latest' || {
    echo "Error: npm could not install rea-agents and no working rea is installed" >&2
    exit 1
  }
else
  npm install --global 'rea-agents@latest' >/dev/null 2>&1 || \
    echo "Warning: rea-agents update failed; retaining installed rea" >&2
fi

# OPENCODE_CONFIG_DIR pins registration into the repo copy instead of ~/.config.
OPENCODE_CONFIG_DIR="$opencode_dir" rea setup \
  --client opencode --client claude_code --client codex --yes || {
  echo "Warning: rea setup exited nonzero; verifying registrations" >&2
}

fail=0
python3 - "$opencode_dir/opencode.json" <<'PY' || fail=1
import json, sys
doc = json.load(open(sys.argv[1]))
mcp = doc.get("mcp", {})
if "rea" in mcp.get("servers", {}) or "rea" in mcp:
    print("opencode: rea registered")
else:
    print("opencode: rea registration missing", file=sys.stderr)
    sys.exit(1)
PY
if [ -f "$HOME/.claude.json" ]; then
  HOME="$HOME" python3 -c 'import json,os; d=json.load(open(os.path.join(os.environ["HOME"], ".claude.json"))); assert "rea" in d.get("mcpServers", {}), "missing"; print("claude_code: rea registered")' || \
    echo "Warning: claude_code rea registration not confirmed" >&2
else
  echo "Warning: $HOME/.claude.json not found; skipping claude_code check" >&2
fi
for home in "$HOME/.codex" "$HOME/.codex-2" "$HOME/.codex-3"; do
  [ -f "$home/config.toml" ] || continue
  if grep -q '^\[mcp_servers\.rea\]' "$home/config.toml"; then
    echo "codex ($home): rea registered"
  else
    echo "codex ($home): rea registration missing" >&2
    fail=1
  fi
done

[ "$fail" -eq 0 ] || {
  echo "Error: one or more rea registrations are missing" >&2
  exit 1
}
echo "REA updated and registered."

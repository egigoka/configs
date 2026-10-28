#!/usr/bin/env bash
# Install/update REA (rea-agents) CLI and register it with repo-managed agents
# (opencode, claude code, codex). Skill installs with each registration by default.
set -u

configs_dir=${1:-"$(cd "$(dirname "$0")/.." && pwd)"}
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

# rea-agents needs node >=22.23.4 / >=24.22.1 / >=26.12.1 (uses node:zlib);
# distro node is often older, so install a known-good user-local copy.
ver_ge() { # $1 >= $2 ?
  local a1 a2 a3 b1 b2 b3
  IFS=. read -r a1 a2 a3 <<<"$1"
  IFS=. read -r b1 b2 b3 <<<"$2"
  [ "$a1" -gt "$b1" ] && return 0; [ "$a1" -lt "$b1" ] && return 1
  [ "${a2:-0}" -gt "${b2:-0}" ] && return 0; [ "${a2:-0}" -lt "${b2:-0}" ] && return 1
  [ "${a3:-0}" -ge "${b3:-0}" ]
}
node_ok() {
  command -v node >/dev/null 2>&1 || return 1
  local cur maj floor
  cur=$(node --version 2>/dev/null) || return 1
  cur=${cur#v}
  maj=${cur%%.*}
  case "$maj" in
    22) floor=22.23.4 ;; 24) floor=24.22.1 ;; 26) floor=26.12.1 ;;
    27|28|29|3[0-9]|[4-9][0-9]) return 0 ;;
    *) return 1 ;;
  esac
  ver_ge "$cur" "$floor"
}
install_local_node() {
  local version os arch ext dest tmp
  # No pinned version: take newest 26.x; 26.12.0 is the oldest known-good.
  version=$(curl -fsSL https://nodejs.org/dist/index.json | python3 -c \
    'import json,sys; print(next(v["version"] for v in json.load(sys.stdin) if v["version"].startswith("v26.")))')
  [ -n "${version:-}" ] || { echo "Could not resolve latest node 26.x" >&2; return 1; }
  version=${version#v}
  ver_ge "$version" 26.12.0 || { echo "Resolved node $version below known-good 26.12.0" >&2; return 1; }
  case "$(uname -s)" in
    Darwin) os=darwin; ext=tar.gz ;;
    Linux) os=linux; ext=tar.xz ;;
    *) echo "Unsupported OS for local node install: $(uname -s)" >&2; return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64) arch=x64 ;; aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported arch for local node install: $(uname -m)" >&2; return 1 ;;
  esac
  dest="$HOME/.local/node"
  tmp=$(mktemp -d) || return 1
  curl -fsSL "https://nodejs.org/dist/v$version/node-v$version-$os-$arch.$ext" \
    -o "$tmp/node.$ext" || { rm -rf "$tmp"; return 1; }
  rm -rf "$dest"
  mkdir -p "$HOME/.local/bin"
  tar -xf "$tmp/node.$ext" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  mv "$tmp/node-v$version-$os-$arch" "$dest"
  rm -rf "$tmp"
  for b in node npm npx; do ln -sf "$dest/bin/$b" "$HOME/.local/bin/$b"; done
  export PATH="$HOME/.local/bin:$PATH"
}
if ! node_ok; then
  echo "node missing or too old for rea-agents; installing user-local node..."
  install_local_node || {
    echo "Error: could not install a new enough node" >&2
    exit 1
  }
  node_ok || { echo "Error: local node install did not satisfy version check" >&2; exit 1; }
fi

# System npm prefix (e.g. /usr/local) is often not user-writable.
if ! [ -w "$(npm root -g 2>/dev/null || printf '/nonexistent')" ]; then
  npm config set prefix "$HOME/.local"
fi

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

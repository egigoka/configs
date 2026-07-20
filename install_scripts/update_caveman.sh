#!/usr/bin/env bash
# Refresh vendored caveman opencode assets (plugin, commands, agents, skills,
# and any new files added upstream) from github:JuliusBrussee/caveman.
#
# The upstream installer is pointed at the repo via XDG_CONFIG_HOME so it writes
# into the selected repo config instead of the real ~/.config/opencode.

set -e

CONFIGS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -s)" = Darwin ]; then
  default_opencode_dir="$CONFIGS_DIR/opencode-macos"
else
  default_opencode_dir="$CONFIGS_DIR/opencode-other"
fi
opencode_dir="${1:-$default_opencode_dir}"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found; skipping caveman update" >&2
  exit 0
fi

echo "Updating caveman opencode assets from upstream..."
# --only opencode: just the opencode provider. --force: overwrite stale vendored
# files. --non-interactive: never prompt. Pin XDG so it writes into the repo.
ln -s "$opencode_dir" "$tmp/opencode"
XDG_CONFIG_HOME="$tmp" \
  npx -y github:JuliusBrussee/caveman -- \
  --only opencode --force --non-interactive || {
    echo "caveman update failed; keeping existing vendored assets" >&2
    exit 0
  }

# Drop installer-generated files we don't track:
#   - AGENTS.md is a Tier-3 ruleset; we keep claude/CLAUDE.md as the
#     AGENTS source (setup.sh symlinks it).
#   - opencode.json.bak is an installer backup.
rm -f "$opencode_dir/AGENTS.md" "$opencode_dir/opencode.json.bak"

echo "caveman opencode assets updated."

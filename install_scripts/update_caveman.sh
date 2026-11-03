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
  [ ! -f "$tmp/config.json" ] || cp "$tmp/config.json" "$opencode_dir/opencode.json"
  [ ! -f "$tmp/server.js" ] || cp "$tmp/server.js" "$opencode_dir/plugins/caveman/server.js"
  rm -rf "$tmp"
}
trap cleanup EXIT

refresh_caveman_checkout() {
  local checkout=$1 repo=https://github.com/JuliusBrussee/caveman.git origin status
  command -v git >/dev/null 2>&1 && command -v node >/dev/null 2>&1 || return 1
  if [ ! -e "$checkout" ] && [ ! -L "$checkout" ]; then
    git clone --depth=1 --single-branch "$repo" "$tmp/caveman" || return
    mkdir -p "${checkout%/*}" || return
    mv "$tmp/caveman" "$checkout" || return
  else
    [ ! -L "$checkout" ] && [ -d "$checkout/.git" ] || return 1
    origin=$(git -C "$checkout" config --get remote.origin.url) || return
    [ "$origin" = "$repo" ] || return 1
    status=$(git -C "$checkout" status --porcelain) || return
    [ -z "$status" ] || return 1
    git -C "$checkout" fetch --depth=1 origin HEAD || return
    git -C "$checkout" checkout --detach FETCH_HEAD || return
  fi
  [ -f "$checkout/installer/install.js" ]
}

run_caveman_installer() {
  # The OpenCode installer uses only Node's standard library. Keep its source
  # checkout current without npm resolving and preparing a Git package each run.
  local checkout="${XDG_CACHE_HOME:-$HOME/.cache}/configs/caveman"
  if refresh_caveman_checkout "$checkout"; then
    if XDG_CONFIG_HOME="$tmp" node "$checkout/installer/install.js" \
      --only opencode --force --non-interactive; then
      return 0
    fi
  fi
  if command -v npx >/dev/null 2>&1; then
    echo "Cached caveman installer unavailable or failed; falling back to npx" >&2
    XDG_CONFIG_HOME="$tmp" npx -y --allow-git=root github:JuliusBrussee/caveman -- \
      --only opencode --force --non-interactive
  else
    echo "No caveman installer available" >&2
    return 1
  fi
}

echo "Updating caveman opencode assets from upstream..."
# --only opencode: just the opencode provider. --force: overwrite stale vendored
# files. --non-interactive: never prompt. Pin XDG so it writes into the repo.
# npm 12 blocks Git packages by default; allow the requested root package.
cp "$opencode_dir/opencode.json" "$tmp/config.json"
if [ -f "$opencode_dir/plugins/caveman/server.js" ]; then
  cp "$opencode_dir/plugins/caveman/server.js" "$tmp/server.js"
fi
ln -s "$opencode_dir" "$tmp/opencode"
run_caveman_installer || {
    echo "caveman update failed; keeping existing vendored assets" >&2
    exit 0
  }

# Drop installer-generated files we don't track:
#   - AGENTS.md is a Tier-3 ruleset; we keep claude/CLAUDE.md as the
#     AGENTS source (setup.sh symlinks it).
#   - opencode.json.bak is an installer backup.
#   - .caveman-opencode-* tracks installer ownership and rollback data, which
#     is unnecessary for vendored files managed by Git.
rm -f "$opencode_dir/AGENTS.md" "$opencode_dir/opencode.json.bak"
rm -rf "$opencode_dir/.caveman-opencode-backups" \
  "$opencode_dir/.caveman-opencode-ownership.json"

echo "caveman opencode assets updated."

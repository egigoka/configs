#!/usr/bin/env bash
# Refresh vendored opencode frontend-design skill from Claude Code official plugin.

set -e

CONFIGS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -s)" = Darwin ]; then
  default_opencode_dir="$CONFIGS_DIR/opencode-macos"
else
  default_opencode_dir="$CONFIGS_DIR/opencode-other"
fi
dst="${1:-$default_opencode_dir}/skills/frontend-design"

sources=(
  "$HOME/.claude/plugins/marketplaces/claude-plugins-official/plugins/frontend-design/skills/frontend-design"
  "$HOME/.claude/plugins/cache/claude-plugins-official/frontend-design/unknown/skills/frontend-design"
)

src=""
for candidate in "${sources[@]}"; do
  if [ -f "$candidate/SKILL.md" ]; then
    src=$candidate
    break
  fi
done

if [ -z "$src" ]; then
  echo "Claude Code frontend-design plugin not found; keeping vendored opencode skill" >&2
  exit 0
fi

mkdir -p "$dst"
cp -f "$src/SKILL.md" "$dst/SKILL.md"
if [ -f "$src/LICENSE.txt" ]; then
  cp -f "$src/LICENSE.txt" "$dst/LICENSE.txt"
fi

echo "frontend-design opencode skill updated from Claude Code plugin."

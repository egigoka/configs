#!/usr/bin/env bash
# Refresh vendored opencode SwiftUI expert skill from upstream Agent Skill repo.

set -e

CONFIGS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -s)" = Darwin ]; then
  default_opencode_dir="$CONFIGS_DIR/opencode-macos"
else
  default_opencode_dir="$CONFIGS_DIR/opencode-other"
fi
dst="${1:-$default_opencode_dir}/skills/swiftui-expert-skill"
tmp="$(mktemp -d)"
staged="$dst.update.$$"

cleanup() {
  rm -rf "$tmp"
  rm -rf "$staged"
}
trap cleanup EXIT

git clone --depth=1 "https://github.com/AvdLee/SwiftUI-Agent-Skill" "$tmp/SwiftUI-Agent-Skill"

rm -rf "$staged"
cp -R "$tmp/SwiftUI-Agent-Skill/skills/swiftui-expert-skill" "$staged"
cp "$tmp/SwiftUI-Agent-Skill/LICENSE" "$staged/LICENSE"
[ -f "$staged/SKILL.md" ]

rm -rf "$dst"
mv "$staged" "$dst"

echo "swiftui-expert-skill opencode skill updated from upstream repo."

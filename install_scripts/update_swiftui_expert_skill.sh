#!/usr/bin/env bash
# Refresh vendored opencode SwiftUI expert skill from upstream Agent Skill repo.

set -e

CONFIGS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
dst="$CONFIGS_DIR/opencode/skills/swiftui-expert-skill"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

git clone --depth=1 "https://github.com/AvdLee/SwiftUI-Agent-Skill" "$tmp/SwiftUI-Agent-Skill"

rm -rf "$dst"
cp -R "$tmp/SwiftUI-Agent-Skill/swiftui-expert-skill" "$dst"
cp "$tmp/SwiftUI-Agent-Skill/LICENSE" "$dst/LICENSE"

echo "swiftui-expert-skill opencode skill updated from upstream repo."

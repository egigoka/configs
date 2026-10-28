#!/usr/bin/env bash
# Ensure @dietrichgebert/ponytail@latest is the only ponytail entry in opencode.json V2 plugin list.

set -e

CONFIGS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(uname -s)" = Darwin ]; then
  default_opencode_dir="$CONFIGS_DIR/opencode-macos"
else
  default_opencode_dir="$CONFIGS_DIR/opencode-other"
fi
json="${1:-$default_opencode_dir}/opencode.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found; skipping ponytail plugin check" >&2
  exit 0
fi

plugin="@dietrichgebert/ponytail@latest"
if jq -e --arg p "$plugin" '.plugins | index($p)' "$json" >/dev/null 2>&1; then
  echo "ponytail already in opencode.json, skipping"
  exit 0
fi

tmp=$(mktemp)
jq --arg p "$plugin" '.plugins |= ((. // []) | map(select(startswith("@dietrichgebert/ponytail") | not)) + [$p])' "$json" > "$tmp"
mv "$tmp" "$json"
echo "Set $plugin in opencode.json"

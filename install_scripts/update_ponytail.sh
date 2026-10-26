#!/usr/bin/env bash
# Ensure @dietrichgebert/ponytail@5.3.2 is in opencode.json V2 plugin list.

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

if jq -e '.plugins | index("@dietrichgebert/ponytail@5.3.2")' "$json" >/dev/null 2>&1; then
  echo "ponytail already in opencode.json, skipping"
  exit 0
fi

tmp=$(mktemp)
jq '.plugins += ["@dietrichgebert/ponytail@5.3.2"]' "$json" > "$tmp"
mv "$tmp" "$json"
echo "Added @dietrichgebert/ponytail@5.3.2 to opencode.json"

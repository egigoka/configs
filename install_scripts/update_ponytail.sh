#!/usr/bin/env bash
# Ensure @dietrichgeber/ponytail is in opencode.json plugin list.

set -e

CONFIGS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
json="$CONFIGS_DIR/opencode/opencode.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found; skipping ponytail plugin check" >&2
  exit 0
fi

if jq -e '.plugin | index("@dietrichgeber/ponytail")' "$json" >/dev/null 2>&1; then
  echo "ponytail already in opencode.json, skipping"
  exit 0
fi

tmp=$(mktemp)
jq '.plugin += ["@dietrichgeber/ponytail"]' "$json" > "$tmp"
mv "$tmp" "$json"
echo "Added @dietrichgeber/ponytail to opencode.json"

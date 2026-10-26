#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
root="${OPENCODE_PLUGIN_DIR:-$HOME/.local/share/opencode-v2-plugins}"
for tool in gh git node npm bun; do
  command -v "$tool" >/dev/null || { printf 'Required tool missing: %s\n' "$tool" >&2; exit 1; }
done
mkdir -p "$root"

while read -r name revision; do
  [ -n "$name" ] || continue
  checkout="$root/$name"
  repo="egigoka/$name"
  if [ ! -e "$checkout" ]; then
    gh repo clone "$repo" "$checkout"
  fi
  if [ -L "$checkout" ] || [ ! -d "$checkout/.git" ]; then
    printf 'Refusing to replace non-checkout path: %s\n' "$checkout" >&2
    exit 1
  fi
  origin=$(git -C "$checkout" remote get-url origin)
  case "$origin" in
    "https://github.com/$repo"|"https://github.com/$repo.git"|"git@github.com:$repo.git") ;;
    *) printf 'Unexpected origin for %s: %s\n' "$name" "$origin" >&2; exit 1 ;;
  esac
  if [ -n "$(git -C "$checkout" status --porcelain)" ]; then
    printf 'Preserve local edits before updating %s\n' "$checkout" >&2
    exit 1
  fi
  git -C "$checkout" fetch origin "$revision"
  git -C "$checkout" checkout --detach "$revision"
  (
    cd "$checkout"
    npm ci --ignore-scripts --no-audit --no-fund
    npm run build
    npm run test:v2
    test -f dist/index.js
  )
done < "$script_dir/opencode_plugins.lock"

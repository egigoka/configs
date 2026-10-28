#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
root="${OPENCODE_PLUGIN_DIR:-$HOME/.local/share/opencode-v2-plugins}"

# setup.sh never installs bun, so self-install user-local (nodejs-style).
if ! command -v bun >/dev/null 2>&1; then
  echo "bun not found; installing to ~/.bun..."
  export BUN_INSTALL="$HOME/.bun"
  curl -fsSL https://bun.sh/install | bash || exit 1
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.bun/bin/bun" "$HOME/.local/bin/bun"
  export PATH="$HOME/.local/bin:$PATH"
fi

for tool in git node npm bun; do
  command -v "$tool" >/dev/null || { printf 'Required tool missing: %s\n' "$tool" >&2; exit 1; }
done
mkdir -p "$root"

while read -r name revision; do
  [ -n "$name" ] || continue
  checkout="$root/$name"
  repo="egigoka/$name"
  if [ ! -e "$checkout" ]; then
    # gh auth may be missing/expired; git falls back to stored credentials.
    if command -v gh >/dev/null 2>&1 && gh repo clone "$repo" "$checkout"; then
      :
    else
      git clone "https://github.com/$repo.git" "$checkout" || {
        printf 'Clone failed for %s; private repo? configure git credentials (gh auth login or credential helper)\n' "$repo" >&2
        exit 1
      }
    fi
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

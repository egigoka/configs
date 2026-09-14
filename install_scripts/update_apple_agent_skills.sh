#!/usr/bin/env bash
# Refresh vendored Apple Xcode built-in agent skills and mirror iphone-duo.
#
# Apple skills come from the local Xcode install via `xcrun agent skills export`
# (includes uikit-app-modernization, the resizability skill that pairs with the
# iphone-duo skill distilled from https://youtube.com/watch?v=h00uDeTYdLA).
# iphone-duo is static; opencode-macos is canonical and is mirrored outward.
set -u

configs_dir=${1:-"$(cd "$(dirname "$0")/.." && pwd)"}
hermes_home=${HERMES_HOME:-"$HOME/.hermes"}
canonical="$configs_dir/opencode-macos/skills/iphone-duo"
roots=(
  "$configs_dir/opencode-macos/skills"
  "$configs_dir/opencode-other/skills"
  "$configs_dir/opencode-steamos/skills"
  "$hermes_home/skills"
)

all_installed() {
  local root
  # Each root must at least carry the resizability skill plus iphone-duo.
  for root in "${roots[@]}"; do
    [ -s "$root/iphone-duo/SKILL.md" ] || return 1
    [ -s "$root/uikit-app-modernization/SKILL.md" ] || return 1
  done
  return 0
}

retain_or_fail() {
  message=$1
  if all_installed; then
    printf 'Warning: %s; retaining installed Apple skills\n' "$message" >&2
    exit 0
  fi
  printf 'Error: %s and required skills are missing\n' "$message" >&2
  exit 1
}

sync_dir() {
  src=$1
  dst=$2
  parent=$(dirname "$dst")
  mkdir -p "$parent" || return 1
  if [ -d "$dst" ] && [ ! -L "$dst" ] && diff -r -q -x '.DS_Store' "$src" "$dst" >/dev/null 2>&1; then
    printf 'current -> %s\n' "$dst"
    return 0
  fi
  staged="$parent/.$(basename "$dst").new.$$"
  backup="$parent/.$(basename "$dst").old.$$"
  rm -rf "$staged" "$backup" || return 1
  cp -R "$src" "$staged" || return 1
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv -f "$dst" "$backup" || return 1
    if ! mv -f "$staged" "$dst"; then
      mv -f "$backup" "$dst"
      return 1
    fi
    rm -rf "$backup"
  else
    mv -f "$staged" "$dst" || return 1
  fi
  printf 'updated -> %s\n' "$dst"
}

[ -s "$canonical/SKILL.md" ] || { printf 'Error: canonical iphone-duo skill missing at %s\n' "$canonical" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || retain_or_fail 'python3 is unavailable'

if ! command -v xcrun >/dev/null 2>&1; then
  retain_or_fail 'xcrun is unavailable; cannot re-export Apple skills'
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/apple-agent-skills.XXXXXX") || retain_or_fail 'could not create staging directory'
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

if ! xcrun agent skills export --output-dir "$tmp_dir/export" >/dev/null 2>&1; then
  retain_or_fail 'xcrun agent skills export failed'
fi

xcode_version=$(xcodebuild -version 2>/dev/null | awk '/^Xcode /{print $2; exit}')
xcode_build=$(xcodebuild -version 2>/dev/null | awk '/Build version/{print $3; exit}')
today=$(date +%F)

count=0
for skill_dir in "$tmp_dir/export"/*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  if ! python3 - "$skill_dir" "$name" <<'PY'
from pathlib import Path
import re
import sys

directory, expected = Path(sys.argv[1]), sys.argv[2]
skill = directory / "SKILL.md"
raw = skill.read_bytes()
if not raw or len(raw) > 500_000 or b"\0" in raw:
    raise SystemExit(f"invalid SKILL.md size/content: {skill}")
text = raw.decode("utf-8")
match = re.match(r"\A---\n(.*?)\n---\n(.*)\Z", text, re.DOTALL)
if not match:
    raise SystemExit(f"invalid frontmatter: {skill}")
frontmatter, body = match.groups()
found = re.search(r"(?m)^name:\s*([^\n]+?)\s*$", frontmatter)
if not found or found.group(1).strip("\"' ") != expected:
    raise SystemExit(f"unexpected skill name in {skill}")
description = re.search(r"(?m)^description:\s*(.+?)\s*$", frontmatter)
if not description or not description.group(1).strip("\"' "):
    raise SystemExit(f"empty description in {skill}")
if not body.strip():
    raise SystemExit(f"empty body in {skill}")
for path in directory.rglob("*"):
    if path.is_symlink():
        raise SystemExit(f"symlink rejected: {path}")
    if path.is_file() and path.stat().st_size > 5_000_000:
        raise SystemExit(f"oversized support file: {path}")
PY
  then
    retain_or_fail "exported Apple skill failed validation: $name"
  fi
  cat > "$skill_dir/UPSTREAM" <<EOF
source: xcrun agent skills export (Apple Xcode built-in skills)
xcode_version: ${xcode_version:-unknown}
xcode_build: ${xcode_build:-unknown}
exported: $today
skill: $name
EOF
  count=$((count + 1))
done

[ "$count" -gt 0 ] || retain_or_fail 'Apple skill export produced no skills'

for skill_dir in "$tmp_dir/export"/*/; do
  name=$(basename "$skill_dir")
  for root in "${roots[@]}"; do
    sync_dir "$skill_dir" "$root/$name" || retain_or_fail "could not update $root/$name"
  done
done

# Mirror static iphone-duo outward from canonical copy.
for root in "${roots[@]}"; do
  [ "$root/iphone-duo" -ef "$canonical" ] 2>/dev/null && continue
  case "$root" in
    "$configs_dir/opencode-macos/skills") continue ;;
  esac
  sync_dir "$canonical" "$root/iphone-duo" || retain_or_fail "could not update $root/iphone-duo"
done

printf 'Apple agent skills updated (%d skills, Xcode %s %s)\n' "$count" "${xcode_version:-unknown}" "${xcode_build:-unknown}"

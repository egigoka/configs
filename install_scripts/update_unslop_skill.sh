#!/usr/bin/env bash
set -u

configs_dir=${1:-"$(cd "$(dirname "$0")/.." && pwd)"}
hermes_home=${HERMES_HOME:-"$HOME/.hermes"}
repo=https://github.com/cursor/plugins.git
raw_repo=https://raw.githubusercontent.com/cursor/plugins

destinations="
$configs_dir/opencode-macos/skills/unslop
$configs_dir/opencode-other/skills/unslop
$configs_dir/opencode-steamos/skills/unslop
$hermes_home/skills/unslop
"

all_installed() {
  while IFS= read -r destination; do
    [ -n "$destination" ] || continue
    [ -f "$destination/SKILL.md" ] || return 1
    [ -f "$destination/LICENSE" ] || return 1
    [ -f "$destination/UPSTREAM" ] || return 1
  done <<EOF
$destinations
EOF
}

retain_or_fail() {
  message=$1
  if all_installed; then
    printf '%s; retaining installed unslop copies\n' "$message" >&2
    exit 0
  fi
  printf '%s; no complete installed copy is available\n' "$message" >&2
  exit 1
}

if ! command -v curl >/dev/null 2>&1; then
  retain_or_fail 'curl not installed; cannot update unslop'
fi
if ! command -v git >/dev/null 2>&1; then
  retain_or_fail 'git not installed; cannot resolve the unslop upstream commit'
fi
if ! command -v python3 >/dev/null 2>&1; then
  retain_or_fail 'python3 not installed; cannot validate the unslop download'
fi

ref=$(git ls-remote "$repo" refs/heads/main 2>/dev/null | cut -f1)
case "$ref" in
  ''|*[!0-9a-f]*) retain_or_fail 'Could not resolve cursor/plugins main to an exact commit' ;;
esac
if [ "${#ref}" -ne 40 ]; then
  retain_or_fail 'Could not resolve cursor/plugins main to an exact commit'
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/unslop-skill.XXXXXX") || retain_or_fail 'Could not create an unslop staging directory'
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

curl_args=(
  --fail
  --silent
  --show-error
  --location
  --proto '=https'
  --tlsv1.2
  --connect-timeout 10
  --max-time 60
  --retry 3
  --retry-delay 1
  --retry-max-time 90
)

if ! curl "${curl_args[@]}" \
  "$raw_repo/$ref/pstack/skills/unslop/SKILL.md" \
  --output "$tmp_dir/SKILL.md"; then
  retain_or_fail "Could not download unslop SKILL.md at $ref"
fi
if ! curl "${curl_args[@]}" \
  "$raw_repo/$ref/pstack/LICENSE" \
  --output "$tmp_dir/LICENSE"; then
  retain_or_fail "Could not download the pstack license at $ref"
fi

if ! python3 - "$tmp_dir/SKILL.md" "$tmp_dir/LICENSE" <<'PY'
from pathlib import Path
import re
import sys

skill_path = Path(sys.argv[1])
license_path = Path(sys.argv[2])

for path in (skill_path, license_path):
    raw = path.read_bytes()
    if not raw or len(raw) > 100_000:
        raise SystemExit(f"invalid size: {path.name}")
    if b"\0" in raw:
        raise SystemExit(f"contains NUL bytes: {path.name}")
    try:
        raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise SystemExit(f"not UTF-8: {path.name}: {exc}")

text = skill_path.read_text(encoding="utf-8")
match = re.match(r"\A---\n(.*?)\n---\n(.*)\Z", text, re.DOTALL)
if not match:
    raise SystemExit("SKILL.md lacks complete YAML frontmatter")
frontmatter, body = match.groups()
if not re.search(r"(?m)^name:\s*unslop\s*$", frontmatter):
    raise SystemExit("SKILL.md name is not unslop")
description = re.search(r"(?m)^description:\s*(.+?)\s*$", frontmatter)
if not description or not description.group(1).strip('"\' '):
    raise SystemExit("SKILL.md description is empty")
if not body.strip():
    raise SystemExit("SKILL.md body is empty")
if "MIT License" not in license_path.read_text(encoding="utf-8"):
    raise SystemExit("LICENSE does not contain the MIT license notice")
PY
then
  retain_or_fail "Downloaded unslop files failed validation at $ref"
fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

skill_sha=$(sha256_file "$tmp_dir/SKILL.md") || retain_or_fail 'Could not hash unslop SKILL.md'
license_sha=$(sha256_file "$tmp_dir/LICENSE") || retain_or_fail 'Could not hash the pstack license'
cat > "$tmp_dir/UPSTREAM" <<EOF
source: https://github.com/cursor/plugins/tree/main/pstack/skills/unslop
repository: $repo
commit: $ref
skill_path: pstack/skills/unslop/SKILL.md
skill_sha256: $skill_sha
license_path: pstack/LICENSE
license_sha256: $license_sha
EOF

sync_file() {
  src=$1
  dst=$2
  mode=$3
  parent=$(dirname "$dst")
  mkdir -p "$parent" || return 1
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    return 0
  fi
  staged=$(mktemp "$parent/.unslop.$(basename "$dst").XXXXXX") || return 1
  if ! install -m "$mode" "$src" "$staged"; then
    rm -f "$staged"
    return 1
  fi
  mv -f "$staged" "$dst"
}

while IFS= read -r destination; do
  [ -n "$destination" ] || continue
  sync_file "$tmp_dir/LICENSE" "$destination/LICENSE" 0644 || retain_or_fail "Could not update $destination/LICENSE"
  sync_file "$tmp_dir/UPSTREAM" "$destination/UPSTREAM" 0644 || retain_or_fail "Could not update $destination/UPSTREAM"
  sync_file "$tmp_dir/SKILL.md" "$destination/SKILL.md" 0644 || retain_or_fail "Could not update $destination/SKILL.md"
  printf 'unslop updated -> %s\n' "$destination"
done <<EOF
$destinations
EOF

#!/usr/bin/env bash
set -u

configs_dir=${1:-"$(cd "$(dirname "$0")/.." && pwd)"}
hermes_home=${HERMES_HOME:-"$HOME/.hermes"}
porter="$configs_dir/install_scripts/port_selected_agent_skills.py"
matt_repo=https://github.com/mattpocock/skills.git
pstack_repo=https://github.com/cursor/plugins.git

matt_names=(
  code-review
  codebase-design
  domain-modeling
  improve-codebase-architecture
  resolving-merge-conflicts
  wizard
  writing-for-agents
  grilling
)
pstack_names=(
  blast-radius
  technical-writing
  typescript-best-practices
  show-me-your-work
  principle-type-system-discipline
  principle-boundary-discipline
  principle-encode-lessons-in-structure
)
roots=(
  "$configs_dir/opencode-macos/skills"
  "$configs_dir/opencode-other/skills"
  "$configs_dir/opencode-steamos/skills"
  "$hermes_home/skills"
)

all_installed() {
  local root name
  for root in "${roots[@]}"; do
    for name in "${matt_names[@]}" "${pstack_names[@]}"; do
      [ -s "$root/$name/SKILL.md" ] || return 1
      [ -s "$root/$name/LICENSE" ] || return 1
      [ -s "$root/$name/UPSTREAM" ] || return 1
    done
  done
  return 0
}

read_field() {
  local file=$1 field=$2 line prefix
  prefix="$field: "
  while IFS= read -r line; do
    case "$line" in
      "$prefix"*) printf '%s\n' "${line#"$prefix"}"; return 0 ;;
    esac
  done < "$file"
  return 1
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d ' ' -f1
  else
    return 1
  fi
}

all_current() {
  local matt_ref=$1 pstack_ref=$2 porter_ref=$3 root name actual
  all_installed || return 1
  for root in "${roots[@]}"; do
    for name in "${matt_names[@]}"; do
      actual=$(read_field "$root/$name/UPSTREAM" commit) || return 1
      [ "$actual" = "$matt_ref" ] || return 1
      actual=$(read_field "$root/$name/UPSTREAM" porter_sha256) || return 1
      [ "$actual" = "$porter_ref" ] || return 1
    done
    for name in "${pstack_names[@]}"; do
      actual=$(read_field "$root/$name/UPSTREAM" commit) || return 1
      [ "$actual" = "$pstack_ref" ] || return 1
      actual=$(read_field "$root/$name/UPSTREAM" porter_sha256) || return 1
      [ "$actual" = "$porter_ref" ] || return 1
    done
  done
  return 0
}

retain_or_fail() {
  local reason=$1
  if all_installed; then
    printf 'Warning: %s; retaining installed selected skills\n' "$reason" >&2
    exit 0
  fi
  printf 'Error: %s and one or more selected skills are missing\n' "$reason" >&2
  exit 1
}

resolve_ref() {
  local repo=$1 ref
  ref=$(git ls-remote "$repo" refs/heads/main 2>/dev/null | cut -f1)
  case "$ref" in
    ''|*[!0-9a-f]*) return 1 ;;
  esac
  [ "${#ref}" -eq 40 ] || return 1
  printf '%s\n' "$ref"
}

checkout_exact() {
  local repo=$1 ref=$2 destination=$3
  shift 3
  git init -q "$destination" || return 1
  git -C "$destination" remote add origin "$repo" || return 1
  git -C "$destination" sparse-checkout init --cone >/dev/null 2>&1 || return 1
  git -C "$destination" sparse-checkout set "$@" >/dev/null 2>&1 || return 1
  git -C "$destination" fetch -q --depth 1 origin "$ref" || return 1
  git -C "$destination" checkout -q --detach FETCH_HEAD || return 1
  [ "$(git -C "$destination" rev-parse HEAD 2>/dev/null)" = "$ref" ] || return 1
}

command -v git >/dev/null 2>&1 || retain_or_fail 'git is unavailable'
command -v python3 >/dev/null 2>&1 || retain_or_fail 'python3 is unavailable'
[ -s "$porter" ] || retain_or_fail "porting helper is missing at $porter"
porter_ref=$(hash_file "$porter") || retain_or_fail 'no SHA-256 utility is available'

matt_ref=$(resolve_ref "$matt_repo") || retain_or_fail 'could not resolve mattpocock/skills main to an exact commit'
pstack_ref=$(resolve_ref "$pstack_repo") || retain_or_fail 'could not resolve cursor/plugins main to an exact commit'

if all_current "$matt_ref" "$pstack_ref" "$porter_ref"; then
  printf 'Selected agent skills already current at matt=%s pstack=%s\n' "$matt_ref" "$pstack_ref"
  exit 0
fi

temporary=$(mktemp -d "${TMPDIR:-/tmp}/selected-agent-skills.XXXXXX") || retain_or_fail 'could not create temporary directory'
cleanup() { rm -rf "$temporary"; }
trap cleanup EXIT INT TERM

matt_checkout="$temporary/matt"
pstack_checkout="$temporary/pstack"

checkout_exact "$matt_repo" "$matt_ref" "$matt_checkout" \
  skills/engineering/code-review \
  skills/engineering/codebase-design \
  skills/engineering/domain-modeling \
  skills/engineering/improve-codebase-architecture \
  skills/engineering/resolving-merge-conflicts \
  skills/engineering/wizard \
  skills/productivity/writing-for-agents \
  skills/productivity/grilling \
  || retain_or_fail 'could not fetch the selected mattpocock/skills directories'

checkout_exact "$pstack_repo" "$pstack_ref" "$pstack_checkout" \
  pstack/skills/blast-radius \
  pstack/skills/technical-writing \
  pstack/skills/typescript-best-practices \
  pstack/skills/show-me-your-work \
  pstack/skills/principle-type-system-discipline \
  pstack/skills/principle-boundary-discipline \
  pstack/skills/principle-encode-lessons-in-structure \
  || retain_or_fail 'could not fetch the selected pstack skill directories'

python3 "$porter" \
  --matt-root "$matt_checkout" \
  --matt-ref "$matt_ref" \
  --pstack-root "$pstack_checkout" \
  --pstack-ref "$pstack_ref" \
  --configs-dir "$configs_dir" \
  --hermes-home "$hermes_home" \
  || retain_or_fail 'selected skill validation, portability transforms, or installation failed'

printf 'Selected agent skills updated at matt=%s pstack=%s\n' "$matt_ref" "$pstack_ref"

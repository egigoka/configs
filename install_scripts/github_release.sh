#!/usr/bin/env bash

# Prefer gh's existing credentials without copying tokens into curl arguments.
github_api_get() {
  local endpoint=$1 response
  if command -v gh >/dev/null 2>&1 && response=$(gh api "$endpoint" 2>/dev/null); then
    printf '%s\n' "$response"
    return 0
  fi
  curl --fail --silent --show-error --location --connect-timeout 10 --max-time 30 \
    "https://api.github.com/$endpoint"
}

# An optional prefix selects a component's release in a multi-component repo.
github_release_tag() {
  local repository=$1 prefix=${2:-} endpoint response
  endpoint="repos/$repository/releases/latest"
  [ -z "$prefix" ] || endpoint="repos/$repository/releases?per_page=50"
  if ! response=$(github_api_get "$endpoint"); then
    printf 'Could not fetch GitHub releases for %s; check gh authentication or API quota\n' "$repository" >&2
    return 1
  fi
  # Parse only successful responses, and report malformed metadata without a
  # Python traceback. Component releases can be marked as prereleases upstream.
  printf '%s' "$response" | python3 -c '
import json, re, sys
repository, prefix = sys.argv[1:]
try:
    data = json.load(sys.stdin)
    releases = data if prefix else [data]
    if not isinstance(releases, list):
        raise ValueError("expected release list")
    tag = next(item["tag_name"] for item in releases
               if isinstance(item, dict) and isinstance(item.get("tag_name"), str)
               and item["tag_name"].startswith(prefix))
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", tag):
        raise ValueError("invalid release tag")
except (ValueError, StopIteration):
    sys.exit(f"Could not resolve release tag for {repository}: invalid or missing release metadata")
print(tag)
' "$repository" "$prefix"
}

#!/usr/bin/env bash

# Reuse successful builds of clean, installer-managed Node checkouts.
build_node_checkout() (
  local checkout=$1 recipe=$2 context=${3:-}
  local revision runtime npm_version cache fingerprint cached=''
  cd "$checkout" || return

  revision=$(git rev-parse HEAD) || return
  runtime=$(node -p 'JSON.stringify([process.version, process.platform, process.arch])') || return
  npm_version=$(npm --version) || return
  cache=$(git rev-parse --git-path configs-node-build) || return
  fingerprint=$(printf '%s\n' "$revision" "$runtime" "$npm_version" \
    "${NODE_ENV:-}" "$context" "$(declare -f "$recipe")")

  if [ -d node_modules ] && [ -f dist/index.js ] && [ -f "$cache" ]; then
    cached=$(<"$cache")
    if [ "$cached" = "$fingerprint" ]; then
      printf '%s build is current, skipping\n' "${checkout##*/}"
      return 0
    fi
  fi

  # A failed or interrupted rebuild must never reuse an earlier success marker.
  rm -f -- "$cache" || return
  "$recipe" || return
  if [ ! -f dist/index.js ]; then
    printf '%s build did not produce %s/dist/index.js\n' "${checkout##*/}" "$checkout" >&2
    return 1
  fi
  printf '%s\n' "$fingerprint" >"$cache"
)

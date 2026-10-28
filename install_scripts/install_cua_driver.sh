#!/bin/bash
set -euo pipefail

# Installs the latest cua-driver-rs release. Pin via CUA_DRIVER_VERSION=x.y.z.
resolve_version() {
  if [ -n "${CUA_DRIVER_VERSION:-}" ]; then printf '%s\n' "$CUA_DRIVER_VERSION"; return 0; fi
  curl -fsSL "https://api.github.com/repos/trycua/cua/releases?per_page=50" |
    python3 -c 'import json,sys; print(next(r["tag_name"] for r in json.load(sys.stdin) if r["tag_name"].startswith("cua-driver-rs-v")))' |
    sed 's/^cua-driver-rs-v//'
}

version=$(resolve_version)
[ -n "$version" ] || { printf 'Could not resolve cua-driver-rs version\n' >&2; exit 1; }
tag="cua-driver-rs-v$version"
base_url="https://github.com/trycua/cua/releases/download/$tag"

if [ "${1:-}" = --version ]; then
  printf '%s\n' "$version"
  exit 0
fi

os=$(uname -s)
arch=$(uname -m)
case "$os-$arch" in
  Darwin-arm64|Darwin-aarch64|Darwin-x86_64)
    archive="cua-driver-rs-$version-darwin-universal.tar.gz"
    target="darwin-universal"
    ;;
  Linux-x86_64|Linux-amd64)
    archive="cua-driver-rs-$version-linux-x86_64-binary.tar.gz"
    target="x86_64-unknown-linux-gnu"
    ;;
  Linux-arm64|Linux-aarch64)
    archive="cua-driver-rs-$version-linux-arm64-binary.tar.gz"
    target="aarch64-unknown-linux-gnu"
    ;;
  *)
    printf 'Unsupported cua-driver platform: %s/%s\n' "$os" "$arch" >&2
    exit 1
    ;;
esac

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

curl --fail --location --silent --show-error \
  "$base_url/$archive" -o "$tmp_dir/$archive"
curl --fail --location --silent --show-error \
  "$base_url/SHA256SUMS" -o "$tmp_dir/SHA256SUMS"

expected=$(grep -F "  $archive" "$tmp_dir/SHA256SUMS" | cut -d' ' -f1)
[ -n "$expected" ] || { printf 'No checksum for %s in %s/SHA256SUMS\n' "$archive" "$tag" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$tmp_dir/$archive" | cut -d' ' -f1)
else
  actual=$(shasum -a 256 "$tmp_dir/$archive" | cut -d' ' -f1)
fi
if [ "$actual" != "$expected" ]; then
  printf 'cua-driver checksum mismatch: expected %s, got %s\n' "$expected" "$actual" >&2
  exit 1
fi

tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
mkdir -p "$HOME/.local/bin"

if [ "$os" = Darwin ]; then
  source_dir="$tmp_dir/cua-driver-rs-$version-$target"
  app_source="$source_dir/CuaDriver.app"
  app_dest=/Applications/CuaDriver.app
  if [ ! -d "$app_source" ]; then
    printf 'CuaDriver.app missing from verified archive\n' >&2
    exit 1
  fi
  if [ ! -w /Applications ]; then
    printf '/Applications is not writable; cannot install CuaDriver.app\n' >&2
    exit 1
  fi
  rm -rf "$app_dest"
  ditto "$app_source" "$app_dest"
  ln -sf "$app_dest/Contents/MacOS/cua-driver" "$HOME/.local/bin/cua-driver"
else
  release_dir="$HOME/.cua-driver/packages/releases/$version-$target"
  current="$HOME/.cua-driver/packages/current"
  mkdir -p "$release_dir"
  install -m 0755 "$tmp_dir/cua-driver" "$release_dir/cua-driver"
  ln -sfn "releases/$version-$target" "$current"
  ln -sf "$current/cua-driver" "$HOME/.local/bin/cua-driver"
fi

"$HOME/.local/bin/cua-driver" --version

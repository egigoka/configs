#!/bin/bash
set -euo pipefail

version=0.7.1
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
    checksum="3bd574f162bf293089ca9d28653c8ac2b869f1577a15b92ff95203c6279a08a1"
    target="darwin-universal"
    ;;
  Linux-x86_64|Linux-amd64)
    archive="cua-driver-rs-$version-linux-x86_64-binary.tar.gz"
    checksum="157dd2d037374250aeca36a0250149854f80f2a62d954e58e89f23d0256fa2eb"
    target="x86_64-unknown-linux-gnu"
    ;;
  Linux-arm64|Linux-aarch64)
    archive="cua-driver-rs-$version-linux-arm64-binary.tar.gz"
    checksum="1ce73e6f128a7857e9695f55862219d515021fc95027d7de1e7d7706aa4e68e0"
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

if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$tmp_dir/$archive" | cut -d' ' -f1)
else
  actual=$(shasum -a 256 "$tmp_dir/$archive" | cut -d' ' -f1)
fi
if [ "$actual" != "$checksum" ]; then
  printf 'cua-driver checksum mismatch: expected %s, got %s\n' "$checksum" "$actual" >&2
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

#!/usr/bin/env bash
set -euo pipefail

installer_url="https://github.com/egigoka/opencode/releases/latest/download/install.sh"
installer=$(mktemp -t opencode-install.XXXXXX)
trap 'rm -f "$installer"' EXIT

curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  "$installer_url" -o "$installer"
bash "$installer"

install_dir="${OPENCODE_INSTALL_DIR:-${XDG_BIN_DIR:-$HOME/.local/bin}}"
binary="$install_dir/opencode"
version=$("$binary" --version)
version=${version##* }
version=${version#v}
case "$version" in
  2.*) ;;
  *) printf 'Expected OpenCode 2, got %s\n' "$version" >&2; exit 1 ;;
esac
"$binary" run --help >/dev/null

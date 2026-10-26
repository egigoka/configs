#!/usr/bin/env bash
set -euo pipefail

installer_url="https://opencode.ai/v2/install"
installer=$(mktemp -t opencode-install.XXXXXX)
trap 'rm -f "$installer"' EXIT

curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  "$installer_url" -o "$installer"
bash "$installer" --no-modify-path

binary="$HOME/.opencode/bin/opencode"
version=$("$binary" --version)
version=${version##* }
version=${version#v}
case "$version" in
  2.*) ;;
  *) printf 'Expected OpenCode 2, got %s\n' "$version" >&2; exit 1 ;;
esac
"$binary" run --help >/dev/null

install_dir="${OPENCODE_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$install_dir"
if [ "$install_dir" != "$HOME/.opencode/bin" ]; then
  ln -sfn "$binary" "$install_dir/opencode"
  ln -sfn "$HOME/.opencode/bin/opencode2" "$install_dir/opencode2"
fi

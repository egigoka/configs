#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=install_scripts/github_release.sh
source "$(dirname "${BASH_SOURCE[0]}")/github_release.sh"

install_dir="${OPENCODE_INSTALL_DIR:-${XDG_BIN_DIR:-$HOME/.local/bin}}"
binary="$install_dir/opencode"
if [ -x "$binary" ] && latest=$(github_release_tag egigoka/opencode); then
  installed_version=$("$binary" --version 2>/dev/null || true)
  installed_version=${installed_version##* }
  installed_version=${installed_version#v}
  case "$installed_version" in
    2.*)
      if [ "$installed_version" = "${latest#v}" ] && "$binary" run --help >/dev/null 2>&1; then
        printf 'OpenCode %s already installed, skipping\n' "$installed_version"
        exit 0
      fi
      ;;
  esac
fi

installer_url="https://github.com/egigoka/opencode/releases/latest/download/install.sh"
installer=$(mktemp -t opencode-install.XXXXXX)
trap 'rm -f "$installer"' EXIT

curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  "$installer_url" -o "$installer"
bash "$installer"

version=$("$binary" --version)
version=${version##* }
version=${version#v}
case "$version" in
  2.*) ;;
  *) printf 'Expected OpenCode 2, got %s\n' "$version" >&2; exit 1 ;;
esac
"$binary" run --help >/dev/null

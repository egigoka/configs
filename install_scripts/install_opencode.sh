#!/usr/bin/env bash
set -euo pipefail

installer_url="https://raw.githubusercontent.com/egigoka/opencode/dev/install.sh"
installer=$(mktemp -t opencode-install.XXXXXX)
trap 'rm -f "$installer"' EXIT

curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  "$installer_url" -o "$installer"
OPENCODE_INSTALL_DIR="${OPENCODE_INSTALL_DIR:-$HOME/.local/bin}" bash "$installer"

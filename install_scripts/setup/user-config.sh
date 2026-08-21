#!/usr/bin/env bash

USER_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install_scripts/setup/user/cli.sh
source "$USER_SETUP_DIR/user/cli.sh"
# shellcheck source=install_scripts/setup/user/macos.sh
source "$USER_SETUP_DIR/user/macos.sh"
# shellcheck source=install_scripts/setup/user/desktop.sh
source "$USER_SETUP_DIR/user/desktop.sh"
# shellcheck source=install_scripts/setup/user/git.sh
source "$USER_SETUP_DIR/user/git.sh"
unset USER_SETUP_DIR

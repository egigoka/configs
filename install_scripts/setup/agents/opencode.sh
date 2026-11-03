#!/usr/bin/env bash

# OpenCode, Kilo, Graphify, mobile tooling, and generated skill patches.

# shellcheck source=install_scripts/github_release.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../github_release.sh"
# shellcheck source=install_scripts/node_build.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../node_build.sh"
# shellcheck source=install_scripts/npm_packages.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../npm_packages.sh"

configure_rocketsim_agent() {
  [ "$(uname -s)" = Darwin ] || return 0

  local app=/Applications/RocketSim.app
  local cli="$app/Contents/Helpers/rocketsim"
  local skill="$app/Contents/Resources/Agent-Skill/rocketsim"

  if [ ! -d "$app" ]; then
    printf 'RocketSim not installed; get App Store app 1504940162 to enable iOS Simulator automation\n' >&2
    return 0
  fi
  if [ ! -x "$cli" ] || [ ! -f "$skill/SKILL.md" ]; then
    printf 'RocketSim CLI or Agent Skill missing from %s\n' "$app" >&2
    return 1
  fi

  install_link "$cli" "$HOME/.local/bin/rocketsim"
  install_link "$skill" "$HOME/.agents/skills/rocketsim"
}

configure_graphify_agent() {
  if ! command -v uv >/dev/null 2>&1; then
    printf 'uv not installed; skipping Graphify installation\n' >&2
    return 0
  fi

  local tag version wheel graphify installed_version=''
  export PATH="$HOME/.local/bin:$PATH"
  graphify=$(command -v graphify 2>/dev/null || printf '%s' "$HOME/.local/bin/graphify")
  if [ -x "$graphify" ]; then
    installed_version=$("$graphify" --version 2>/dev/null) || installed_version=
  fi
  if tag=$(github_release_tag Graphify-Labs/graphify); then
    version=${tag#v}
    wheel="https://github.com/Graphify-Labs/graphify/releases/download/$tag/graphifyy-$version-py3-none-any.whl"
    if [ "$installed_version" != "graphify $version" ]; then
      # Native tree-sitter wheels require the standard CPython ABI.
      uv tool install --force --python cpython@3.13 "graphifyy @ $wheel" || return
      graphify="$HOME/.local/bin/graphify"
    fi
  elif [ -n "$installed_version" ]; then
    printf 'Warning: could not check Graphify updates; keeping %s\n' "$installed_version" >&2
  else
    printf 'Graphify is not installed and its release could not be resolved\n' >&2
    return 1
  fi

  "$graphify" install --platform agents || return
  "$graphify" install --platform hermes
}

install_macos_android_tools() {
  [ "$(uname -s)" = Darwin ] || return 0

  install_if_missing android-studio
  install_if_missing android-platform-tools

  if command -v adb >/dev/null 2>&1; then
    printf 'Android Studio tooling ready; Mobile MCP uses ADB for Android devices\n'
  else
    printf 'adb not found; Android Mobile MCP device control will be unavailable\n' >&2
  fi
}

install_macos_mobile_mcp_tools() {
  [ "$(uname -s)" = Darwin ] || return 0

  if command -v xcrun >/dev/null 2>&1 && xcrun --find mcpbridge >/dev/null 2>&1; then
    printf 'Xcode MCP ready; enable Xcode > Settings > Intelligence > Allow external agents to use Xcode tools\n'
  else
    printf 'Xcode 26.3+ with mcpbridge not found; Xcode MCP will be unavailable\n' >&2
  fi

  install_latest_npm_packages "@mobilenext/mobile-mcp" "xcodebuildmcp"
}

configure_caveman_session_models() {
  python3 "$SETUP_DIR/agents/configure_caveman.py" "$1"
}

build_opencode_codex_auth_fork() {
  npm ci --no-audit --no-fund && npm run build
}

install_opencode_codex_auth_fork() {
  local repo_url=https://github.com/egigoka/opencode-codex-auth.git
  local checkout="$HOME/.local/share/opencode-codex-auth"
  local origin_url

  if [ -e "$checkout" ] && [ ! -d "$checkout/.git" ]; then
    printf 'Refusing to replace non-git path: %s\n' "$checkout" >&2
    return 1
  fi

  if [ ! -d "$checkout/.git" ]; then
    mkdir -p -- "$(dirname -- "$checkout")" || return
    git clone --filter=blob:none --single-branch --branch main "$repo_url" "$checkout" || return
  else
    origin_url=$(git -C "$checkout" remote get-url origin 2>/dev/null) || return
    case "$origin_url" in
      "$repo_url"|git@github.com:egigoka/opencode-codex-auth.git) ;;
      *)
        printf 'Unexpected opencode-codex-auth origin at %s: %s\n' "$checkout" "$origin_url" >&2
        return 1
        ;;
    esac
    git -C "$checkout" fetch --prune origin main || return
  fi

  git -C "$checkout" checkout --detach --force origin/main || return
  build_node_checkout "$checkout" build_opencode_codex_auth_fork
}

prepare_opencode_tools() {
  configure_rocketsim_agent

  install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/opencode"
  install_link "${OPENCODE_CONFIG_DIR/opencode-/kilo-}" "$HOME/.config/kilo"
  install_link "$HOME/.local/share/opencode/auth.json" "$HOME/.local/share/kilo/auth.json"

  export PATH="$HOME/.local/bin:$PATH"

  # System npm prefix (e.g. /usr/local) is often not user-writable.
  if ! [ -w "$(npm root -g 2>/dev/null || printf '/nonexistent')" ]; then
    npm config set prefix "$HOME/.local"
  fi
}

install_opencode_tools() {
  bash "$CONFIGS_DIR/install_scripts/install_opencode.sh" || return

  local kilo_have kilo_latest
  kilo_have=$(kilo --version 2>/dev/null || true)
  if [ -z "$kilo_have" ]; then
    npm install -g "@kilocode/cli@latest" || return
  else
    kilo_latest=$(npm view "@kilocode/cli" version 2>/dev/null || true)
    if [ -n "$kilo_latest" ] && [ "$kilo_have" != "$kilo_latest" ]; then
      npm install -g "@kilocode/cli@latest" || return
    fi
  fi

  if [ "$(uname -s)" = Darwin ] && [ -x /Applications/VSCodium.app/Contents/Resources/app/bin/codium ]; then
    local kilo_extension_platform kilo_ext_api kilo_extension_metadata kilo_extension_version kilo_extension_url temp_dir vsix
    case "$(uname -m)" in
      arm64) kilo_extension_platform=darwin-arm64 ;;
      x86_64) kilo_extension_platform=darwin-x64 ;;
    esac

    kilo_ext_api=$(curl -fsSL https://open-vsx.org/api/kilocode/kilo-code) || return
    kilo_extension_metadata=$(printf '%s' "$kilo_ext_api" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["version"]); print(data["downloads"][sys.argv[1]])' "$kilo_extension_platform") || return
    kilo_extension_version=${kilo_extension_metadata%%$'\n'*}
    kilo_extension_url=${kilo_extension_metadata#*$'\n'}

    if [ -n "${kilo_extension_platform:-}" ] && \
      ! /Applications/VSCodium.app/Contents/Resources/app/bin/codium --list-extensions --show-versions | \
        grep -Fx "kilocode.kilo-code@$kilo_extension_version" >/dev/null; then
      temp_dir=$(mktemp -d -t kilo-code) || return
      vsix="$temp_dir/kilo-code.vsix"
      if curl --fail --location "$kilo_extension_url" --output "$vsix"; then
        /Applications/VSCodium.app/Contents/Resources/app/bin/codium --install-extension "$vsix" --force
      fi
      rm -rf -- "$temp_dir"
    fi
  fi

  install_macos_android_tools
  install_macos_mobile_mcp_tools

  # Claude Code subscription integration remains disabled. Restore from either
  # config's claude-integration.json.bak before uncommenting this command.
  # npm install -g opencode-with-claude
}

install_opencode_builds() {
  # NOTE: opencode-openai-multi-auth was replaced by egigoka/opencode-codex-auth
  # (v2.x): both register provider "openai", so only one auth plugin may be
  # enabled. Codex-auth won: native Codex OAuth with multi-account rotation.
  install_opencode_codex_auth_fork || return
  bash "$CONFIGS_DIR/install_scripts/install_opencode_plugins.sh"
}

install_cua_driver() {
  local installer="$CONFIGS_DIR/install_scripts/install_cua_driver.sh"
  local version driver installed_version=''
  driver=$(command -v cua-driver 2>/dev/null || printf '%s' "$HOME/.local/bin/cua-driver")
  if [ -x "$driver" ]; then
    installed_version=$("$driver" --version 2>/dev/null) || installed_version=
  fi
  if ! version=$(bash "$installer" --version); then
    if [ -n "$installed_version" ]; then
      printf 'Warning: could not check CUA driver updates; keeping %s\n' "$installed_version" >&2
      return 0
    fi
    printf 'CUA driver is not installed and its release could not be resolved\n' >&2
    return 1
  fi
  if [ "$installed_version" != "cua-driver $version" ]; then
    CUA_DRIVER_VERSION="$version" bash "$installer"
  fi
}

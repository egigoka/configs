#!/usr/bin/env bash

# OpenCode, Kilo, Graphify, mobile tooling, and generated skill patches.

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
  local version=0.9.20
  local wheel="https://github.com/Graphify-Labs/graphify/releases/download/v$version/graphifyy-$version-py3-none-any.whl"
  local checksum=2e06d20ecfcd971812e73f26b7d7aef45d6cc2057139e33c66d15ba393e5319e
  local graphify

  if ! command -v uv >/dev/null 2>&1; then
    printf 'uv not installed; skipping Graphify installation\n' >&2
    return 0
  fi

  export PATH="$HOME/.local/bin:$PATH"
  graphify=$(command -v graphify 2>/dev/null || printf '%s' "$HOME/.local/bin/graphify")
  if [ ! -x "$graphify" ] || [ "$("$graphify" --version 2>/dev/null)" != "graphify $version" ]; then
    uv tool install --force "graphifyy @ $wheel#sha256=$checksum" || return
    graphify="$HOME/.local/bin/graphify"
  fi

  "$graphify" install --platform agents
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

  npm install -g \
    "@mobilenext/mobile-mcp@latest" \
    "xcodebuildmcp@latest"
}

configure_caveman_session_models() {
  python3 "$SETUP_DIR/agents/configure_caveman.py" "$1"
}

install_opencode_tools() {
  configure_rocketsim_agent
  configure_graphify_agent

  install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/opencode"
  install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/kilo"
  install_link "$HOME/.local/share/opencode/auth.json" "$HOME/.local/share/kilo/auth.json"

  bash "$CONFIGS_DIR/install_scripts/install_opencode.sh"
  export PATH="$HOME/.local/bin:$PATH"

  if ! command -v opencode >/dev/null 2>&1; then
    npm i -g opencode-ai@latest
  fi

  local kilo_cli_version=7.4.11
  if ! command -v kilo >/dev/null 2>&1 || [ "$(kilo --version 2>/dev/null)" != "$kilo_cli_version" ]; then
    npm install -g "@kilocode/cli@$kilo_cli_version"
  fi

  if [ "$(uname -s)" = Darwin ] && [ -x /Applications/VSCodium.app/Contents/Resources/app/bin/codium ]; then
    local kilo_extension_version=7.4.13
    local kilo_extension_platform kilo_extension_sha256 kilo_extension_url temp_dir vsix
    case "$(uname -m)" in
      arm64)
        kilo_extension_platform=darwin-arm64
        kilo_extension_sha256=13009b6267d541e6e5c0025dd86aa76436b64f742a7516fd74055b590987ec89
        ;;
      x86_64)
        kilo_extension_platform=darwin-x64
        kilo_extension_sha256=9bb27b6668dbe10e1fbfb8975bb195bd05251976298a39454f5358a3f704ac12
        ;;
    esac

    if [ -n "${kilo_extension_platform:-}" ] && \
      ! /Applications/VSCodium.app/Contents/Resources/app/bin/codium --list-extensions --show-versions | \
        grep -qFx "kilocode.kilo-code@$kilo_extension_version"; then
      kilo_extension_url="https://open-vsx.org/api/kilocode/kilo-code/$kilo_extension_platform/$kilo_extension_version/file/kilocode.kilo-code-$kilo_extension_version@$kilo_extension_platform.vsix"
      temp_dir=$(mktemp -d -t kilo-code) || return
      vsix="$temp_dir/kilo-code.vsix"
      if curl --fail --location "$kilo_extension_url" --output "$vsix" && \
        printf '%s  %s\n' "$kilo_extension_sha256" "$vsix" | shasum -a 256 --check; then
        /Applications/VSCodium.app/Contents/Resources/app/bin/codium --install-extension "$vsix" --force
      fi
      rm -rf -- "$temp_dir"
    fi
  fi

  install_macos_android_tools
  install_macos_mobile_mcp_tools

  local cua_driver_installer="$CONFIGS_DIR/install_scripts/install_cua_driver.sh"
  local cua_driver_version
  local cua_driver
  cua_driver_version=$(bash "$cua_driver_installer" --version)
  cua_driver=$(command -v cua-driver 2>/dev/null || printf '%s' "$HOME/.local/bin/cua-driver")
  if [ ! -x "$cua_driver" ] || [ "$("$cua_driver" --version 2>/dev/null)" != "cua-driver $cua_driver_version" ]; then
    bash "$cua_driver_installer"
  fi
  export PATH="$HOME/.local/bin:$PATH"

  # Claude Code subscription integration remains disabled. Restore from either
  # config's claude-integration.json.bak before uncommenting this command.
  # npm install -g opencode-with-claude

  npm install -g opencode-claude-memory@1.7.2
  local opencode_memory
  opencode_memory=$(command -v opencode-memory 2>/dev/null || printf '%s' "$(npm prefix -g)/bin/opencode-memory")
  if [ -x "$opencode_memory" ]; then
    "$opencode_memory" install
  fi

}

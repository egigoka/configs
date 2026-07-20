#!/bin/bash

# get product name
product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

# install command
CONFIGS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$CONFIGS_DIR/install_scripts/epm.sh"

if [ "$(uname -s)" = Darwin ]; then
  OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-macos"
else
  OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-other"
fi

USER="$(whoami)"

# UTF-8 locale for this script and every child it spawns. Nix-built Qt tools
# (kwriteconfig6 et al.) warn "Detected locale C ... ANSI_X3.4-1968" and fall
# back to C under a non-UTF-8 locale. IMPORTANT: the Nix glibc only ships
# C.UTF-8 -- en_US.UTF-8 is listed by the *system* `locale -a` but is NOT
# loadable by Nix binaries (setlocale fails -> C). C.UTF-8 loads under both
# Nix and system glibc, so use it. LC_ALL overrides any inherited C category
# (fish's LC_COLLATE, KDE Formats' LC_TIME/PAPER/MEASUREMENT).
export LANG=C.UTF-8 LC_ALL=C.UTF-8
unset LC_COLLATE LC_CTYPE LC_TIME LC_PAPER LC_MEASUREMENT LC_NUMERIC LANGUAGE

pkg_installed() {
  local pkg=$1
  case "$(uname -s)" in
    Linux)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          rocky) rpm -q "$pkg" >/dev/null 2>&1 || command -v "$pkg" >/dev/null 2>&1 ;;
          arch) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
          debian|ubuntu|droidian) dpkg -s "$pkg" >/dev/null 2>&1 ;;
          opensuse-tumbleweed|opensuse-leap) rpm -q "$pkg" >/dev/null 2>&1 ;;
          alpine) apk info -e "$pkg" >/dev/null 2>&1 ;;
          nixos)
            grep -q -F "$pkg" /etc/nixos/configuration.nix /etc/nixos/packages.nix 2>/dev/null
            ;;
          *) return 1 ;;
        esac
      else
        return 1
      fi
      ;;
    Darwin)
      brew list --formula "$pkg" >/dev/null 2>&1 || brew list --cask "$pkg" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

install_if_missing() {
  local pkg
  for pkg in "$@"; do
    if pkg_installed "$pkg"; then
      echo "$pkg already installed, skipping"
    else
      install "$pkg"
    fi
  done
}

# if no package
install_autojump() {
  pwd=$PWD
  shell=$SHELL
  git clone https://github.com/wting/autojump.git "$CONFIGS_DIR/autojump"
  cd "$CONFIGS_DIR/autojump"
  export SHELL=/bin/zsh
  python3 "$CONFIGS_DIR/autojump/install.py"
  rm -rf "$CONFIGS_DIR/autojump"
  cd "$pwd"
  export SHELL=$shell
}

install_link() {
  if [ $# -ne 2 ]; then
    printf 'Usage: %s SRC DST\n' "${0##*/}" >&2
    return 1
  fi

  src=$1
  dst=$2

  parent=$(dirname -- "$dst")
  mkdir -p -- "$parent" || return

  dst="${dst%/}"  # strip slash at the end

  # already a correct symlink — nothing to do
  if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$src" ]; then
    return 0
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -e "$dst.preinstall" ]; then
      rm -rf "$dst"
    else
      mv -- "$dst" "$dst.preinstall" || return
    fi
  fi

  ln -s -- "$src" "$dst"
}

configure_codex_home() {
  local codex_home=$1
  local skill agent legacy_ultragoogle

  install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$codex_home/AGENTS.md"
  install_link "$CONFIGS_DIR/codex/codex.toml" "$codex_home/config.toml"

  legacy_ultragoogle="$codex_home/skills/ultragoogle"
  if [ -L "$legacy_ultragoogle" ] && [ "$(readlink -- "$legacy_ultragoogle")" = "$CONFIGS_DIR/opencode/skills/ultragoogle" ]; then
    rm -- "$legacy_ultragoogle"
  fi

  for skill in \
    caveman \
    caveman-commit \
    caveman-compress \
    caveman-help \
    caveman-review \
    frontend-design \
    swiftui-expert-skill \
    ultrabrowser
  do
    install_link "$OPENCODE_CONFIG_DIR/skills/$skill" "$codex_home/skills/$skill"
  done

  install_link "$CONFIGS_DIR/codex/skills/cavecrew" "$codex_home/skills/cavecrew"

  for agent in "$CONFIGS_DIR"/codex/agents/*.toml; do
    install_link "$agent" "$codex_home/agents/$(basename "$agent")"
  done
}

configure_codex() {
  local codex_home

  for codex_home in "$HOME/.codex" "$HOME/.codex-2" "$HOME/.codex-3"; do
    configure_codex_home "$codex_home"
  done
}

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

if [ "${1:-}" = "--codex-only" ]; then
  configure_codex
  exit 0
fi

install_opencode_tools() {
  configure_rocketsim_agent
  configure_graphify_agent

  install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/opencode"

  if ! command -v opencode >/dev/null 2>&1; then
    npm i -g opencode-ai@latest
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

  npx -y opencode-openai-multi-auth@5.0.6
}

install_usage_tui() {
  if ! command -v usage >/dev/null 2>&1; then
    uv tool install git+https://github.com/egigoka/usage
  fi
}

install_virtualfish() {
  if ! command -v vf >/dev/null 2>&1; then
    uv tool install virtualfish
  fi

  if command -v vf >/dev/null 2>&1; then
    vf install
  elif [ -x "$HOME/.local/bin/vf" ]; then
    "$HOME/.local/bin/vf" install
  else
    echo "vf not found; skipping virtualfish setup" >&2
  fi
}

install_usage() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "uv not found; skipping usage install" >&2
    return 0
  fi

  uv tool install --force --refresh "git+https://github.com/egigoka/usage.git@main"
}

# install some packages
case "$(uname -s)" in
  Linux)
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
      	rocky)
          ;;
        arch)
          ;;
        debian|ubuntu|droidian)
          ;;
        opensuse-tumbleweed|opensuse-leap)
          ;;
        alpine)
          install_if_missing git
          install_if_missing shadow # chsh
          install_if_missing ncurses # tput in omz
          install_if_missing tar # GNU tar (busybox tar lacks zstd)
          install_if_missing zstd
          ;;
        nixos)
          ;;
        steamos)
          # Packages handled below via Nix + home-manager (read-only root).
          ;;
        *)
         echo "Unknown Linux distribution"
         exit
          ;;
      esac
    else
      echo "Unknown Linux distribution"
      exit
    fi
    ;;
  Darwin)
    
    ;;
  *)
  	echo Unsupported OS
  	exit
    ;;
esac

is_nixos=false
is_steamos=false
if [ -f /etc/os-release ]; then
  . /etc/os-release
  [ "$ID" = "nixos" ] && is_nixos=true
  [ "$ID" = "steamos" ] && is_steamos=true
fi

# Source the nix profile into the current shell, if nix is installed.
source_nix() {
  if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
}

if [ "$is_steamos" = true ]; then

  source_nix
  if ! command -v nix >/dev/null 2>&1; then
    echo "Installing upstream Nix (steam-deck planner, store under /home/nix)..."
    nix_installer="$(mktemp)"
    curl --proto '=https' --tlsv1.2 -sSf -L \
      https://github.com/DeterminateSystems/nix-installer/releases/latest/download/nix-installer-x86_64-linux \
      -o "$nix_installer"
    chmod +x "$nix_installer"
    "$nix_installer" install steam-deck --no-confirm --prefer-upstream-nix
    rm -f "$nix_installer"
    source_nix
  fi

  if ! command -v nix >/dev/null 2>&1; then
    echo "Nix install failed or not on PATH; open a new shell and re-run setup.sh." >&2
    exit 1
  fi

  export NIX_CONFIG="experimental-features = nix-command flakes"

  # Restore Nix build users if SteamOS removed them from /etc/group/passwd.
  if ! getent group nixbld >/dev/null 2>&1; then
    _nixbld_gid="$(getent passwd nixbld1 2>/dev/null | cut -d: -f4)"
    if [ -n "$_nixbld_gid" ]; then
      sudo groupadd -r -g "$_nixbld_gid" nixbld
    else
      sudo groupadd -r nixbld
    fi
  fi
  _nix_nologin="$(command -v nologin 2>/dev/null || printf '%s\n' /usr/bin/nologin)"
  for _nix_i in $(seq 1 32); do
    _nix_user="nixbld$_nix_i"
    if ! getent passwd "$_nix_user" >/dev/null 2>&1; then
      sudo useradd -r -g nixbld -G nixbld -N -M -d /var/empty -s "$_nix_nologin" "$_nix_user"
    else
      sudo usermod -a -G nixbld "$_nix_user"
    fi
  done

  # Restore the nix-daemon system service if lost (e.g. after a SteamOS update).
  if ! systemctl is-active --quiet nix-daemon 2>/dev/null; then
    _nix_svc_dir=/nix/var/nix/profiles/default/lib/systemd/system
    if [ -f "$_nix_svc_dir/nix-daemon.service" ]; then
      sudo cp "$_nix_svc_dir/nix-daemon.service" /etc/systemd/system/nix-daemon.service
      sudo cp "$_nix_svc_dir/nix-daemon.socket" /etc/systemd/system/nix-daemon.socket 2>/dev/null || true
    else
      sudo tee /etc/systemd/system/nix-daemon.service >/dev/null <<'NIXUNIT'
[Unit]
Description=Nix Daemon
After=network.target

[Service]
ExecStart=/nix/var/nix/profiles/default/bin/nix-daemon --daemon
KillMode=process

[Install]
WantedBy=multi-user.target
NIXUNIT
    fi
    sudo systemctl daemon-reload
    sudo systemctl enable --now nix-daemon
  fi

  # home-manager reads the flake at ~/.config/home-manager
  install_link "$CONFIGS_DIR/nix" "$HOME/.config/home-manager"

  # Nix flakes only evaluate git-tracked files; stage the flake dir so it's
  # visible even on a dirty/freshly-edited checkout (no-op once committed).
  git -C "$CONFIGS_DIR" add nix >/dev/null 2>&1 || true

  echo "Installing console packages via home-manager..."
  if command -v home-manager >/dev/null 2>&1; then
    home-manager switch --impure -b backup --flake "$CONFIGS_DIR/nix#default"
  else
    nix run --extra-experimental-features "nix-command flakes" --refresh --impure \
      home-manager/release-26.05 -- switch --impure -b backup --flake "$CONFIGS_DIR/nix#default"
  fi

  source_nix
  fish -c "fish_add_path -g ~/.nix-profile/bin ~/.local/state/nix/profile/bin /nix/var/nix/profiles/default/bin" 2>/dev/null

  # sponge: only purge history on shell exit (not after each command)
  fish -c "set -Ux sponge_purge_only_on_exit true"

  # fish config + plugins
  install_link "$CONFIGS_DIR/fish" "$HOME/.config/fish"
  FISH_PLUGINS=$(grep -v '^[[:space:]]*$' "$CONFIGS_DIR/fish/fish_plugins" | tr '\n' ' ')
  fish -c "cat $CONFIGS_DIR/install_scripts/install_fisher.fish | source && fisher install $FISH_PLUGINS"
  git -C "$CONFIGS_DIR" checkout fish/fish_plugins

  # dircolors-solarized
  [ -d "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized" ] || git clone https://github.com/seebi/dircolors-solarized "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized"

  install_virtualfish

  install_opencode_tools
  install_usage_tui

  # git config
  git config --global user.name egigoka
  git config --global user.email egigoka@gmail.com
  git config --global pull.rebase true
  git -C "$CONFIGS_DIR" config core.hooksPath hooks
  git -C "$CONFIGS_DIR" config filter.codex-projects.clean hooks/filter-codex-projects

  fish_launch_snippet() {
    cat <<'EOF'

# >>> configs: launch fish >>>
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi
if [[ $- == *i* ]] && [ -t 0 ] && command -v fish >/dev/null 2>&1 && [[ $(ps -o comm= -p $PPID 2>/dev/null) != fish ]]; then
  exec fish
fi
# <<< configs: launch fish <<<
EOF
  }

  append_fish_launch() {
    local file=$1 owner=$2
    grep -q "configs: launch fish" "$file" 2>/dev/null && return 0
    if [ "$(id -un)" = "$owner" ]; then
      fish_launch_snippet >> "$file"
    elif [ "$(id -u)" -eq 0 ]; then
      # write as the target user so the file stays owned by them
      fish_launch_snippet | sudo -u "$owner" tee -a "$file" >/dev/null
    else
      return 0   # another user's dotfiles need root
    fi
    echo "Added fish launch to $file"
  }

  add_fish_launch() {
    local home=$1 owner=$2 login_rc
    [ -d "$home" ] || return 0
    append_fish_launch "$home/.bashrc" "$owner"
    for login_rc in "$home/.bash_profile" "$home/.bash_login" "$home/.profile"; do
      if [ -f "$login_rc" ]; then
        append_fish_launch "$login_rc" "$owner"
        return 0
      fi
    done
    append_fish_launch "$home/.bash_profile" "$owner"
  }

  add_fish_launch "$HOME" "$(id -un)"
  while IFS=: read -r u _ uid _ _ home shell; do
    [ "$home" = "$HOME" ] && continue
    case "$shell" in */nologin|*/false|"") continue ;; esac
    { [ "$uid" -eq 0 ] || [ "$uid" -ge 1000 ]; } || continue
    add_fish_launch "$home" "$u"
  done < <(getent passwd)

  patch_tty_stderr() {
    local f=$1 pat=$2 repl=$3
    [ -f "$f" ] || return 0
    grep -qF "$repl" "$f" 2>/dev/null && return 0   # already patched
    grep -qF "$pat" "$f" 2>/dev/null || return 0    # pattern not present
    echo "Silencing tty stderr in $f"
    local ro; ro=$(steamos-readonly status 2>/dev/null)
    [ "$ro" = enabled ] && sudo steamos-readonly disable
    sudo sed -i "s|$pat|$repl|g" "$f"
    [ "$ro" = enabled ] && sudo steamos-readonly enable
  }
  patch_tty_stderr /etc/profile.d/gpm.sh ' /usr/bin/tty ' ' /usr/bin/tty 2>/dev/null '
  patch_tty_stderr /etc/bash.bashrc '$(tty)' '$(tty 2>/dev/null)'

  if [ "$(id -u)" -eq 0 ]; then
    sshd_bin=$(command -v sshd || echo /usr/bin/sshd)
    sudo_user="${SUDO_USER:-deck}"
    sudoers_file="/etc/sudoers.d/zzz-sshd-test"
    sudoers_line="$sudo_user ALL=(root) NOPASSWD: $sshd_bin -T"
    if [ "$(cat "$sudoers_file" 2>/dev/null)" != "$sudoers_line" ]; then
      echo "Granting $sudo_user passwordless 'sudo sshd -T' via $sudoers_file"
      ro=$(steamos-readonly status 2>/dev/null)
      [ "$ro" = enabled ] && steamos-readonly disable
      tmp=$(mktemp)
      printf '%s\n' "$sudoers_line" > "$tmp"
      if visudo -cf "$tmp" >/dev/null 2>&1; then
        command install -m 0440 "$tmp" "$sudoers_file"
      else
        echo "Generated sudoers line failed validation, not installing:" >&2
        echo "  $sudoers_line" >&2
      fi
      rm -f "$tmp"
      [ "$ro" = enabled ] && steamos-readonly enable
    fi
  fi

  # Force a UTF-8 locale system-wide. SteamOS ships /etc/environment with only
  # comments, so logins land in the C locale (ANSI_X3.4-1968) and Qt/CLIs warn.
  # pam_env reads /etc/environment for every login (bash + fish, all users).
  # Use C.UTF-8, not en_US.UTF-8: Nix binaries (fish, kwriteconfig6, ...) run
  # against a Nix glibc that only ships C.UTF-8, so en_US.UTF-8 -- though listed
  # by the system `locale -a` -- fails to load in them and falls back to C.
  if [ "$(id -u)" -eq 0 ]; then
    env_file="/etc/environment"
    locale_lang="C.UTF-8"
    if ! grep -qxF "LANG=$locale_lang" "$env_file" 2>/dev/null \
       || ! grep -qxF "LC_ALL=$locale_lang" "$env_file" 2>/dev/null; then
      echo "Setting UTF-8 locale ($locale_lang) in $env_file"
      ro=$(steamos-readonly status 2>/dev/null)
      [ "$ro" = enabled ] && steamos-readonly disable
      tmp=$(mktemp)
      grep -vE '^(LANG|LC_ALL)=' "$env_file" 2>/dev/null > "$tmp" || true
      printf 'LANG=%s\nLC_ALL=%s\n' "$locale_lang" "$locale_lang" >> "$tmp"
      command install -m 0644 "$tmp" "$env_file"
      rm -f "$tmp"
      [ "$ro" = enabled ] && steamos-readonly enable
    fi
  fi

  if [ "$(id -u)" -eq 0 ]; then
    sshd_conf_dir="/etc/ssh/sshd_config.d"
    sshd_settings=(
      "PermitRootLogin no"
      "KbdInteractiveAuthentication yes"
      "PasswordAuthentication no"
      "AllowAgentForwarding no"
      "MaxAuthTries 3"
      "LoginGraceTime 60s"
      "MaxSessions 5"
      "MaxStartups 10:30:60"
      "ClientAliveInterval 300"
      "ClientAliveCountMax 36"
      "AuthenticationMethods publickey keyboard-interactive"
    )
    ro=$(steamos-readonly status 2>/dev/null)
    sshd_changed=false
    for setting in "${sshd_settings[@]}"; do
      key=${setting%% *}
      file="$sshd_conf_dir/01-$key.conf"
      [ "$(cat "$file" 2>/dev/null)" = "$setting" ] && continue
      if [ "$ro" = enabled ] && [ "$sshd_changed" = false ]; then
        steamos-readonly disable
      fi
      sshd_changed=true
      mkdir -p "$sshd_conf_dir"
      printf '%s\n' "$setting" > "$file"
      chmod 0644 "$file"
      echo "Set sshd: $setting"
    done
    if [ "$sshd_changed" = true ]; then
      if sshd -t 2>/dev/null; then
        systemctl reload sshd 2>/dev/null \
          || systemctl reload sshd.service 2>/dev/null || true
      else
        echo "sshd config validation failed; not reloading sshd" >&2
      fi
      [ "$ro" = enabled ] && steamos-readonly enable
    fi
  fi

  if [ "$(id -u)" -eq 0 ]; then
    login_user="${SUDO_USER:-deck}"
    hm_path=$(nix eval --raw --impure \
              "$CONFIGS_DIR/nix#homeConfigurations.default.config.home.path" 2>/dev/null)
    ga_so="$hm_path/lib/security/pam_google_authenticator.so"
    pam_sshd="/etc/pam.d/sshd"
    dest_so="/usr/lib/security/pam_google_authenticator.so"
    pam_line="auth required $dest_so"
    if [ -z "$hm_path" ] || [ ! -f "$ga_so" ]; then
      echo "google-authenticator PAM module not resolvable from the flake ($CONFIGS_DIR/nix);" >&2
      echo "skipping SSH 2FA wiring (is it in nix/home.nix and did home-manager run?)." >&2
    else
      mod_glibc=$(LC_ALL=C tr -c '[:print:]' '\n' < "$ga_so" \
                  | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sed 's/GLIBC_//' | sort -V | tail -n1)
      sys_glibc=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $NF}')
      [ -z "$sys_glibc" ] && sys_glibc=$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+$')
      newest=$(printf '%s\n%s\n' "$sys_glibc" "$mod_glibc" | sort -V | tail -n1)
      if [ -n "$mod_glibc" ] && [ -n "$sys_glibc" ] \
         && [ "$newest" = "$mod_glibc" ] && [ "$mod_glibc" != "$sys_glibc" ]; then
        echo "REFUSING to enable Google Authenticator PAM: module needs glibc $mod_glibc" >&2
        echo "but system has $sys_glibc -- loading it would fail and lock out SSH" >&2
        echo "(strict, no nullok). Skipping pam.d wiring; the CLI is still installed." >&2
      elif [ ! -f "$pam_sshd" ]; then
        echo "$pam_sshd missing; refusing to create a bare PAM file. Skipping 2FA wiring." >&2
      else
        beg="# >>> configs ssh 2fa (password then TOTP, both required) >>>"
        end="# <<< configs ssh 2fa <<<"
        pristine=$(awk -v b="$beg" -v e="$end" '
          $0 == b { inblk = 1; next }
          $0 == e { inblk = 0; next }
          inblk { next }
          /^# configs: Google Authenticator/  { next }
          $0 ~ /pam_google_authenticator\.so/ { next }
          { sub(/^#configs-disabled# /, ""); print }
        ' "$pam_sshd")
        desired=$(printf '%s\n' "$pristine" | awk -v b="$beg" -v e="$end" -v ga="$pam_line" '
          !done && $1 == "auth" {
            print "#configs-disabled# " $0
            print b; print "auth required pam_unix.so"; print ga; print e
            done = 1; next
          }
          { print }
          END { if (!done) { print b; print "auth required pam_unix.so"; print ga; print e } }
        ')
        if [ "$desired" != "$(cat "$pam_sshd")" ] || ! cmp -s "$ga_so" "$dest_so" 2>/dev/null; then
          ro=$(steamos-readonly status 2>/dev/null)
          [ "$ro" = enabled ] && steamos-readonly disable
          mkdir -p /usr/lib/security
          command install -m 0644 "$ga_so" "$dest_so"
          printf '%s\n' "$desired" > "$pam_sshd"
          echo "Wired SSH auth = pam_unix (password) + TOTP, both required, in $pam_sshd; installed $dest_so"
          [ "$ro" = enabled ] && steamos-readonly enable
        fi
        echo "SSH 2FA wired. Enroll BEFORE reconnecting: run 'google-authenticator' as" \
             "$login_user and keep your current session open as an escape hatch."
      fi
    fi
  fi

  if [ "$(id -u)" -eq 0 ]; then
    wg_key="$CONFIGS_DIR/wireguard/wg4.key"
    wg_tmpl="$CONFIGS_DIR/wireguard/wg4.conf"
    wg_dest="/etc/wireguard/wg4.conf"
    if [ -f "$wg_key" ] && [ -f "$wg_tmpl" ]; then
      wg_conf=$(sed "s|__PRIVATE_KEY__|$(cat "$wg_key")|" "$wg_tmpl")
      need_conf=false; [ "$wg_conf" != "$(cat "$wg_dest" 2>/dev/null)" ] && need_conf=true
      need_enable=false; systemctl is-enabled wg-quick@wg4 >/dev/null 2>&1 || need_enable=true
      if [ "$need_conf" = true ] || [ "$need_enable" = true ]; then
        ro=$(steamos-readonly status 2>/dev/null)
        [ "$ro" = enabled ] && steamos-readonly disable
        if [ "$need_conf" = true ]; then
          mkdir -p /etc/wireguard
          printf '%s\n' "$wg_conf" > "$wg_dest"
          chmod 600 "$wg_dest"
          echo "Installed $wg_dest (wireguard wg4)"
        fi
        if [ "$need_enable" = true ]; then
          systemctl enable wg-quick@wg4 >/dev/null 2>&1 && echo "Enabled wg-quick@wg4"
        fi
        [ "$ro" = enabled ] && steamos-readonly enable
      fi
    else
      echo "WireGuard: $wg_key missing; skipping wg4 (private key not on this machine)." >&2
    fi
  fi

  if command -v flatpak >/dev/null 2>&1; then
    flatpak override --user io.mpv.Mpv --filesystem="$CONFIGS_DIR/mpv"
    install_link "$CONFIGS_DIR/mpv" "$HOME/.var/app/io.mpv.Mpv/config/mpv"
    # Konsole flatpak: user fonts under ~/.local/share/fonts are symlinks into
    # $CONFIGS_DIR/fonts, which isn't mounted in the sandbox -- grant read access
    # so the symlinks resolve and fc-list picks the fonts up.
    if flatpak info org.kde.konsole >/dev/null 2>&1; then
      flatpak override --user org.kde.konsole --filesystem="$CONFIGS_DIR/fonts:ro"
    fi
  fi

  # Tailscale: vendored official Steam Deck installer. It writes /opt + the
  # systemd unit, but the root partition is read-only here, so toggle
  # steamos-readonly around it (upstream omits this). The installer only sets up
  # and starts tailscaled -- authenticate separately (see echo below).
  if [ ! -x /opt/tailscale/tailscale ] \
     || [ ! -f /etc/systemd/system/tailscaled.service ] \
     || ! systemctl is-enabled tailscaled >/dev/null 2>&1; then
    echo "Installing Tailscale (tailscale-dev/deck-tailscale)..."
    ro=$(steamos-readonly status 2>/dev/null)
    [ "$ro" = enabled ] && sudo steamos-readonly disable
    sudo bash "$CONFIGS_DIR/install_scripts/install_tailscale.sh"
    [ "$ro" = enabled ] && sudo steamos-readonly enable
  fi
  if [ -x /opt/tailscale/tailscale ]; then
    [ -e /etc/profile.d/tailscale.sh ] && . /etc/profile.d/tailscale.sh
    sudo /opt/tailscale/tailscale set --accept-dns=false >/dev/null 2>&1 || true
    echo "Tailscale ready. Authenticate once with:"
    echo "  sudo tailscale up --qr --operator=$USER --ssh --accept-dns=false"
  fi

  bash "$CONFIGS_DIR/install_scripts/install_decky.sh" || true

  # decky-launch-options runs inside Steam's environment, where PATH resolves
  # bare `python` to Nix Python and crashes before the game starts.
  dlo_run="$HOME/.dlo/run"
  if [ -f "$dlo_run" ] && grep -qF '/decky-launch-options/run.py' "$dlo_run"; then
    cat > "$dlo_run" <<'EOF'
#!/bin/bash
PYTHON=/usr/bin/python
[ -x "$PYTHON" ] || PYTHON=/usr/bin/python3
PLUGIN_RUN="$HOME/homebrew/plugins/decky-launch-options/run.py"

if [ -x "$PYTHON" ] && [ -f "$PLUGIN_RUN" ]; then
    "$PYTHON" "$PLUGIN_RUN" "$@"
else
    exec "$@"
fi
EOF
    chmod +x "$dlo_run"
  fi

  # KDiskMark disk benchmark: AppImage (not the sandboxed Flathub build, which
  # can't flush the OS cache -- see install_kdiskmark.sh for the why).
  sh "$CONFIGS_DIR/install_scripts/install_kdiskmark.sh" || true
elif [ "$is_nixos" = true ]; then
  echo "Packages needed (add to your NixOS configuration):"
  install fish
  install pay-respects
  install fzf
  install coreutils # dircolors
  install python3
  install autojump
  install bat
  install lsd
  install difftastic
  install gh
  install uv
  install starship
  install pstree
  echo
  install_link "$CONFIGS_DIR/fish" "$HOME/.config/fish"

  # dircolors-solarized
  [ -d "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized" ] || git clone https://github.com/seebi/dircolors-solarized "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized"

  install_virtualfish

  install_opencode_tools
  install_usage_tui
else
  # install micro editor
  install_if_missing micro || install_if_missing micro-editor

  # set micro as default editor on macOS (for current zsh session and persistent fish)
  if [ "$(uname -s)" = "Darwin" ]; then
    export EDITOR=micro
    fish -c "set -Ux EDITOR micro"
  fi

  # sponge: only purge history on shell exit (not after each command)
  fish -c "set -Ux sponge_purge_only_on_exit true"

  install_if_missing fish

  # setup default shell
  case "$(uname -s)" in
    Darwin) current_shell=$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}') ;;
    *)      current_shell=$(getent passwd "$USER" | cut -d: -f7) ;;
  esac
  if [ "$current_shell" != "$(which fish)" ]; then
    fish_path="$(which fish)"
    echo
    echo "$fish_path"
    echo
    if ! grep -qxF "$fish_path" /etc/shells; then
      echo "$fish_path" | sudo tee -a /etc/shells > /dev/null
    fi
    chsh -s "$fish_path" "$USER"
  fi

  # add homebrew to fish path on macOS
  if [ -d /opt/homebrew/bin ]; then
    fish -c "set -U fish_user_paths /opt/homebrew/bin \$fish_user_paths"
  fi

  # custom zsh plugins (still needed for dircolors-solarized)
  ZSH_CUSTOM="$CONFIGS_DIR/zsh/ZSH_CUSTOM" sh "$CONFIGS_DIR/zsh/ZSH_CUSTOM/install_themes_plugins.sh"

  # dircolors-solarized
  [ -d "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized" ] || git clone https://github.com/seebi/dircolors-solarized "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized"
  # zsh config
  #sh ~/configs/install_scripts/install_omz.sh
  #install_link ~/configs/zsh/.zshrc ~/.zshrc
  #install_link ~/configs/zsh/.p10k.zsh ~/.p10k.zsh

  # install fisher and fish plugins
  install_link "$CONFIGS_DIR/fish" "$HOME/.config/fish"
  FISH_PLUGINS=$(grep -v '^[[:space:]]*$' "$CONFIGS_DIR/fish/fish_plugins" | tr '\n' ' ')
  fish -c "cat $CONFIGS_DIR/install_scripts/install_fisher.fish | source && fisher install $FISH_PLUGINS"
  git -C "$CONFIGS_DIR" checkout fish/fish_plugins

  # apps that used in shell config
  command -v pay-respects >/dev/null 2>&1 || [ -x "$HOME/.local/bin/pay-respects" ] || sh "$CONFIGS_DIR/install_scripts/install_pay_respects.sh"
  install_if_missing fzf
  install_if_missing dircolors || install_if_missing coreutils
  install_if_missing python3
  command -v autojump >/dev/null 2>&1 || [ -d "$HOME/.autojump" ] || install_autojump
  install_if_missing bat
  install_if_missing lsd
  command -v difft >/dev/null 2>&1 || [ -x "$HOME/.local/bin/difft" ] || install_if_missing difftastic || sh "$CONFIGS_DIR/install_scripts/install_difftastic.sh"
  install_if_missing gh || install_if_missing github-cli
  command -v uv >/dev/null 2>&1 || install_if_missing uv || sh "$CONFIGS_DIR/install_scripts/install_uv.sh"
  install_if_missing starship
  install_if_missing pstree
  command -v node >/dev/null 2>&1 || install_if_missing nodejs || install_if_missing node
  command -v npm >/dev/null 2>&1 || install_if_missing npm

  uv tool install --force virtualfish
  "$HOME/.local/bin/vf" install

  install_opencode_tools
  install_usage_tui

  # git config
  git config --global user.name egigoka
  git config --global user.email egigoka@gmail.com
  git config --global pull.rebase true
  git -C "$CONFIGS_DIR" config core.hooksPath hooks
  git -C "$CONFIGS_DIR" config filter.codex-projects.clean hooks/filter-codex-projects
fi

install_usage

# zellij
install_link "$CONFIGS_DIR/zellij" "$HOME/.config/zellij"

# mpv
install_link "$CONFIGS_DIR/mpv" "$HOME/.config/mpv"
[ -d "$HOME/.config/mpv/scripts/uosc" ] || bash "$CONFIGS_DIR/install_scripts/install_uosc.sh"
# patch uosc to not disable mpv's native OSC (we use uosc only for its menu)
[ -f "$HOME/.config/mpv/scripts/uosc/main.lua" ] && sed -i "s|^mp\.set_property('osc', 'no')|-- & -- patched: keep native OSC|" "$HOME/.config/mpv/scripts/uosc/main.lua"

# konsole
install_link "$CONFIGS_DIR/konsole/sessionui.rc" "$HOME/.local/share/kxmlgui5/konsole/sessionui.rc"
install_link "$CONFIGS_DIR/konsole/konsoleui.rc" "$HOME/.local/share/kxmlgui5/konsole/konsoleui.rc"
install_link "$CONFIGS_DIR/konsole/konsolerc" "$HOME/.config/konsolerc"
install_link "$CONFIGS_DIR/konsole/GNOMETerminalLight.colorscheme" "$HOME/.local/share/konsole/GNOMETerminalLight.colorscheme"
install_link "$CONFIGS_DIR/konsole/default.profile" "$HOME/.local/share/konsole/default.profile"

# micro
install_link "$CONFIGS_DIR/micro/bindings.json" "$HOME/.config/micro/bindings.json"
install_link "$CONFIGS_DIR/micro/settings.json" "$HOME/.config/micro/settings.json"
install_link "$CONFIGS_DIR/micro/colorschemes" "$HOME/.config/micro/colorschemes"

# starship
install_link "$CONFIGS_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

# karabiner
if [ "$(uname -s)" = "Darwin" ]; then
  install_link "$CONFIGS_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
fi

# hammerspoon
if [ "$(uname -s)" = "Darwin" ]; then
  install_link "$CONFIGS_DIR/hammerspoon/hammerspoon.lua" "$HOME/.hammerspoon/init.lua"
fi

# cmux
if [ "$(uname -s)" = "Darwin" ]; then
  install_link "$CONFIGS_DIR/cmux/config.ghostty" "$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
  install_link "$CONFIGS_DIR/cmux/config.ghostty" "$HOME/Library/Application Support/cmux/config.ghostty"
fi

# helium tabs backup
if [ "$(uname -s)" = "Darwin" ]; then
  install_link "$CONFIGS_DIR/scripts/helium-tabs-backup.py" "$HOME/.scripts/helium-tabs-backup.py"
  install_link "$CONFIGS_DIR/mac/com.egigoka.helium-tabs-backup.plist" "$HOME/Library/LaunchAgents/com.egigoka.helium-tabs-backup.plist"
  launchctl load "$HOME/Library/LaunchAgents/com.egigoka.helium-tabs-backup.plist" 2>/dev/null || true
fi

# Remove temporary unlocked SSH keys whenever the user's launchd session starts.
if [ "$(uname -s)" = "Darwin" ]; then
  install_link "$CONFIGS_DIR/scripts/clean-unlocked-ssh-keys.sh" "$HOME/.scripts/clean-unlocked-ssh-keys.sh"
  install_link "$CONFIGS_DIR/mac/com.egigoka.clean-unlocked-ssh-keys.plist" "$HOME/Library/LaunchAgents/com.egigoka.clean-unlocked-ssh-keys.plist"
  launchctl bootout "gui/$(id -u)/com.egigoka.clean-unlocked-ssh-keys" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.egigoka.clean-unlocked-ssh-keys.plist"
fi

# opencode
bash "$CONFIGS_DIR/install_scripts/update_caveman.sh" "$OPENCODE_CONFIG_DIR"
bash "$CONFIGS_DIR/install_scripts/update_ponytail.sh" "$OPENCODE_CONFIG_DIR"
bash "$CONFIGS_DIR/install_scripts/update_frontend_design_skill.sh" "$OPENCODE_CONFIG_DIR"
bash "$CONFIGS_DIR/install_scripts/update_swiftui_expert_skill.sh" "$OPENCODE_CONFIG_DIR"
install_link "$OPENCODE_CONFIG_DIR/kv.json" "$HOME/.local/state/opencode/kv.json"
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$OPENCODE_CONFIG_DIR/AGENTS.md"
install_link "$OPENCODE_CONFIG_DIR" "$HOME/.config/opencode"

# forgecode
install_link "$CONFIGS_DIR/forgecode/permissions.yaml" "$HOME/.config/forge/permissions.yaml"

# claude code
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
install_link "$CONFIGS_DIR/claude/settings.json" "$HOME/.claude/settings.json"

# codex
configure_codex

# forge (two-account setup: ~/forge1 + ~/forge2, symlinked via ~/forge)
if [ -d "$HOME/forge" ] && [ ! -L "$HOME/forge" ]; then
  mv "$HOME/forge" "$HOME/forge1"
fi
mkdir -p "$HOME/forge1" "$HOME/forge2"
install_link "$HOME/forge1" "$HOME/forge"
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/forge1/AGENTS.md"
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/forge2/AGENTS.md"
# lsd
install_link "$CONFIGS_DIR/lsd" "$HOME/.config/lsd"

# fonts
install_link "$CONFIGS_DIR/fonts/Atkynson-Hyperlegible-Mono-NerdFont-Gapless-Braille" "$HOME/.local/share/fonts/Atkynson-Hyperlegible-Mono-NerdFont-Gapless-Braille"
command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1

# fontconfig
install_link "$CONFIGS_DIR/fontconfig" "$HOME/.config/fontconfig/conf.d"

# gnome quarter-windows keybindings
sh ~/configs/install_scripts/set_quarterwindows_hotkeys.sh

# virt-manager
if command -v dconf >/dev/null 2>&1 && { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }; then
  dconf write /org/virt-manager/virt-manager/console/resize-guest 1
fi

# kde kwin scripts
if command -v kwriteconfig6 >/dev/null 2>&1; then
  for script_dir in "$CONFIGS_DIR"/kde-scripts/*/; do
    script_name=$(basename "$script_dir")
    if [ "$is_steamos" = true ]; then
      rm -rf "$HOME/.local/share/kwin/scripts/$script_name"
      mkdir -p "$HOME/.local/share/kwin/scripts"
      cp -a "$CONFIGS_DIR/kde-scripts/$script_name" "$HOME/.local/share/kwin/scripts/$script_name"
    else
      install_link "$CONFIGS_DIR/kde-scripts/$script_name" "$HOME/.local/share/kwin/scripts/$script_name"
    fi
    kwriteconfig6 --file kwinrc --group Plugins --key "${script_name}Enabled" true
  done
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowTopHalf "Meta+Ctrl+Alt+Shift+W,none,Tile Window to Top Half"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowRightHalf "Meta+Ctrl+Alt+Shift+D,none,Tile Window to Right Half"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowBottomHalf "Meta+Ctrl+Alt+Shift+X,none,Tile Window to Bottom Half"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowLeftHalf "Meta+Ctrl+Alt+Shift+A,none,Tile Window to Left Half"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowMaximize "Meta+Ctrl+Alt+Shift+S,none,Maximize Window Without Toggling"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowTopRight "Meta+Ctrl+Alt+Shift+E,none,Tile Window to Upper Right Quadrant"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowTopLeft "Meta+Ctrl+Alt+Shift+Q,none,Tile Window to Upper Left Quadrant"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowBottomLeft "Meta+Ctrl+Alt+Shift+Z,none,Tile Window to Lower Left Quadrant"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowBottomRight "Meta+Ctrl+Alt+Shift+C,none,Tile Window to Lower Right Quadrant"
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Maximize" "none,Meta+PgUp,Maximize Window"
  qdbus org.kde.KWin /KWin reconfigure 2>/dev/null
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
  # Plasma Keyboard uses locale IDs and does not provide kk/emoji layouts here.
  kwriteconfig6 --file plasmakeyboardrc --group General --key enabledLocales "en_US,ru_RU,uk_UA"
  kwriteconfig6 --file plasmakeyboardrc --group General --key panelFillScreenWidth true
fi

# launch shell
exec fish

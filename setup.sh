#!/bin/bash

# get product name
product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)

# install command
CONFIGS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$CONFIGS_DIR/install_scripts/epm.sh"

USER="$(whoami)"

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
  # SteamOS (Steam Deck): the root filesystem is read-only/immutable and gets
  # wiped on every OS update, so pacman is unusable for persistent packages and
  # chsh / /etc edits don't stick. Install all console packages with Nix +
  # home-manager. The Determinate Systems "steam-deck" planner keeps the store
  # under /home (bind-mounted to /nix) so it survives OS updates.

  source_nix
  if ! command -v nix >/dev/null 2>&1; then
    echo "Installing upstream Nix (steam-deck planner, store under /home/nix)..."
    # The steam-deck planner installs "Determinate Nix" by DEFAULT, which
    # provisions determinate-nixd into /usr/local/bin -> fails on SteamOS's
    # read-only root. --prefer-upstream-nix forces plain upstream Nix instead,
    # which needs no /usr writes. The planner persists the store via SteamOS's
    # offload mechanism (/home/.steamos/offload/nix bind-mounted to /nix), so it
    # survives OS updates.
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

  # home-manager reads the flake at ~/.config/home-manager
  install_link "$CONFIGS_DIR/nix" "$HOME/.config/home-manager"

  # Nix flakes only evaluate git-tracked files; stage the flake dir so it's
  # visible even on a dirty/freshly-edited checkout (no-op once committed).
  git -C "$CONFIGS_DIR" add nix >/dev/null 2>&1 || true

  echo "Installing console packages via home-manager..."
  # --impure so the flake can read $USER/$HOME via builtins.getEnv.
  # -b backup so home-manager moves any pre-existing files out of the way.
  nix run --impure home-manager/release-26.05 -- switch --impure -b backup \
    --flake "$CONFIGS_DIR/nix#default"

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

  uv tool install --force virtualfish
  "$HOME/.local/bin/vf" install

  # git config
  git config --global user.name egigoka
  git config --global user.email egigoka@gmail.com
  git config --global pull.rebase true
  git -C "$CONFIGS_DIR" config core.hooksPath hooks

  # Default shell: /etc is read-only so chsh / /etc/shells don't work. Instead,
  # source nix and hand off to fish from an interactive login bash (idempotent).
  bashrc="$HOME/.bashrc"
  if ! grep -q "configs: launch fish" "$bashrc" 2>/dev/null; then
    cat >> "$bashrc" <<'EOF'

# >>> configs: launch fish >>>
# SteamOS can't chsh (read-only /etc); source nix and exec fish for interactive shells.
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi
if [[ $- == *i* ]] && command -v fish >/dev/null 2>&1 && [[ $(ps -o comm= -p $PPID 2>/dev/null) != fish ]]; then
  exec fish
fi
# <<< configs: launch fish <<<
EOF
  fi

  # SteamOS's /etc/profile.d/gpm.sh and /etc/bash.bashrc call `tty` without
  # redirecting stderr; in pty-less/SSH sessions that leaks "tty: ttyname error:
  # No such device" on every bash login (before exec fish). Both calls are no-ops
  # on a Deck. Redirect their stderr. /etc is read-only and OS updates may revert
  # this, so it re-applies on every setup.sh run (idempotent).
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

  # mpv on SteamOS is the io.mpv.Mpv Flatpak. Its sandbox overrides
  # XDG_CONFIG_HOME to ~/.var/app/io.mpv.Mpv/config, so it never reads the
  # ~/.config/mpv symlink the common section sets up below. Point the Flatpak's
  # own config dir at the repo and grant the sandbox access to the link target
  # (a path outside ~/.var/app is invisible inside the sandbox, so the symlink
  # would otherwise dangle). install_link creates ~/.var/app/io.mpv.Mpv/config,
  # which is also what makes the later install_uosc.sh detect the Flatpak and
  # write uosc through this symlink into the repo (uosc is gitignored).
  if command -v flatpak >/dev/null 2>&1; then
    flatpak override --user io.mpv.Mpv --filesystem="$CONFIGS_DIR/mpv"
    install_link "$CONFIGS_DIR/mpv" "$HOME/.var/app/io.mpv.Mpv/config/mpv"
  fi
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

  uv tool install --force virtualfish
  "$HOME/.local/bin/vf" install
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
  # install shell
  #install zsh
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
  command -v pay-respects >/dev/null 2>&1 || [ -x "$HOME/.local/bin/pay-respects" ] || install_if_missing pay-respects || sh "$CONFIGS_DIR/install_scripts/install_pay_respects.sh"
  install_if_missing fzf
  install_if_missing dircolors || install_if_missing coreutils
  install_if_missing python3
  install_if_missing autojump || install_autojump
  install_if_missing bat
  install_if_missing lsd
  command -v difft >/dev/null 2>&1 || [ -x "$HOME/.local/bin/difft" ] || install_if_missing difftastic || sh "$CONFIGS_DIR/install_scripts/install_difftastic.sh"
  install_if_missing gh || install_if_missing github-cli
  command -v uv >/dev/null 2>&1 || install_if_missing uv || sh "$CONFIGS_DIR/install_scripts/install_uv.sh"
  install_if_missing starship
  install_if_missing pstree

  uv tool install --force virtualfish
  "$HOME/.local/bin/vf" install
  
  # git config
  git config --global user.name egigoka
  git config --global user.email egigoka@gmail.com
  git config --global pull.rebase true
  git -C "$CONFIGS_DIR" config core.hooksPath hooks
fi

# disable mobile-power-saver on droidian
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "$ID" = "droidian" ]; then
    sudo ln -sf "$CONFIGS_DIR/systemd/disable-mobile-power-saver.service" /etc/systemd/system/disable-mobile-power-saver.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now disable-mobile-power-saver.service
  fi
fi

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

# opencode
install_link "$CONFIGS_DIR/opencode/kv.json" "$HOME/.local/state/opencode/kv.json"
install_link "$CONFIGS_DIR/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/.config/opencode/AGENTS.md"

# forgecode
install_link "$CONFIGS_DIR/forgecode/permissions.yaml" "$HOME/.config/forge/permissions.yaml"

# claude code
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
install_link "$CONFIGS_DIR/claude/settings.json" "$HOME/.claude/settings.json"

# codex
install_link "$CONFIGS_DIR/claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"
install_link "$CONFIGS_DIR/codex/codex.toml" "$HOME/.codex/config.toml"

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
    install_link "$CONFIGS_DIR/kde-scripts/$script_name" "$HOME/.local/share/kwin/scripts/$script_name"
    kwriteconfig6 --file kwinrc --group Plugins --key "${script_name}Enabled" true
  done
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key TileWindowMaximize "Meta+Ctrl+Alt+Shift+S,none,Maximize Window Without Toggling"
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

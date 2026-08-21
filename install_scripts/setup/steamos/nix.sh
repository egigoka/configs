#!/usr/bin/env bash

# Nix installation, recovery, home-manager, shell tools, and Git defaults.

# Source the nix profile into the current shell, if nix is installed.
source_nix() {
  if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
}

setup_steamos_nix() {
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
  export NIXPKGS_ALLOW_UNFREE=1
  install_link "$CONFIGS_DIR/nix/nixpkgs-config.nix" "$HOME/.config/nixpkgs/config.nix"

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
    home-manager switch --refresh --impure -b backup --flake "$CONFIGS_DIR/nix#default"
  else
    nix run --extra-experimental-features "nix-command flakes" --refresh --impure \
      home-manager/release-26.05 -- switch --refresh --impure -b backup --flake "$CONFIGS_DIR/nix#default"
  fi

  source_nix
  fish -c "fish_add_path -g ~/.nix-profile/bin ~/.local/state/nix/profile/bin /nix/var/nix/profiles/default/bin" 2>/dev/null
  fish -c "set -Ux NIXPKGS_ALLOW_UNFREE 1"
  mosh_server_wrapper="$HOME/.local/bin/mosh-server-systemd"
  if [ -x "$mosh_server_wrapper" ]; then
    ro=$(steamos-readonly status 2>/dev/null)
    [ "$ro" = enabled ] && sudo steamos-readonly disable
    sudo ln -sfn -- "$mosh_server_wrapper" /usr/local/bin/mosh-server
    [ "$ro" = enabled ] && sudo steamos-readonly enable
  fi
  android_studio_version=$(nix eval --impure --raw "$CONFIGS_DIR/nix#homeConfigurations.default.pkgs.android-studio.version")
  android_studio_config_version=$(printf '%s' "$android_studio_version" | cut -d. -f1,2)
  install_link \
    "$CONFIGS_DIR/opencode-steamos/android-studio/mcpServer.xml" \
    "$HOME/.config/Google/AndroidStudio$android_studio_config_version/options/mcpServer.xml"

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
}

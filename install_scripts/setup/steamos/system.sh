#!/usr/bin/env bash

# SteamOS shell startup, locale, sudoers, and SSH hardening.

setup_steamos_shell_startup() {
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
}

setup_steamos_sshd_sudoers() {
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
}

setup_steamos_locale() {
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
}

setup_steamos_ssh() {
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
}

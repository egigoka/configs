#!/usr/bin/env bash

# SteamOS WireGuard, watchdog, and Tailscale configuration.

setup_steamos_wireguard() {
  if sudo -v; then
    for wg_interface in wg1 wg4; do
      wg_key="$CONFIGS_DIR/wireguard/$wg_interface.key"
      wg_tmpl="$CONFIGS_DIR/wireguard/$wg_interface.conf"
      wg_dest="/etc/wireguard/$wg_interface.conf"
      if [ -f "$wg_key" ] && [ -f "$wg_tmpl" ]; then
        wg_conf=$(sed "s|__PRIVATE_KEY__|$(cat "$wg_key")|" "$wg_tmpl")
        need_conf=false; [ "$wg_conf" != "$(sudo cat "$wg_dest" 2>/dev/null)" ] && need_conf=true
        need_enable=false; systemctl is-enabled "wg-quick@$wg_interface" >/dev/null 2>&1 || need_enable=true
        if [ "$need_conf" = true ] || [ "$need_enable" = true ]; then
          ro=$(steamos-readonly status 2>/dev/null)
          [ "$ro" = enabled ] && sudo steamos-readonly disable
          if [ "$need_conf" = true ]; then
            sudo mkdir -p /etc/wireguard
            printf '%s\n' "$wg_conf" | sudo tee "$wg_dest" >/dev/null
            sudo chmod 600 "$wg_dest"
            echo "Installed $wg_dest (wireguard $wg_interface)"
          fi
          if [ "$need_enable" = true ]; then
            sudo systemctl enable "wg-quick@$wg_interface" >/dev/null 2>&1 && echo "Enabled wg-quick@$wg_interface"
          fi
          [ "$ro" = enabled ] && sudo steamos-readonly enable
        fi
      else
        echo "WireGuard: $wg_key missing; skipping $wg_interface (private key not on this machine)." >&2
      fi
    done

    wg_watchdog_interfaces=()
    for wg_interface in wg1 wg4; do
      [ -f "/etc/wireguard/$wg_interface.conf" ] \
        && wg_watchdog_interfaces+=("$wg_interface")
    done
    if [ "${#wg_watchdog_interfaces[@]}" -gt 0 ]; then
      wg_watchdog_service=/etc/systemd/system/wireguard-watchdog@.service
      wg_watchdog_timer=/etc/systemd/system/wireguard-watchdog@.timer
      wg_watchdog_service_tmp=$(mktemp)
      wg_watchdog_timer_tmp=$(mktemp)
      cat > "$wg_watchdog_service_tmp" <<'EOF'
[Unit]
Description=Restart WireGuard %i when 10.0.0.1 is unreachable
After=network-online.target wg-quick@%i.service
Wants=network-online.target
ConditionPathExists=/etc/wireguard/%i.conf

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if ! /usr/bin/ping -I %i -c 3 -W 2 10.0.0.1 >/dev/null 2>&1; then echo "WireGuard watchdog: 10.0.0.1 unreachable; restarting %i"; /usr/bin/systemctl restart wg-quick@%i.service; fi'
EOF
      cat > "$wg_watchdog_timer_tmp" <<'EOF'
[Unit]
Description=Check WireGuard %i every five minutes

[Timer]
OnBootSec=5min
OnUnitInactiveSec=5min
Unit=wireguard-watchdog@%i.service

[Install]
WantedBy=timers.target
EOF

      wg_watchdog_changed=false
      wg_watchdog_enable=false
      cmp -s "$wg_watchdog_service_tmp" "$wg_watchdog_service" \
        || wg_watchdog_changed=true
      cmp -s "$wg_watchdog_timer_tmp" "$wg_watchdog_timer" \
        || wg_watchdog_changed=true
      for wg_interface in "${wg_watchdog_interfaces[@]}"; do
        systemctl is-enabled "wireguard-watchdog@$wg_interface.timer" >/dev/null 2>&1 \
          || wg_watchdog_enable=true
      done

      if [ "$wg_watchdog_changed" = true ] || [ "$wg_watchdog_enable" = true ]; then
        ro=$(steamos-readonly status 2>/dev/null)
        [ "$ro" = enabled ] && sudo steamos-readonly disable
        sudo install -m 0644 "$wg_watchdog_service_tmp" "$wg_watchdog_service"
        sudo install -m 0644 "$wg_watchdog_timer_tmp" "$wg_watchdog_timer"
        sudo systemctl daemon-reload
        for wg_interface in "${wg_watchdog_interfaces[@]}"; do
          sudo systemctl enable "wireguard-watchdog@$wg_interface.timer" >/dev/null 2>&1
          sudo systemctl restart "wireguard-watchdog@$wg_interface.timer"
        done
        [ "$ro" = enabled ] && sudo steamos-readonly enable
        echo "Enabled WireGuard watchdog for ${wg_watchdog_interfaces[*]} (10.0.0.1 every five minutes)"
      else
        for wg_interface in "${wg_watchdog_interfaces[@]}"; do
          systemctl is-active "wireguard-watchdog@$wg_interface.timer" >/dev/null 2>&1 \
            || sudo systemctl start "wireguard-watchdog@$wg_interface.timer"
        done
      fi
      rm -f "$wg_watchdog_service_tmp" "$wg_watchdog_timer_tmp"
    fi
  fi
}

setup_steamos_tailscale() {
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
}

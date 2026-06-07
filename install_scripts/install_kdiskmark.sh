#!/usr/bin/env bash

# Install KDiskMark as an AppImage with an app-menu launcher.
#
# Why not the Flathub build: the sandboxed Flatpak can't flush the OS cache
# (it needs root via a host polkit helper, which a sandbox can't reach), so its
# read numbers are inflated. The AppImage isn't sandboxed and uses pkexec to
# clear caches, giving accurate results. See KDiskMark's own in-app warning.

set -eu -o pipefail

# Pin the release here; bump both when updating.
KDM_VER="3.2.0"
KDM_FILE="KDiskMark-${KDM_VER}-fio-3.40-x86_64.AppImage"
KDM_URL="https://github.com/JonMagon/KDiskMark/releases/download/${KDM_VER}/${KDM_FILE}"

APP_DIR="$HOME/Applications"
APPIMAGE="$APP_DIR/$KDM_FILE"
ICON_DST="$HOME/.local/share/icons/hicolor/256x256/apps/kdiskmark.png"
DESKTOP_DST="$HOME/.local/share/applications/kdiskmark.desktop"

# Download the AppImage if this exact version isn't already present.
if [ ! -x "$APPIMAGE" ]; then
  echo "Installing KDiskMark AppImage ${KDM_VER}..."
  mkdir -p "$APP_DIR"
  tmp="$(mktemp)"
  if curl --proto '=https' --tlsv1.2 -sSf -L "$KDM_URL" -o "$tmp"; then
    chmod +x "$tmp"
    mv -f "$tmp" "$APPIMAGE"
    # Drop any older pinned versions so they don't pile up / shadow the launcher.
    find "$APP_DIR" -maxdepth 1 -name 'KDiskMark-*-x86_64.AppImage' \
      ! -name "$KDM_FILE" -type f -delete 2>/dev/null || true
  else
    rm -f "$tmp"
    echo "KDiskMark: download failed; skipping." >&2
    exit 1
  fi
else
  echo "KDiskMark AppImage ${KDM_VER} already installed, skipping download."
fi

# Pull the icon out of the AppImage (best effort; launcher still works without).
if [ ! -f "$ICON_DST" ]; then
  tmpd="$(mktemp -d)"
  ( cd "$tmpd" && "$APPIMAGE" --appimage-extract kdiskmark.png >/dev/null 2>&1 ) || true
  if [ -f "$tmpd/squashfs-root/kdiskmark.png" ]; then
    mkdir -p "$(dirname "$ICON_DST")"
    cp "$tmpd/squashfs-root/kdiskmark.png" "$ICON_DST"
  fi
  rm -rf "$tmpd"
fi

# App-menu launcher pointing at the AppImage.
mkdir -p "$(dirname "$DESKTOP_DST")"
cat > "$DESKTOP_DST" <<EOF
[Desktop Entry]
Name=KDiskMark
GenericName=Disk Benchmark
Comment=A storage device benchmark tool (AppImage)
Exec=$APPIMAGE
Icon=kdiskmark
Terminal=false
StartupNotify=true
StartupWMClass=kdiskmark
Type=Application
Categories=System;Utility;
Keywords=benchmark;storage;performance;speed;test;disk;
EOF
update-desktop-database "$(dirname "$DESKTOP_DST")" 2>/dev/null || true

# Retire the sandboxed Flathub build if it's still around (superseded here).
if command -v flatpak >/dev/null 2>&1 \
   && flatpak info io.github.jonmagon.kdiskmark >/dev/null 2>&1; then
  echo "Removing the sandboxed Flathub KDiskMark (superseded by the AppImage)..."
  flatpak uninstall -y io.github.jonmagon.kdiskmark >/dev/null 2>&1 \
    || sudo flatpak uninstall -y --system io.github.jonmagon.kdiskmark >/dev/null 2>&1 \
    || echo "KDiskMark: couldn't auto-remove the Flatpak; remove it yourself with: flatpak uninstall io.github.jonmagon.kdiskmark" >&2
  flatpak override --user --reset io.github.jonmagon.kdiskmark >/dev/null 2>&1 || true
fi

echo "KDiskMark ${KDM_VER} ready (AppImage at $APPIMAGE)."

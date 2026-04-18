#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Skipping qBittorrent MacPorts autopatch: not macOS"
  exit 0
fi

if ! command -v port >/dev/null 2>&1; then
  echo "Skipping qBittorrent MacPorts autopatch: MacPorts is not installed"
  exit 0
fi

portfile="/opt/local/var/macports/sources/rsync.macports.org/macports/release/tarballs/ports/net/qBittorrent/Portfile"

if [[ ! -f "$portfile" ]]; then
  echo "Skipping qBittorrent MacPorts autopatch: Portfile not found at $portfile"
  exit 0
fi

if ! port installed qBittorrent 2>/dev/null | grep -q 'qBittorrent @'; then
  echo "Skipping qBittorrent MacPorts autopatch: qBittorrent is not installed via MacPorts"
  exit 0
fi

active_line="$(port installed qBittorrent 2>/dev/null | awk '/qBittorrent @/ && /\(active\)/ {sub(/^  /, ""); print; exit}')"

variant_args=()
if [[ -n "$active_line" && "$active_line" =~ @[^+[:space:]]+((\+[A-Za-z0-9_]+)+) ]]; then
  variant_blob="${BASH_REMATCH[1]}"
  while IFS= read -r variant; do
    [[ -n "$variant" ]] && variant_args+=("+$variant")
  done < <(printf '%s\n' "$variant_blob" | tr '+' '\n')
else
  variant_args=(+gui +webui)
fi

edit_result="$(python3 - "$portfile" <<'PY'
from pathlib import Path
import re
import sys

portfile = Path(sys.argv[1])
text = portfile.read_text()
changed = False

patch_line = '    reinplace "s|TimeResolution resolution = TimeResolution::Minutes|TimeResolution resolution = TimeResolution::Seconds|g" \\\n            ${worksrcpath}/src/base/utils/misc.h'
patch_block = f'post-extract {{\n{patch_line}\n}}\n\n'

if patch_line not in text:
    match = re.search(r'^post-extract\s*\{\n(.*?)\n\}\n', text, flags=re.MULTILINE | re.DOTALL)
    if match:
        body = match.group(1).rstrip('\n')
        new_body = f'{body}\n{patch_line}' if body else patch_line
        text = text[:match.start()] + f'post-extract {{\n{new_body}\n}}\n' + text[match.end():]
    else:
        marker = 'destroot {'
        if marker not in text:
            raise SystemExit('Could not find destroot block in Portfile')
        text = text.replace(marker, patch_block + marker, 1)
    changed = True

revision_match = re.search(r'^(revision\s+)(\d+)(\s*)$', text, flags=re.MULTILINE)
if not revision_match:
    raise SystemExit('Could not find revision line in Portfile')

revision = int(revision_match.group(2))
if changed:
    revision += 1
    text = text[:revision_match.start()] + revision_match.group(1) + str(revision) + revision_match.group(3) + text[revision_match.end():]
    portfile.write_text(text)
    print(f'changed:{revision}')
else:
    print(f'unchanged:{revision}')
PY
)"

edit_status="${edit_result%%:*}"
revision="${edit_result#*:}"
version="$(awk '/^github\.setup[[:space:]]/ { print $4; exit }' "$portfile")"
target_spec="@${version}_${revision}"

if [[ "$edit_status" == "unchanged" && -n "$active_line" && "$active_line" == *"$target_spec"* ]]; then
  echo "qBittorrent MacPorts autopatch already up to date: $active_line"
  exit 0
fi

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  port_cmd=(port)
else
  port_cmd=(sudo port)
fi

echo "Applying qBittorrent MacPorts autopatch using $portfile"
"${port_cmd[@]}" -s upgrade qBittorrent "${variant_args[@]}" || "${port_cmd[@]}" -s install qBittorrent "${variant_args[@]}"

new_active_line="$(port installed qBittorrent 2>/dev/null | awk '/qBittorrent @/ && /\(active\)/ {sub(/^  /, ""); print; exit}')"
if [[ -n "$new_active_line" ]]; then
  echo "Active qBittorrent after autopatch: $new_active_line"
else
  echo "qBittorrent MacPorts autopatch finished"
fi

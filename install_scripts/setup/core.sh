#!/usr/bin/env bash

# Shared setup context and filesystem helpers.

initialize_setup_context() {
  CONFIGS_DIR=${CONFIGS_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
  SETUP_OS=$(uname -s)
  USER=$(whoami)

  case "$SETUP_OS" in
    Darwin)
      SETUP_PLATFORM=standard
      OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-macos"
      ;;
    Linux)
      if grep -q '^ID=steamos$' /etc/os-release 2>/dev/null; then
        SETUP_PLATFORM=steamos
        OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-steamos"
      elif grep -q '^ID=nixos$' /etc/os-release 2>/dev/null; then
        SETUP_PLATFORM=nixos
        OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-other"
      else
        SETUP_PLATFORM=standard
        OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-other"
      fi
      ;;
    *)
      SETUP_PLATFORM=unsupported
      OPENCODE_CONFIG_DIR="$CONFIGS_DIR/opencode-other"
      ;;
  esac

  # C.UTF-8 works with both system and Nix glibc. Nix glibc does not ship
  # en_US.UTF-8, even when the host lists that locale.
  export LANG=C.UTF-8 LC_ALL=C.UTF-8
  unset LC_COLLATE LC_CTYPE LC_TIME LC_PAPER LC_MEASUREMENT LC_NUMERIC LANGUAGE
}

install_link() {
  local src dst parent link_target common prefix

  if [ $# -ne 2 ]; then
    printf 'Usage: %s SRC DST\n' "${0##*/}" >&2
    return 1
  fi

  src=$1
  dst=$2

  dst="${dst%/}"  # strip slash at the end
  parent=${dst%/*}
  [ "$parent" != "$dst" ] || parent=.
  [ -n "$parent" ] || parent=/
  [ -d "$parent" ] || mkdir -p -- "$parent" || return

  # Relative target keeps username/host paths out of the link.
  case "$src" in
    /*)
      # Most reruns already have the correct relative link. Avoid starting
      # Python for every skill in every agent home when nothing changed.
      if [ -L "$dst" ] && [ "$src" -ef "$dst" ]; then
        case "$(readlink -- "$dst")" in
          /*) ;;
          *) return 0 ;;
        esac
      fi
      # Normal absolute paths need only string operations. Keep Python's path
      # normalization for relative parents, dot segments, and repeated slashes.
      case "$parent" in
        /*)
          case "$src/|$parent/" in
            *//*|*/./*|*/../*) link_target= ;;
            *)
              common=$parent
              prefix=
              while [ -n "$common" ] && [ "$src" != "$common" ] && \
                [ "${src#"$common"/}" = "$src" ]; do
                common=${common%/*}
                prefix=../$prefix
              done
              if [ "$src" = "$common" ]; then
                link_target=${prefix%/}
              else
                link_target=$prefix${src#"$common"/}
              fi
              link_target=${link_target:-.}
              ;;
          esac
          ;;
        *) link_target= ;;
      esac
      if [ -z "$link_target" ]; then
        link_target=$(python3 -c 'import os.path,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$src" "$parent" 2>/dev/null) || link_target=$src
      fi
      ;;
    *)
      link_target=$src
      ;;
  esac

  # A correct symlink needs no work.
  if [ -L "$dst" ] && [ "$(readlink -- "$dst")" = "$link_target" ]; then
    return 0
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -e "$dst.preinstall" ]; then
      rm -rf "$dst"
    else
      mv -- "$dst" "$dst.preinstall" || return
    fi
  fi

  ln -s -- "$link_target" "$dst"
}

# Check large link sets in one process, then use the normal installer for any
# missing or changed link. Results live only for this call, never across runs.
install_links() {
  local pending index
  local -a links=("$@")
  [ "$(($# % 2))" -eq 0 ] || return 1
  [ "$#" -gt 0 ] || return 0
  if ! command -v python3 >/dev/null 2>&1; then
    while [ "$#" -gt 0 ]; do
      install_link "$1" "$2" || return
      shift 2
    done
    return 0
  fi
  pending=$(python3 - "$@" <<'PY'
import os
import sys

links = sys.argv[1:]
for index in range(0, len(links), 2):
    source, destination = links[index:index + 2]
    destination = destination.rstrip("/")
    try:
        target = os.readlink(destination)
        if os.path.isabs(source):
            current = not os.path.isabs(target) and os.path.samefile(source, destination)
        else:
            current = target == source
    except OSError:
        current = False
    if not current:
        print(index)
PY
  ) || return
  for index in $pending; do
    install_link "${links[$index]}" "${links[$((index + 1))]}" || return
  done
}

#!/usr/bin/env bash

# Check the registry every run, but reinstall only changed or incomplete CLIs.
install_latest_npm_packages() {
  local root package latest
  local pending=()
  root=$(npm root -g 2>/dev/null) || root=

  for package in "$@"; do
    latest=
    if [ -n "$root" ] && [ -f "$root/$package/package.json" ]; then
      latest=$(npm view "$package@latest" version 2>/dev/null) || latest=
    fi
    if [ -n "$latest" ] && python3 - "$root/$package" "$latest" <<'PY'
import json
import os
import pathlib
import shutil
import sys

directory = pathlib.Path(sys.argv[1])
try:
    package = json.loads((directory / "package.json").read_text())
    if package["version"] != sys.argv[2]:
        sys.exit(1)
    binaries = package["bin"]
    if isinstance(binaries, str):
        binaries = {directory.name: binaries}
    if not isinstance(binaries, dict) or not binaries:
        sys.exit(1)
    for name, relative_path in binaries.items():
        target = directory / relative_path
        command = shutil.which(name)
        if not command or not os.access(target, os.X_OK) or not os.path.samefile(command, target):
            sys.exit(1)
except (OSError, ValueError, KeyError, TypeError):
    sys.exit(1)
PY
    then
      printf '%s %s is current, skipping installation\n' "$package" "$latest"
    else
      pending+=("$package@latest")
    fi
  done

  if [ "${#pending[@]}" -gt 0 ]; then
    npm install --global "${pending[@]}"
  fi
}

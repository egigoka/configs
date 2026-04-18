#!/usr/bin/env python3
"""Reset only LaunchNext app-placement persistence.

This removes the SwiftData layout store used for top-level app/folder placement:
  ~/Library/Application Support/LaunchNext/Data.store*

It intentionally does not touch other LaunchNext state such as defaults or CLI history.
"""

from pathlib import Path
import subprocess
import sys
import time


STORE_DIR = Path.home() / "Library" / "Application Support" / "LaunchNext"
STORE_FILES = [
    STORE_DIR / "Data.store",
    STORE_DIR / "Data.store-shm",
    STORE_DIR / "Data.store-wal",
]


def quit_app() -> None:
    subprocess.run(
        ["osascript", "-e", 'tell application "LaunchNext" to quit'],
        capture_output=True,
        text=True,
    )
    time.sleep(2)


def main() -> int:
    if not STORE_DIR.exists():
        print(f"Missing LaunchNext support directory: {STORE_DIR}", file=sys.stderr)
        return 1

    quit_app()

    removed = []
    missing = []
    for path in STORE_FILES:
        if path.exists():
            path.unlink()
            removed.append(str(path))
        else:
            missing.append(str(path))

    print("Reset LaunchNext app-placement store.")
    if removed:
        print("Removed:")
        for path in removed:
            print(f"  {path}")
    if missing:
        print("Already absent:")
        for path in missing:
            print(f"  {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

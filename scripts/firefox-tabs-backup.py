#!/usr/bin/env python3
"""Backup open tabs from Firefox profiles to JSON with tiered retention."""

import configparser
import json
import os
import platform
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

BACKUP_DIR = Path.home() / "backups" / "firefox"
MOZLZ4_MAGIC = b"mozLz40\0"


def xdg_dir(var, fallback):
    value = os.environ.get(var)
    if not value:
        value = Path.home() / fallback
    return Path(value).expanduser()


def firefox_roots():
    if platform.system() == "Darwin":
        return [Path.home() / "Library" / "Application Support" / "Firefox"]

    flatpak = Path.home() / ".var" / "app" / "org.mozilla.firefox"
    snap_common = Path.home() / "snap" / "firefox" / "common"
    snap_current = Path.home() / "snap" / "firefox" / "current"
    return [
        xdg_dir("XDG_CONFIG_HOME", ".config") / "mozilla" / "firefox",
        xdg_dir("XDG_DATA_HOME", ".local/share") / "mozilla" / "firefox",
        Path.home() / ".mozilla" / "firefox",
        flatpak / "config" / "mozilla" / "firefox",
        flatpak / "data" / "mozilla" / "firefox",
        flatpak / ".mozilla" / "firefox",
        snap_common / ".config" / "mozilla" / "firefox",
        snap_common / ".mozilla" / "firefox",
        snap_current / ".config" / "mozilla" / "firefox",
        snap_current / ".mozilla" / "firefox",
    ]


def profile_candidates(root):
    profiles = []
    ini = root / "profiles.ini"
    if ini.is_file():
        config = configparser.ConfigParser()
        config.read(ini)
        for section in config.sections():
            if not section.startswith("Profile"):
                continue
            raw_path = config.get(section, "Path", fallback="")
            if not raw_path:
                continue
            profile_path = Path(raw_path).expanduser()
            if config.get(section, "IsRelative", fallback="1") == "1":
                profile_path = root / profile_path
            profiles.append({
                "name": config.get(section, "Name", fallback=profile_path.name),
                "path": profile_path,
                "default": config.get(section, "Default", fallback="0") == "1",
                "root": root,
            })

    for parent in (root / "Profiles", root):
        if not parent.is_dir():
            continue
        for profile_path in parent.iterdir():
            if not profile_path.is_dir():
                continue
            if (profile_path / "prefs.js").is_file() or (profile_path / "sessionstore-backups").is_dir():
                profiles.append({
                    "name": profile_path.name,
                    "path": profile_path,
                    "default": False,
                    "root": root,
                })

    return profiles


def find_profiles():
    profiles = []
    seen = set()
    for root in firefox_roots():
        if not root.is_dir():
            continue
        for profile in profile_candidates(root):
            path = profile["path"]
            if not path.is_dir():
                continue
            key = path.resolve()
            if key in seen:
                continue
            seen.add(key)
            profiles.append(profile)
    profiles.sort(key=lambda item: (not item["default"], str(item["path"])))
    return profiles


def lz4_decompress(data):
    out = bytearray()
    i = 0
    while i < len(data):
        token = data[i]
        i += 1

        literal_len = token >> 4
        if literal_len == 15:
            while True:
                extra = data[i]
                i += 1
                literal_len += extra
                if extra != 255:
                    break

        out.extend(data[i:i + literal_len])
        i += literal_len
        if i >= len(data):
            break

        offset = data[i] | (data[i + 1] << 8)
        i += 2
        if offset == 0 or offset > len(out):
            raise ValueError("invalid lz4 offset")

        match_len = token & 0x0F
        if match_len == 15:
            while True:
                extra = data[i]
                i += 1
                match_len += extra
                if extra != 255:
                    break
        match_len += 4

        start = len(out) - offset
        for _ in range(match_len):
            out.append(out[start])
            start += 1

    return bytes(out)


def read_jsonlz4(path):
    raw = path.read_bytes()
    if raw.startswith(MOZLZ4_MAGIC):
        compressed = raw[len(MOZLZ4_MAGIC):]
        if len(compressed) >= 4:
            expected_size = int.from_bytes(compressed[:4], "little")
            try:
                decoded = lz4_decompress(compressed[4:])
                if len(decoded) == expected_size:
                    raw = decoded
                else:
                    raw = lz4_decompress(compressed)
            except Exception:
                raw = lz4_decompress(compressed)
        else:
            raw = lz4_decompress(compressed)
    return json.loads(raw.decode("utf-8"))


def session_candidates(profile_path):
    backup_dir = profile_path / "sessionstore-backups"
    return [
        backup_dir / "recovery.jsonlz4",
        backup_dir / "recovery.baklz4",
        profile_path / "sessionstore.jsonlz4",
        backup_dir / "previous.jsonlz4",
    ]


def load_session(profile_path):
    last_error = None
    for path in session_candidates(profile_path):
        if not path.is_file():
            continue
        try:
            return path, read_jsonlz4(path), None
        except Exception as e:
            last_error = f"{path}: {e}"
    return None, None, last_error


def current_entry(tab):
    entries = tab.get("entries") or []
    if not entries:
        return None
    index = tab.get("index", len(entries))
    try:
        index = int(index)
    except (TypeError, ValueError):
        index = len(entries)
    if index < 1 or index > len(entries):
        index = len(entries)
    return entries[index - 1]


def extract_tabs(profile, session):
    tabs = []
    for window_index, window in enumerate(session.get("windows", []), start=1):
        selected = window.get("selected", 1)
        try:
            selected = int(selected)
        except (TypeError, ValueError):
            selected = 1
        for tab_index, tab in enumerate(window.get("tabs", []), start=1):
            entry = current_entry(tab)
            if not entry:
                continue
            tabs.append({
                "url": entry.get("url", ""),
                "title": entry.get("title", ""),
                "window": window_index,
                "tab_index": tab_index,
                "active": tab_index == selected,
                "profile": profile["name"],
                "profile_dir": str(profile["path"]),
            })
    return tabs


def cleanup(backup_dir: Path):
    pattern = re.compile(r"^tabs-(\d{4}-\d{2}-\d{2}-\d{2})\.json$")
    files = []
    for f in backup_dir.glob("tabs-*.json"):
        m = pattern.match(f.name)
        if m:
            dt = datetime.strptime(m.group(1), "%Y-%m-%d-%H")
            files.append((dt, f))
    files.sort(reverse=True)

    now = datetime.now()
    keep = set()

    for _, f in files[:24]:
        keep.add(f)

    seen_days = set()
    cutoff_hourly = now - timedelta(hours=24)
    for dt, f in files:
        if dt >= cutoff_hourly:
            continue
        key = dt.strftime("%Y-%m-%d")
        if key not in seen_days:
            seen_days.add(key)
            keep.add(f)
        if len(seen_days) >= 7:
            break

    seen_weeks = set()
    cutoff_daily = now - timedelta(days=7)
    for dt, f in files:
        if dt >= cutoff_daily:
            continue
        key = dt.strftime("%Y-W%V")
        if key not in seen_weeks:
            seen_weeks.add(key)
            keep.add(f)
        if len(seen_weeks) >= 4:
            break

    seen_months = set()
    cutoff_weekly = now - timedelta(weeks=4)
    for dt, f in files:
        if dt >= cutoff_weekly:
            continue
        key = dt.strftime("%Y-%m")
        if key not in seen_months:
            seen_months.add(key)
            keep.add(f)
        if len(seen_months) >= 12:
            break

    for _, f in files:
        if f not in keep:
            f.unlink()


def main():
    profiles = []
    tabs = []
    errors = []

    for profile in find_profiles():
        source, session, err = load_session(profile["path"])
        if session is None:
            if err:
                errors.append(err)
            continue
        profile_tabs = extract_tabs(profile, session)
        tabs.extend(profile_tabs)
        profiles.append({
            "name": profile["name"],
            "path": str(profile["path"]),
            "root": str(profile["root"]),
            "source_file": str(source),
            "tab_count": len(profile_tabs),
        })

    if not profiles:
        for err in errors:
            print(err, file=sys.stderr)
        print("Firefox profile/session not found; skipping tab backup")
        sys.exit(0)

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d-%H")
    out_file = BACKUP_DIR / f"tabs-{timestamp}.json"
    payload = {
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "browser": "Firefox",
        "profile_count": len(profiles),
        "tab_count": len(tabs),
        "profiles": profiles,
        "tabs": tabs,
    }
    out_file.write_text(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"Saved {len(tabs)} tabs from {len(profiles)} profiles to {out_file}")

    cleanup(BACKUP_DIR)


if __name__ == "__main__":
    main()

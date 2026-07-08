#!/usr/bin/env python3
"""Backup open tabs from Brave Origin to JSON with tiered retention."""

import json
import re
import sys
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

from chromium_session_tabs import get_tabs_offline

BACKUP_DIR = Path.home() / "backups" / "brave-origin"
PROFILE_DIR = Path.home() / ".config" / "BraveSoftware" / "Brave-Origin"
DEBUG_PORT = 9223


def get_tabs_cdp(port=DEBUG_PORT):
    try:
        with urllib.request.urlopen(f"http://localhost:{port}/json/list", timeout=3) as r:
            items = json.loads(r.read())
    except Exception as e:
        return None, str(e)
    tabs = []
    for item in items:
        if item.get("type") != "page":
            continue
        tabs.append({
            "url": item.get("url", ""),
            "title": item.get("title", ""),
            "window": 1,
            "tab_index": len(tabs) + 1,
            "active": False,
        })
    return tabs, None


def get_tabs():
    data, live_err = get_tabs_cdp()
    if live_err is None:
        return data, "live", None, None

    data, metadata, offline_err = get_tabs_offline(PROFILE_DIR)
    if offline_err is None:
        return data, "offline", metadata, None
    return None, None, None, f"{live_err}; offline fallback: {offline_err}"


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
    data, source, metadata, err = get_tabs()
    if err is not None:
        print(f"Brave Origin tab backup error: {err}", file=sys.stderr)
        sys.exit(0)

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d-%H")
    out_file = BACKUP_DIR / f"tabs-{timestamp}.json"
    payload = {
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "browser": "Brave Origin",
        "profile_dir": str(PROFILE_DIR),
        "source": source,
        "tab_count": len(data),
        "tabs": data,
    }
    if metadata:
        payload.update(metadata)
    out_file.write_text(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"Saved {len(data)} tabs to {out_file}")

    cleanup(BACKUP_DIR)


if __name__ == "__main__":
    main()

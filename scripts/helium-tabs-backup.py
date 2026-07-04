#!/usr/bin/env python3
"""Backup open tabs from Helium browser to JSON with tiered retention."""

import json
import platform
import re
import subprocess
import sys
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

PLATFORM = platform.system()
BACKUP_DIR = Path.home() / "backups" / "helium"

if PLATFORM == "Darwin":
    PROFILE_DIR = Path.home() / "Library" / "Application Support" / "net.imput.helium"
else:
    PROFILE_DIR = Path.home() / ".config" / "net.imput.helium"

JXA_SCRIPT = """
var app = Application("Helium");
var tabs = [];
app.windows().forEach(function(win, wIdx) {
    var activeTab = win.activeTab();
    win.tabs().forEach(function(tab, tIdx) {
        tabs.push({
            url: tab.url(),
            title: tab.name(),
            window: wIdx + 1,
            tab_index: tIdx + 1,
            active: tab.url() === activeTab.url()
        });
    });
});
JSON.stringify(tabs);
"""


def helium_running():
    name = "Helium" if PLATFORM == "Darwin" else "helium"
    return subprocess.run(
        ["pgrep", "-x", name],
        capture_output=True,
        text=True,
    ).returncode == 0


def get_tabs_cdp(port=9222):
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
    if PLATFORM == "Darwin":
        result = subprocess.run(
            ["osascript", "-l", "JavaScript", "-e", JXA_SCRIPT],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            return None, result.stderr.strip()
        return json.loads(result.stdout.strip()), None
    return get_tabs_cdp()


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

    # Hourly: keep 24 newest
    for _, f in files[:24]:
        keep.add(f)

    # Daily: 1 per calendar day for days beyond 24h window, up to 7 days
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

    # Weekly: 1 per ISO week beyond 7-day window, up to 4 weeks
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

    # Monthly: 1 per month beyond 4-week window, up to 12 months
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
    if not helium_running():
        print("Helium not running; skipping tab backup")
        sys.exit(0)

    data, err = get_tabs()
    if err is not None:
        print(f"Helium not running or error: {err}", file=sys.stderr)
        sys.exit(0)

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d-%H")
    out_file = BACKUP_DIR / f"tabs-{timestamp}.json"
    payload = {
        "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "browser": "Helium",
        "profile_dir": str(PROFILE_DIR),
        "tab_count": len(data),
        "tabs": data,
    }
    out_file.write_text(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"Saved {len(data)} tabs to {out_file}")

    cleanup(BACKUP_DIR)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Rebuild LaunchNext folders from launchnext-snapshot.json.

Flow:
  1. Reset LaunchNext app-placement persistence.
  2. Recreate each folder from the snapshot (using its first two apps).
  3. Append any remaining snapshot apps into the matching new folder.
  4. Re-read live state and diff it against the snapshot.
"""

import json
import subprocess
import sys
import time
from pathlib import Path

SNAPSHOT_PATH = Path(__file__).resolve().parent / "launchnext-snapshot.json"
RESET_SCRIPT_PATH = Path(__file__).resolve().parent / "launchnext-reset.py"

TRANSIENT_STDERR = "Failed to receive CLI response."
MAX_RETRIES = 8
RETRY_DELAY = 0.4


def load_snapshot():
    with SNAPSHOT_PATH.open() as f:
        return json.load(f)


def current_snapshot():
    for attempt in range(MAX_RETRIES):
        result = subprocess.run(
            ["launchnext", "--cli", "snapshot"],
            capture_output=True,
            text=True,
        )
        out = result.stdout
        if out.strip():
            try:
                return json.loads(out)
            except json.JSONDecodeError:
                pass
        print(
            f"    snapshot retry {attempt + 1}/{MAX_RETRIES} (stderr={result.stderr.strip()!r})"
        )
        time.sleep(RETRY_DELAY)
    raise RuntimeError("current_snapshot: CLI kept returning empty/invalid output")


WARNINGS = []


class CLIError(RuntimeError):
    pass


def run_cli(*args, allow_failure=False):
    cmd = ["launchnext", "--cli", *args]
    print(f"  $ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)

    stderr = result.stderr.strip()
    if stderr:
        for line in stderr.splitlines():
            print(f"    err| {line}")

    payload = None
    if result.stdout.strip():
        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError:
            for line in result.stdout.splitlines():
                print(f"    out| {line}")

    if payload is not None:
        summary = payload.get("summary") or payload.get("command")
        print(
            f"    out| ok={payload.get('ok')} applied={payload.get('applied')} :: {summary}"
        )

    ok_flag = payload.get("ok") if isinstance(payload, dict) else None
    failed = result.returncode != 0 or bool(stderr) or (ok_flag is False)

    if failed:
        msg = f"CLI failure ({' '.join(cmd)}): rc={result.returncode} stderr={stderr!r} ok={ok_flag}"
        if allow_failure:
            print(f"    WARN {msg}")
            WARNINGS.append(msg)
            return payload
        raise CLIError(msg)

    return payload


def folder_apps(data):
    for item in data.get("items", []):
        if item.get("kind") != "folder":
            continue
        folder_id = item["id"]
        folder_name = item.get("name") or "Folder"
        for app in item.get("apps", []):
            yield folder_id, folder_name, app["name"], app["path"]


def _top_level_paths(data):
    paths = set()
    for item in data.get("items", []):
        if item.get("kind") == "folder":
            continue
        p = item.get("path")
        if p:
            paths.add(p)
    return paths


def reset_app_placement():
    print("\n== phase: reset_app_placement ==")
    if not RESET_SCRIPT_PATH.exists():
        raise RuntimeError(f"reset script not found: {RESET_SCRIPT_PATH}")

    result = subprocess.run(
        [sys.executable, str(RESET_SCRIPT_PATH)],
        capture_output=True,
        text=True,
    )

    if result.stdout.strip():
        for line in result.stdout.splitlines():
            print(f"    out| {line}")
    if result.stderr.strip():
        for line in result.stderr.splitlines():
            print(f"    err| {line}")

    if result.returncode != 0:
        raise RuntimeError(f"reset_app_placement failed with rc={result.returncode}")

    # Give LaunchNext a moment to relaunch or rebuild its default top-level layout.
    time.sleep(2)


def _snapshot_folders(data):
    return [item for item in data.get("items", []) if item.get("kind") == "folder"]


def _find_folder_id(live_data, name, required_paths):
    required = set(required_paths)
    for item in _snapshot_folders(live_data):
        if item.get("name") != name:
            continue
        live_paths = {a["path"] for a in item.get("apps", [])}
        if required.issubset(live_paths):
            return item["id"]
    return None


def _pick_donor(live, exclude_paths):
    """Pick any top-level app we can borrow as a second seed for create-folder."""
    excluded = set(exclude_paths)
    for item in live.get("items", []):
        if item.get("kind") == "folder":
            continue
        p = item.get("path")
        if p and p not in excluded:
            return p
    return None


FOLDERS_AT_END = ("Bullshit", "Menubar apps", "Safari Extensions")


def _folder_sort_key(folder):
    name = folder.get("name") or ""
    try:
        tail_rank = FOLDERS_AT_END.index(name)
        return (1, tail_rank, name.lower())
    except ValueError:
        return (0, 0, name.lower())


def recreate_folders_from_snapshot(data):
    print("\n== phase: recreate_folders_from_snapshot ==")
    folders = sorted(_snapshot_folders(data), key=_folder_sort_key)
    print(
        f"  snapshot defines {len(folders)} folders (order: {[f.get('name') for f in folders]})"
    )
    for target_index, folder in enumerate(folders):
        apps = folder.get("apps", [])
        name = folder.get("name") or "Folder"
        if len(apps) == 0:
            print(f"  SKIP '{name}' — empty folder in snapshot")
            continue

        live = current_snapshot()
        top = _top_level_paths(live)

        available = [a for a in apps if a["path"] in top]
        donor_path = None
        seed_paths = None
        if len(available) >= 2:
            seed_paths = [available[0]["path"], available[1]["path"]]
        elif len(available) == 1:
            donor_path = _pick_donor(live, exclude_paths=[available[0]["path"]])
            if donor_path is None:
                print(f"  FAIL '{name}' — only one available app and no donor")
                WARNINGS.append(f"{name}: no donor for 1-app folder")
                continue
            seed_paths = [available[0]["path"], donor_path]
            print(f"  '{name}' has 1 top-level app, borrowing donor {donor_path}")
        else:
            print(f"  FAIL '{name}' — no snapshot apps present at top level:")
            for a in apps:
                print(f"       unavailable: {a['path']}")
            WARNINGS.append(f"{name}: no seed apps available at top level")
            continue

        args = ["create-folder"]
        for p in seed_paths:
            args += ["--path", p]
        args += ["--name", name, "--index", str(target_index)]
        print(f"Creating folder {name} at index {target_index}")
        run_cli(*args, allow_failure=True)

        verify = current_snapshot()
        new_folder = None
        for f in _snapshot_folders(verify):
            if f.get("name") != name:
                continue
            paths_in_f = {a["path"] for a in f.get("apps", [])}
            if set(seed_paths).issubset(paths_in_f):
                new_folder = f
                break
        if new_folder is None:
            print(f"  FAIL '{name}' — not present in live state after create-folder")
            continue

        if donor_path is not None:
            print(f"  ejecting donor {donor_path} back to top level")
            run_cli(
                "move",
                "--source",
                "folder-app",
                "--folder-id",
                new_folder["id"],
                "--path",
                donor_path,
                "--to",
                "normal-index",
                "--index",
                str(len(verify.get("items", []))),
                allow_failure=True,
            )


def move_apps_to_folders(data):
    print("\n== phase: move_apps_to_folders ==")
    folders = sorted(_snapshot_folders(data), key=_folder_sort_key)
    for folder in folders:
        raw_apps = folder.get("apps", [])
        name = folder.get("name") or "Folder"

        seen_paths = set()
        apps = []
        dupes = 0
        for a in raw_apps:
            p = a["path"]
            if p in seen_paths:
                dupes += 1
                continue
            seen_paths.add(p)
            apps.append(a)
        if dupes:
            print(f"  '{name}': dropped {dupes} duplicate path(s) from snapshot")

        if len(apps) < 2:
            continue

        live = current_snapshot()
        live_folder = None
        for f in _snapshot_folders(live):
            if f.get("name") == name:
                live_folder = f
                break
        if live_folder is None:
            msg = f"{name}: live folder not found during append phase"
            print(f"  SKIP {msg}")
            WARNINGS.append(msg)
            continue
        new_id = live_folder["id"]
        already_in = {a["path"] for a in live_folder.get("apps", [])}

        pending = [a for a in apps if a["path"] not in already_in]
        print(f"  folder '{name}' -> live id {new_id}, appending {len(pending)} apps")

        for app in pending:
            app_path = app["path"]
            live = current_snapshot()
            top = _top_level_paths(live)
            if app_path not in top:
                msg = f"{name}: {app['name']} not at top level ({app_path})"
                print(f"  WARN {msg}")
                WARNINGS.append(msg)
                continue
            print(f"Moving {app['name']} to {name}")
            run_cli(
                "move",
                "--source",
                "normal-app",
                "--path",
                app_path,
                "--to",
                "folder-append",
                "--target-folder-id",
                new_id,
                allow_failure=True,
            )


def compare_snapshots(expected, actual):
    def folder_map(data):
        out = {}
        for f in _snapshot_folders(data):
            out[f.get("name", "")] = [a["path"] for a in f.get("apps", [])]
        return out

    exp = folder_map(expected)
    act = folder_map(actual)

    print("\n=== Snapshot diff ===")
    ok = True
    for name, want in exp.items():
        got = act.get(name)
        if got is None:
            print(f"MISSING folder: {name}")
            ok = False
            continue
        missing = [p for p in want if p not in got]
        extra = [p for p in got if p not in want]
        if missing or extra:
            ok = False
            print(f"DIFF folder: {name}")
            for p in missing:
                print(f"  - missing: {p}")
            for p in extra:
                print(f"  + extra:   {p}")
    for name in act:
        if name not in exp:
            ok = False
            print(f"UNEXPECTED folder: {name}")
    if ok:
        print("Live state matches snapshot.")


def main():
    #reset_app_placement()
    data = load_snapshot()
    recreate_folders_from_snapshot(data)
    move_apps_to_folders(data)
    data_current = current_snapshot()
    compare_snapshots(data, data_current)

    if WARNINGS:
        print(f"\n=== {len(WARNINGS)} warning(s) during run ===")
        for w in WARNINGS:
            print(f"  - {w}")


if __name__ == "__main__":
    sys.exit(main())

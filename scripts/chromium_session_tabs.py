#!/usr/bin/env python3
"""Read current tabs from Chromium SNSS session files."""

from dataclasses import dataclass, field
from pathlib import Path
import struct


class SessionParseError(Exception):
    pass


@dataclass
class HistoryEntry:
    url: str = ""
    title: str = ""


@dataclass
class SessionTab:
    id: int
    history: dict[int, HistoryEntry] = field(default_factory=dict)
    index: int = 0
    window_id: int = 0
    deleted: bool = False
    current_history_index: int = 0


@dataclass
class SessionWindow:
    id: int
    active_tab_index: int = 0
    deleted: bool = False


class Cursor:
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0

    def read_u32(self):
        if self.offset + 4 > len(self.data):
            raise SessionParseError("unexpected end of command")
        value = struct.unpack_from("<I", self.data, self.offset)[0]
        self.offset += 4
        return value

    def read_u64(self):
        if self.offset + 8 > len(self.data):
            raise SessionParseError("unexpected end of command")
        value = struct.unpack_from("<Q", self.data, self.offset)[0]
        self.offset += 8
        return value

    def read_bytes(self, length: int):
        padded = length + ((4 - length % 4) % 4)
        if self.offset + padded > len(self.data):
            raise SessionParseError("unexpected end of command")
        value = self.data[self.offset:self.offset + length]
        self.offset += padded
        return value

    def read_string(self):
        length = self.read_u32()
        return self.read_bytes(length).decode("utf-8", errors="replace")

    def read_string16(self):
        length = self.read_u32() * 2
        return self.read_bytes(length).decode("utf-16-le", errors="replace")


def newest_session_files(profile_dir: Path):
    sessions_dir = profile_dir / "Sessions"
    if not sessions_dir.is_dir():
        return []
    return sorted(
        sessions_dir.glob("Session_*"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )


def profile_dirs(user_data_dir: Path):
    if not user_data_dir.is_dir():
        return []

    profiles = []
    for candidate in user_data_dir.iterdir():
        if candidate.is_dir() and newest_session_files(candidate):
            profiles.append(candidate)

    def sort_key(path: Path):
        if path.name == "Default":
            return (0, path.name)
        if path.name.startswith("Profile "):
            return (1, path.name)
        return (2, path.name)

    return sorted(profiles, key=sort_key)


def iter_commands(path: Path):
    data = path.read_bytes()
    if len(data) < 8 or data[:4] != b"SNSS":
        raise SessionParseError("invalid SNSS header")

    version = struct.unpack_from("<I", data, 4)[0]
    if version not in (1, 3):
        raise SessionParseError(f"unsupported SNSS version {version}")

    offset = 8
    while offset + 2 <= len(data):
        size = struct.unpack_from("<H", data, offset)[0]
        offset += 2
        if size == 0:
            continue
        if offset + size > len(data):
            break
        command = data[offset:offset + size]
        offset += size
        yield command[0], command[1:]


def get_tab(tabs: dict[int, SessionTab], tab_id: int):
    if tab_id not in tabs:
        tabs[tab_id] = SessionTab(tab_id)
    return tabs[tab_id]


def get_window(windows: dict[int, SessionWindow], window_id: int):
    if window_id not in windows:
        windows[window_id] = SessionWindow(window_id)
    return windows[window_id]


def parse_session_file(path: Path):
    tabs: dict[int, SessionTab] = {}
    windows: dict[int, SessionWindow] = {}
    active_window_id = None

    for command_id, payload in iter_commands(path):
        cursor = Cursor(payload)
        try:
            if command_id == 6:
                cursor.read_u32()
                tab_id = cursor.read_u32()
                history_index = cursor.read_u32()
                url = cursor.read_string()
                title = cursor.read_string16()
                get_tab(tabs, tab_id).history[history_index] = HistoryEntry(url, title)
            elif command_id == 0:
                window_id = cursor.read_u32()
                tab_id = cursor.read_u32()
                get_window(windows, window_id)
                get_tab(tabs, tab_id).window_id = window_id
            elif command_id == 2:
                tab_id = cursor.read_u32()
                get_tab(tabs, tab_id).index = cursor.read_u32()
            elif command_id == 7:
                tab_id = cursor.read_u32()
                get_tab(tabs, tab_id).current_history_index = cursor.read_u32()
            elif command_id == 8:
                window_id = cursor.read_u32()
                get_window(windows, window_id).active_tab_index = cursor.read_u32()
            elif command_id == 16:
                get_tab(tabs, cursor.read_u32()).deleted = True
            elif command_id == 17:
                get_window(windows, cursor.read_u32()).deleted = True
            elif command_id == 20:
                active_window_id = cursor.read_u32()
                get_window(windows, active_window_id)
            elif command_id == 21:
                cursor.read_u32()
                cursor.read_u64()
        except SessionParseError:
            continue

    for tab in tabs.values():
        if tab.window_id:
            get_window(windows, tab.window_id)

    parsed_windows = []
    for window in sorted(windows.values(), key=lambda w: (w.id != active_window_id, w.id)):
        if window.deleted:
            continue
        window_tabs = [
            tab for tab in tabs.values()
            if tab.window_id == window.id and not tab.deleted and tab.history
        ]
        window_tabs.sort(key=lambda tab: (tab.index, tab.id))
        if window_tabs:
            parsed_windows.append((window, window_tabs))
    return parsed_windows


def selected_history_entry(tab: SessionTab):
    if tab.current_history_index in tab.history:
        return tab.history[tab.current_history_index]
    latest_index = max(tab.history)
    return tab.history[latest_index]


def tabs_from_session_file(path: Path, profile_dir: Path, profile_name: str, first_window: int):
    tabs = []
    window_number = first_window
    for window, window_tabs in parse_session_file(path):
        visible_index = 0
        for tab in window_tabs:
            entry = selected_history_entry(tab)
            if not entry.url:
                continue
            tabs.append({
                "url": entry.url,
                "title": entry.title,
                "window": window_number,
                "tab_index": visible_index + 1,
                "active": visible_index == window.active_tab_index,
                "profile": profile_name,
                "profile_dir": str(profile_dir),
            })
            visible_index += 1
        window_number += 1
    return tabs, window_number


def get_tabs_offline(user_data_dir: Path):
    errors = []
    all_tabs = []
    profiles = []
    next_window = 1

    for profile_dir in profile_dirs(user_data_dir):
        for session_file in newest_session_files(profile_dir):
            try:
                tabs, next_window = tabs_from_session_file(
                    session_file,
                    profile_dir,
                    profile_dir.name,
                    next_window,
                )
            except (OSError, SessionParseError) as e:
                errors.append(f"{session_file}: {e}")
                continue
            if tabs:
                all_tabs.extend(tabs)
                profiles.append({
                    "name": profile_dir.name,
                    "path": str(profile_dir),
                    "source_file": str(session_file),
                    "tab_count": len(tabs),
                })
                break

    if all_tabs or profiles:
        return all_tabs, {"profiles": profiles}, None
    if errors:
        return None, None, "; ".join(errors)
    return None, None, f"no Chromium session files under {user_data_dir}"

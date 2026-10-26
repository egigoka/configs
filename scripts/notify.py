#!/usr/bin/env python3
import sys
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
HOME_SCRIPTS = Path.home() / ".scripts"
if str(HOME_SCRIPTS) != str(HERE):
    sys.path.insert(0, str(HOME_SCRIPTS))

from telegram_secrets import chatid, token


def main():
    text = " ".join(sys.argv[1:]).strip()
    if not text and not sys.stdin.isatty():
        text = sys.stdin.read().strip()
    if not text:
        print(f"usage: {Path(__file__).name} \"message\"", file=sys.stderr)
        sys.exit(2)
    data = urllib.parse.urlencode({"chat_id": chatid, "text": text}).encode()
    req = urllib.request.Request(f"https://api.telegram.org/bot{token}/sendMessage", data=data)
    with urllib.request.urlopen(req, timeout=30) as r:
        if r.status != 200:
            raise SystemExit(f"telegram error: {r.status} {r.read().decode()}")


if __name__ == "__main__":
    main()

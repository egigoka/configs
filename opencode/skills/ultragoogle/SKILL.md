---
name: ultragoogle
description: >
  Google Search loading workflow using Python curl_cffi, a local Camoufox browser server, and Safari fallback.
  Use when user asks to Google/search web results manually, bypass brittle fetches, inspect Google SERP HTML,
  use curl_cffi or Camoufox, or use Safari debug pull.
---

# UltraGoogle

Fetch Google results in this order:

1. `curl_cffi`: fastest and least stateful; keep result when it contains real titles and snippets.
2. Camoufox at `http://localhost:9377`: rendered browser fallback for JavaScript, browser state, or interaction.
3. Safari debug pull: last resort when Camoufox is unavailable or also blocked.

Do not escalate to a browser when `curl_cffi` already returned usable results.

## Trigger

Use for:
- Google Search / SERP retrieval where normal `webfetch` or plain `curl` may fail
- Requests mentioning `ultragoogle`, `curl_cffi`, Camoufox, Google HTML, SERP scraping, Safari debug, Safari pull
- Debugging whether Google returned real results, consent, captcha, bot wall, or JS-only content

Do not use for normal URL fetches where `webfetch` is enough.

## Primary: curl_cffi

First verify `curl_cffi` import:

```bash
python3 -c "import curl_cffi; print(curl_cffi.__version__)"
```

If missing and user asked to enable this workflow, install user-global:

```bash
python3 -m pip install --user --break-system-packages curl_cffi
```

Use Python one-shot, not plain `curl`:

```bash
python3 - <<'PY'
from curl_cffi import requests
from urllib.parse import urlencode

query = "site:example.com search terms"
url = "https://www.google.com/search?" + urlencode({"q": query, "hl": "en", "num": "10"})
headers = {
    "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "accept-language": "en-US,en;q=0.9",
}
response = requests.get(url, headers=headers, impersonate="chrome", timeout=30)
print(response.status_code, response.url)
print(response.text[:20000])
PY
```

Signals request failed as search source:
- HTTP 429/403
- `Our systems have detected unusual traffic`
- `/sorry/`, `recaptcha`, `captcha`
- consent page with little/no result content
- mostly scripts and no visible result titles/snippets

When response is good, extract minimally with stdlib HTML parser or regex against current HTML. Avoid adding parser deps unless needed. Save large HTML to temp file under `/var/folders/r_/_mr22dqn24d31b7460cz8z5m0000gn/T/opencode` if inspection needs repeated passes.

## Fallback 1: Camoufox Server

Use local Camoufox when `curl_cffi` returns a bot/consent wall, rendered JavaScript is required, or search needs browser interaction. Server API documentation is available at `http://localhost:9377/docs/` and `http://localhost:9377/openapi.json`.

Check health first. If unavailable, skip directly to Safari instead of trying to start or reconfigure the service:

```bash
curl --fail --silent --show-error http://localhost:9377/health
```

Create a task-specific tab, navigate with Camoufox's Google macro, then read the accessibility snapshot:

```bash
BASE=http://localhost:9377
USER_ID="ultragoogle-$$"
SESSION_KEY="google-search-$$"

TAB_ID=$(curl --fail --silent --show-error --request POST "$BASE/tabs" \
  --header 'Content-Type: application/json' \
  --data "{\"userId\":\"$USER_ID\",\"sessionKey\":\"$SESSION_KEY\"}" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["tabId"])')

curl --fail --silent --show-error --request POST "$BASE/tabs/$TAB_ID/navigate" \
  --header 'Content-Type: application/json' \
  --data "{\"userId\":\"$USER_ID\",\"macro\":\"@google_search\",\"query\":\"site:example.com search terms\"}"

curl --fail --silent --show-error \
  "$BASE/tabs/$TAB_ID/snapshot?userId=$USER_ID&format=text"

curl --fail --silent --show-error --request DELETE \
  "$BASE/tabs/$TAB_ID?userId=$USER_ID"
```

Use unique `USER_ID` and `SESSION_KEY` values when concurrent tasks could collide. Close tabs after extraction. Prefer accessibility snapshots and `/tabs/{tabId}/links`; use `/tabs/{tabId}/evaluate` only when structured endpoints cannot expose required data.

Apply same failure signals as `curl_cffi`. A rendered captcha, `/sorry/` URL, or unusual-traffic snapshot is not a valid result; continue to Safari.

## Fallback 2: Safari Debug Pull

Use Safari when Camoufox is unavailable, gets a bot wall/consent page, or needs desktop browser state that only Safari has.

Reference implementation: `/Users/egigoka/Developer/slop/deal-tracker/safari-fetch.mjs`.

Prereq: Safari Develop > Allow JavaScript from Apple Events.

Direct command:

```bash
node /Users/egigoka/Developer/slop/deal-tracker/safari-fetch.mjs "https://www.google.com/search?q=example" --html --timeout 30000 --settle 2000
```

Use `--out` for large captures:

```bash
node /Users/egigoka/Developer/slop/deal-tracker/safari-fetch.mjs "https://www.google.com/search?q=example" --html --timeout 30000 --settle 2000 --out /var/folders/r_/_mr22dqn24d31b7460cz8z5m0000gn/T/opencode/google.html
```

If copying pattern inline, use `osascript` to:
- activate Safari
- open/navigate front document
- wait until `document.readyState === "complete"`
- optionally settle 1-3s
- read `document.documentElement.outerHTML` or `document.body.innerText`

## Result Handling

Report concise search findings, not raw HTML. Include source URLs and note method only when relevant:
- `curl_cffi` success
- Camoufox fallback used for rendered browser content
- Safari fallback used because HTTP and Camoufox methods failed

If all methods fail, state exact blocker for each attempted method and preserve shortest diagnostic snippet.

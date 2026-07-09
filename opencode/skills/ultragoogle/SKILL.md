---
name: ultragoogle
description: >
  Google Search fetching workflow using Python curl_cffi first, with Safari AppleScript debugging fallback.
  Use when user asks to Google/search web results manually, bypass brittle fetches, inspect Google SERP HTML,
  use curl_cffi, or use Safari debug pull.
---

# UltraGoogle

Fetch Google results with browser-like HTTP first. If blocked, use Safari rendered DOM pull.

## Trigger

Use for:
- Google Search / SERP retrieval where normal `webfetch` or plain `curl` may fail
- Requests mentioning `ultragoogle`, `curl_cffi`, Google HTML, SERP scraping, Safari debug, Safari pull
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

## Fallback: Safari Debug Pull

Use Safari when `curl_cffi` gets bot wall/consent or page needs real browser state.

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
- Safari fallback used because Google returned bot/consent/JS wall

If both methods fail, state exact blocker and preserve shortest diagnostic snippet.

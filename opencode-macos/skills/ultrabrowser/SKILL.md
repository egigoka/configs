---
name: ultrabrowser
description: >
  General web page loading workflow using webfetch, curl_cffi, a local Camoufox server, and cua-driver browser automation.
  Use when user asks to load, open, inspect, or interact with any URL, especially pages blocked by basic HTTP fetching,
  rendered JavaScript pages, authenticated pages, consent flows, and browser-state-dependent content.
---

# UltraBrowser

Load pages in this order:

1. `webfetch`: public page needing no browser state or interaction.
2. `curl_cffi`: HTTP fetch needs browser impersonation but not rendering.
3. Camoufox at `http://localhost:9377`: isolated rendered page or scripted interaction.
4. Browser through `cua-driver`: existing browser state, GUI interaction, visual inspection, or Camoufox failure.

Stop at first method that returns usable content. Do not launch a browser when a cheaper method already satisfies request.

## Trigger

Use for loading, reading, inspecting, or interacting with any web page. Also use when requests mention `ultrabrowser`, `curl_cffi`, Camoufox, Safari, browser automation, blocked fetches, JavaScript rendering, consent, captcha, or authenticated browser state.

## HTTP Loading

Try `webfetch` first. Escalate when response is blocked, empty, missing rendered content, or needs cookies and browser interaction.

For browser-like HTTP without rendering, verify `curl_cffi` import:

```bash
python3 -c "import curl_cffi; print(curl_cffi.__version__)"
```

Install only when user asked to enable workflow:

```bash
python3 -m pip install --user --break-system-packages curl_cffi
```

Fetch target URL with one-shot Python:

```bash
python3 - <<'PY'
from curl_cffi import requests

url = "https://example.com/page"
response = requests.get(
    url,
    headers={"accept-language": "en-US,en;q=0.9"},
    impersonate="chrome",
    timeout=30,
)
print(response.status_code, response.url)
print(response.text[:20000])
PY
```

Treat HTTP 403/429, challenge pages, consent-only content, captcha, empty bodies, or script shells without requested content as failure. Save large captures under `/var/folders/r_/_mr22dqn24d31b7460cz8z5m0000gn/T/opencode` only when repeated inspection is needed.

## Camoufox

Use local Camoufox when rendering or isolated browser interaction is required. API documentation: `http://localhost:9377/docs/` and `http://localhost:9377/openapi.json`.

Check health first:

```bash
curl --fail --silent --show-error http://localhost:9377/health
```

If unavailable, skip to `cua-driver`; do not start or reconfigure service. Use unique user and session IDs, create task-specific tab, navigate to target URL, read accessibility snapshot or links, then close only tab created by task. Prefer structured endpoints over page evaluation. Confirm current request shape from OpenAPI instead of guessing.

## cua-driver Browser

Use `cua-driver` when page needs existing browser state, GUI interaction, screenshots, or Camoufox cannot load it. Never automate Safari through raw `osascript`, direct activation, or standalone Safari-fetch scripts.

1. Call `cua-driver_start_session` with task-specific session ID.
2. Call `cua-driver_launch_app` with chosen browser bundle ID and target URL in `urls`. Prefer Safari (`com.apple.Safari`) when existing Safari state matters. Use returned PID and window ID; call `cua-driver_list_windows` only when returned windows are missing or ambiguous.
3. Call `cua-driver_get_window_state` to verify page loaded and inspect AX tree plus screenshot.
4. Read content from structured AX elements or tree. Use `cua-driver_page` with `action: "get_text"` when AX output is insufficient, then `query_dom` for missing structure or links.
5. Before each interaction, refresh `cua-driver_get_window_state`. Prefer AX actions by `element_index`; use pixel actions only for surfaces missing from AX tree.
6. After each interaction, refresh state and verify effect. Keep background delivery; escalate one failed action to `delivery_mode: "foreground"` only after screenshot verification.
7. Call `cua-driver_end_session` on success and failure paths.

Safari page extraction may require Develop > Allow JavaScript from Apple Events. If `cua-driver_page` reports setting disabled, continue with AX output or ask before enabling and restarting Safari. Never change browser settings without user confirmation.

Do not close unrelated browser windows or tabs. Leave browser content intact unless task-created disposable window can be identified safely.

## Result Handling

Return requested page content or interaction result, not raw transport output. Include final URL and source links when relevant. Mention loading method only when fallback choice explains limitations. If every method fails, report exact blocker for each attempted method with shortest useful diagnostic.

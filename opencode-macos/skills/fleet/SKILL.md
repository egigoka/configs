---
name: fleet
description: Use when work touches the user's other machines - running jobs or tests on remote Linux hosts, installing builds on the server, Steam Deck, Windows PC or Apple devices, updating agent CLIs on a host, or choosing where a heavy job should run.
---

# Fleet

The user's machines, how to reach them, and what each one is for.
`~/.ssh/config` is the source of truth for host names, users and ports.
Read it before connecting; this file names SSH aliases only.

## Reaching a host

- Keys in `~/.ssh/config` default paths are locked. Unlocked copies live in
  `~/.ssh/.unlocked/id_ed25519_<key>`. List that directory to see what is
  usable now; a missing key means the user has not unlocked it.
- Connect with
  `ssh -o BatchMode=yes -o IdentitiesOnly=yes -i ~/.ssh/.unlocked/id_ed25519_<key> <alias>`.
- Never read, print, copy or move a key file. Only pass it to `ssh -i`.
- Login shells are fish. Pipe scripts into `bash -s` and keep them ASCII:
  `ssh ... <alias> 'bash -s' < script.sh`.
- Each host has variants by network: `<name>t` is Tailscale, `<name>w` is
  WireGuard, `<name>local` is the home LAN. Try `t` first when away from home.
- A host that times out or reports "No route to host" is offline. Report it
  and skip it; do not retry in a loop.

## Hosts

| Alias | Key | Role |
| --- | --- | --- |
| `hetzner` | `hetzner` | Production server. No free RAM for jobs. Deploys only. |
| `hostingby` | `hostingby` | x86, 6 CPUs, 10G. Shared heavy-job host; ask its current owner first. One heavy job at a time. |
| `oracle` | `oracle` | Oracle Linux aarch64, 4 CPUs, 17G. Good for parallel Linux jobs. Arm, so x86-only binaries fail. |
| `steamdeckt` / `steamdecklocal` | `steamdeck` | Steam Deck, SteamOS. Light jobs only. Desktop app installs. |
| `proxmoxt` / `proxmoxlocal` | `proxmox` | Hypervisor. Light jobs only. |
| `beyondt` / `beyondlocal` | `beyond` | Dev host, no free RAM for jobs. |
| `workt` / `workw` | `work` | Arch under WSL2. Unstable: the VM restarts under load. Never run tests or builds there. |
| `oyanlocal` | `oyan` | Windows PC reached through WSL. Home LAN only. |
| `17t` | `work` | Second alias for the work host; same rules as `workt`. |

There is no other macOS machine. Apple builds and macOS-only tests stay local.

## Agent CLIs per host

Each host installs opencode, codex and claude differently. Use that host's
method; another host's method breaks it.

- `steamdeck*`: standalone binaries in `~/.local/bin`. Update codex with
  `codex update`, not npm.
- `beyondt` and `oracle`: opencode from the `egigoka/opencode` fork installer
  (`curl -fsSL https://github.com/egigoka/opencode/releases/latest/download/install.sh | bash`),
  codex via npm, claude via `curl -fsSL https://claude.ai/install.sh | bash`.
  `beyondt` needs both `sudo npm i -g` and user `npm i -g` for codex.
- `workt`: npm. `/root/.npmrc` sets a user prefix, so update the system codex
  with `sudo npm i -g --prefix /usr`.

Verify with `opencode --version; codex --version; claude --version; which opencode codex claude`.

## Apple devices

- This Mac: 16 GB RAM. Run at most one iOS simulator job and one Android
  job (Gradle or emulator) at once, never two of the same kind. Pause new
  heavy work when free memory drops below 20%.
- iPhone "17" and Apple Watch: physical devices. Check with
  `xcrun devicectl list devices`. Use them only when the user asks for an
  install on that device. "unavailable" means locked or out of range; skip.

## Placing work

1. Apple work: local, within the Mac limits above.
2. Linux-capable heavy work: `oracle`, then `hostingby` with permission.
3. Light checks: `steamdeckt` or `proxmoxt`.
4. Never `workt`, `hetzner` or `beyondt` for jobs.

Remote hosts start without Java or an Android SDK. Install toolchains in the
home directory, never system-wide. Results from Linux do not cover
macOS-only tests.

## Installing releases

Pomodorough releases install through
`pomodorough-helpers/scripts/install_everywhere.py` in the pomodorough tree:

```
python3 pomodorough-helpers/scripts/install_everywhere.py --target server --target mac --json
```

Targets: `server` (`hetzner`), `mac`, `iphone`, `android` (local emulator
only), `deck` (`steamdecklocal`), `windows` (`oyanlocal`). Each remote target
backs up the previous install before swapping. Report every skipped target
and why.

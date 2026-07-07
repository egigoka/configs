# Patched opencode-snip

Local install for <https://github.com/VincentHardouin/opencode-snip/pull/14> until upstream merges.

Pinned PR head:

`lenucksi/opencode-snip@bdb44108b2c1b26c27f9101c3dc56a2bcbdbf719`

`setup.sh` installs it into opencode's plugin cache:

`~/.cache/opencode/packages/opencode-snip@latest/node_modules/opencode-snip/src/index.ts`

## Behavior

- Uses `snip check -- <command>` to decide if command has snip filter.
- Wraps supported commands with `snip run --`.
- Leaves unsupported commands unchanged.
- Checks each pipeline/compound segment independently.
- Avoids double-prefixing segments already starting with `snip`.
- Disables itself if `snip check/run` subcommands are missing.
- Adds system instruction telling agents not to add `snip run --` manually.

## Verified

- `git status --short` -> `snip run -- git status --short`
- `git log -1` -> `snip run -- git log -1`
- `true` -> `true`
- `node --version` -> `node --version`
- `git status --short && true && node --version` -> `snip run -- git status --short && true && node --version`

Raw checks:

- `snip check -- git status` -> `filter: git-status`
- `snip check -- true` -> `no filter`
- `snip check -- node --version` -> `no filter`

Package test passed:

`snip npm test`

Restart opencode after patching so plugin reloads.

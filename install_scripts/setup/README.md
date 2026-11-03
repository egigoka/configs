# Setup modules

`setup.sh` is the entry point. It loads source-only modules, detects the host, and reports progress for each phase.

## Execution order

1. `initialize_setup_context`
2. `prepare_host_packages`
3. `setup_platform_prerequisites`
4. `install_agent_tools`
5. `setup_platform_integrations`
6. `setup_cli_configs`
7. `setup_macos_integrations`
8. `setup_agent_configs`
9. `setup_file_listing_config`
10. `setup_desktop_configs`
11. Replace the setup process with Fish

`install_agent_tools` overlaps three independent workers with foreground OpenCode and CUA driver installation. One worker updates local plugin builds and Usage. Another updates Graphify, SwiftUI, and Caveman. The third refreshes Unslop, selected agent skills, and Apple skills. Global npm and system package installs remain sequential. Usage installs once per run.

OpenCode skips reinstallation when its installed version matches the latest release and `opencode run --help` succeeds. Failed version lookups or CLI checks fall back to the installer.

Mobile MCP, XcodeBuildMCP, and REA check npm for the latest version on every run. Matching versions skip installation only when their declared commands still point to executable files in the installed package. Changed versions, missing commands, unreadable package metadata, and failed registry checks use the normal npm installer. REA still registers every client on every run.

The Codex auth fork and V2 plugins fetch upstream changes on every run. Successful builds are cached in each checkout's Git metadata. Unchanged checkouts skip `npm ci`, builds, and V2 tests when their dependencies and `dist/index.js` still exist. Changes to the revision, Node version, platform, architecture, npm version, `NODE_ENV`, or build recipe invalidate the cache. V2 plugins also track the Bun version. Every rebuild removes the previous success marker before it starts.

Graphify and CUA driver release checks prefer authenticated `gh` requests, then fall back to anonymous HTTP. If release metadata is unavailable, setup retains working installed binaries. Missing binaries still fail with a clear error. Failed HTTP responses never reach the JSON parser.

Graphify installs use standard CPython 3.13 for compatibility with its native tree-sitter dependencies. This overrides uv's default interpreter, which may be a newer or free-threaded build. uv downloads a compatible interpreter if needed.

Agent configuration waits for all tool and skill workers to finish. Only Caveman writes agent configuration during this group. Standalone `setup_agent_configs` calls still refresh shared skills before changing configuration.

Caveman keeps a source checkout under `${XDG_CACHE_HOME:-$HOME/.cache}/configs/caveman` and fetches upstream HEAD on every run. Its OpenCode installer runs directly with Node and repairs vendored assets even when upstream is unchanged. Failed checkout refreshes or installer runs fall back to the npm installer. Local configuration and the custom plugin server remain preserved.

Fontconfig checks its own cache validity on every run and rebuilds stale font caches without forcing a rescan of unchanged fonts.

Claude MCP setup reads existing user registrations from `~/.claude.json` once. Missing or malformed entries, unreadable configurations, and custom `CLAUDE_CONFIG_DIR` settings fall back to `claude mcp get`. This preserves project and local scope checks before adding a user registration.

`setup.sh --codex-only` stops after `configure_codex`.

## Progress and concurrency

Terminals show a colored progress bar, completed phase counts, and elapsed time. Parallel groups show their own task counts and a spinner while waiting. Redirected output uses plain lines. `NO_COLOR=1` disables color, and `TERM=dumb` disables terminal animation.

`SETUP_JOBS` limits concurrent tasks, including the foreground task. The default is 4, and values above 32 use 32. `SETUP_JOBS=1 ./setup.sh` runs tasks sequentially.

Foreground commands keep their output and terminal input. Background tasks save output in a private temporary directory printed at startup. Failed tasks print their logs and stop the group. Cancellation stops worker process groups, including child installers. Logs remain available after setup exits.

Background plugin builds disable Git and SSH prompts. Failed builds retry in the foreground after workers finish, using the caller's original credentials and terminal input. Sequential mode runs builds directly in the foreground. Update checks still contact upstream on every run.

Homebrew package checks share an inventory cache for each run. Cache misses still resolve aliases through Homebrew. Normal absolute paths use Bash string operations to calculate relative symlink targets. Paths with dot segments, repeated separators, or relative destination parents use Python for normalization. Existing relative symlinks skip Python when they already point to the source. Agent-link loops extract filenames in Bash.

Agent link sets check current relative symlinks together in one Python process. Missing or changed links use the same backup and repair rules as individual links. Results apply only to that call; every run checks links again.

Mutable Linux hosts check installed commands before querying package aliases. Package providers vary by distribution: `coreutils` supplies `dircolors`, `psmisc` supplies `pstree`, and Arch supplies `gh` through `github-cli`. Setup installs CUA's XInput and xkbcommon runtime libraries, `jq`, and the `zstd` extractor when needed. Rocky uses Starship's official installer because its default repositories lack the package. Required prerequisite failures stop setup.

Fish configures command paths for interactive and noninteractive sessions so SSH commands can find user-installed tools and Nix profiles.

Fisher adopts byte-identical vendored plugin files. Conflicting local edits remain untouched and stop setup. Failed downloads and extraction also return failure instead of silently skipping plugins. Fetch workers skip Fish startup configuration.

## Files

- `core.sh` detects the host and provides `install_link`.
- `progress.sh` reports progress and runs independent tasks with a concurrency limit.
- `../github_release.sh` fetches and validates GitHub release metadata.
- `../node_build.sh` caches successful Node builds by revision, runtime, and recipe.
- `../npm_packages.sh` checks global CLI versions and command files before reinstalling npm packages.
- `packages.sh` detects and installs command-line packages.
- `agents.sh` loads agent-specific modules and exposes the common agent-tool phase.
- `platforms.sh` dispatches platform prerequisite and integration phases.
- `platform-steamos.sh` orders the SteamOS modules under `steamos/`.
- `platform-nixos.sh` configures NixOS prerequisites.
- `platform-standard.sh` configures macOS and mutable Linux prerequisites.
- `user-config.sh` loads focused modules under `user/` for CLI, macOS, Git, and desktop configuration.

## Shared state

The orchestrator initializes these variables before running any task:

- `CONFIGS_DIR`
- `SETUP_DIR`
- `SETUP_OS`
- `SETUP_PLATFORM`
- `OPENCODE_CONFIG_DIR`
- `USER`

Modules resolve their own child-module paths from `BASH_SOURCE`; they do not rely on the caller's current directory. Loading modules only defines functions. System changes begin when the orchestrator calls those functions.

## Intentional hardening

- Unsupported hosts return a nonzero status instead of printing an error and accidentally exiting successfully.
- The quarter-window helper uses `CONFIGS_DIR` instead of assuming the checkout is always at `~/configs`.
- Required skill-updater failures stop setup before it launches Fish.

## Validation

`python3 -m unittest discover -s install_scripts/tests -v` checks scheduling, cancellation, progress output, package caching, symlink targets, build-cache invalidation, and release-lookup failures. Installer tests use temporary Git checkouts and local command stubs. Tests do not install packages or change the user's configuration.

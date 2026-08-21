# Setup modules

`setup.sh` is the entry point. It loads source-only modules, detects the host, and calls their public functions in order.

## Execution order

1. `initialize_setup_context`
2. `prepare_host_packages`
3. `setup_platform_prerequisites`
4. `install_agent_tools`
5. `setup_platform_integrations`
6. `install_usage`
7. `setup_cli_configs`
8. `setup_macos_integrations`
9. `setup_agent_configs`
10. `setup_file_listing_config`
11. `setup_desktop_configs`
12. Replace the setup process with Fish

This split keeps OpenCode and Usage installation visible as a common phase while preserving its original position between each platform's package setup and later Git or SteamOS integration work.

`setup.sh --codex-only` stops after `configure_codex`.

## Files

- `core.sh` detects the host and provides `install_link`.
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

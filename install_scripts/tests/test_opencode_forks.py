#!/usr/bin/env python3

import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SETUP = ROOT / "install_scripts/setup/agents/opencode.sh"
CONFIG_DIRS = [ROOT / "opencode-macos", ROOT / "opencode-other", ROOT / "opencode-steamos"]


class OpenCodeForkSetupTests(unittest.TestCase):
    def test_setup_does_not_install_legacy_multi_auth_fork(self) -> None:
        source = SETUP.read_text()
        self.assertNotIn("install_opencode_openai_multi_auth_fork", source)
        self.assertNotIn("opencode-openai-multi-auth.git", source)
        self.assertNotIn(".local/share/opencode-openai-multi-auth", source)

    def test_configs_do_not_load_legacy_multi_auth_fork(self) -> None:
        for config_dir in CONFIG_DIRS:
            config = (config_dir / "opencode.json").read_text()
            self.assertNotIn("openai-multi-auth-fork", config)
            self.assertNotIn("opencode-openai-multi-auth-v2", config)
            self.assertFalse((config_dir / "plugins/openai-multi-auth-fork.js").exists())
            self.assertFalse((config_dir / "v2-plugins/opencode-openai-multi-auth-v2").exists())
            self.assertFalse((config_dir / "cli-plugins/opencode-openai-multi-auth-v2").exists())

    def test_setup_installs_and_builds_codex_auth_fork(self) -> None:
        source = SETUP.read_text()
        self.assertIn("install_opencode_codex_auth_fork()", source)
        self.assertIn("https://github.com/egigoka/opencode-codex-auth.git", source)
        self.assertIn('checkout="$HOME/.local/share/opencode-codex-auth"', source)
        self.assertIn("install_opencode_codex_auth_fork || return", source)

    def test_configs_load_codex_auth_v2_port_and_preserve_kilo(self) -> None:
        import json
        for config_dir in CONFIG_DIRS:
            config = json.loads((config_dir / "opencode.json").read_text())
            self.assertNotIn("plugin", config)
            self.assertIn("./v2-plugins/opencode-codex-auth", config["plugins"])
            shim = (config_dir / "v2-plugins/opencode-codex-auth/server.js").read_text()
            self.assertIn("homedir()", shim)
            self.assertIn("opencode-v2-plugins/opencode-codex-auth/server.js", shim)
            cli_shim = (config_dir / "cli-plugins/opencode-codex-auth/index.js").read_text()
            self.assertIn("opencode-v2-plugins/opencode-codex-auth/tui/index.js", cli_shim)
            kilo = ROOT / config_dir.name.replace("opencode-", "kilo-")
            self.assertIn("./plugins/codex-auth-fork.js", json.loads((kilo / "opencode.json").read_text())["plugin"])
            self.assertTrue((kilo / "plugins/codex-auth-fork.js").exists())
            self.assertFalse((kilo / "plugins/codex-auth-release.js").exists())

    def test_fish_caches_generated_integrations_and_avoids_local_pstree(self) -> None:
        config = (ROOT / "fish/config.fish").read_text()
        helper = (ROOT / "fish/functions/__cached_command_init.fish").read_text()

        self.assertIn("__cached_command_init starship starship init fish", config)
        self.assertIn("__cached_command_init fzf fzf --fish", config)
        self.assertIn("__cached_command_init pay-respects pay-respects fish --alias fuck", config)
        self.assertNotIn("starship init fish | source", config)
        self.assertNotIn("fzf --fish | source", config)
        self.assertIn("set -l _platform (uname -s)", config)
        self.assertIn("set -q SUDO_USER; and pstree", config)
        self.assertIn("command mktemp", helper)
        self.assertIn("command mv", helper)
        self.assertIn("source $cache_file", helper)


if __name__ == "__main__":
    unittest.main()

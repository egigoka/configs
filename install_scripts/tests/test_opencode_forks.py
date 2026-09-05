#!/usr/bin/env python3

import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SETUP = ROOT / "install_scripts/setup/agents/opencode.sh"
CONFIG_DIRS = [ROOT / "opencode-macos", ROOT / "opencode-other", ROOT / "opencode-steamos"]


class OpenCodeForkSetupTests(unittest.TestCase):
    def test_setup_installs_and_builds_codex_auth_fork(self) -> None:
        source = SETUP.read_text()
        self.assertIn("install_opencode_codex_auth_fork()", source)
        self.assertIn("https://github.com/egigoka/opencode-codex-auth.git", source)
        self.assertIn('checkout="$HOME/.local/share/opencode-codex-auth"', source)
        self.assertIn('npm ci', source)
        self.assertIn('npm run build', source)
        self.assertIn("install_opencode_codex_auth_fork || return", source)

    def test_configs_load_the_built_fork_through_portable_shim(self) -> None:
        for config_dir in CONFIG_DIRS:
            config = (config_dir / "opencode.json").read_text()
            self.assertIn('"./plugins/codex-auth-fork.js"', config)
            self.assertNotIn('"@iam-brain/opencode-codex-auth@latest"', config)
            shim = (config_dir / "plugins/codex-auth-fork.js").read_text()
            self.assertIn('homedir()', shim)
            self.assertIn('".local", "share", "opencode-codex-auth", "dist", "index.js"', shim)
            self.assertIn("OpenAIMultiAuthPlugin", shim)
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

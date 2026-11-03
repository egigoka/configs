#!/usr/bin/env python3
import os
import pathlib
import subprocess
import tempfile
import unittest

MODULE = pathlib.Path(__file__).resolve().parents[1] / "setup/user/macos.sh"


class LaunchdCleanupTests(unittest.TestCase):
    def run_setup(self, scenario):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "scripts").mkdir()
            (root / "mac").mkdir()
            (root / "scripts/clean-unlocked-ssh-keys.sh").write_text("original script")
            (root / "mac/com.egigoka.clean-unlocked-ssh-keys.plist").write_text("original plist")
            result = subprocess.run(
                ["/bin/bash", "-c", f'''
                    source "{MODULE}"
                    CONFIGS_DIR=$HOME
                    uname() {{ echo Darwin; }}
                    install_link() {{ :; }}
                    launchctl() {{
                        case "$1" in
                            load) return 0 ;;
                            print) test -f "$HOME/loaded" ;;
                            bootout) echo bootout; rm -f "$HOME/loaded" ;;
                            bootstrap)
                                echo bootstrap
                                [ "${{FAIL_BOOTSTRAP:-0}}" = 0 ] || return 23
                                touch "$HOME/loaded"
                                ;;
                        esac
                    }}
                    {scenario}
                '''],
                env=dict(os.environ, HOME=directory),
                text=True, capture_output=True, timeout=5,
            )
            return result

    def assert_reloads(self, scenario, count):
        result = self.run_setup(scenario)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["bootout", "bootstrap"] * count)

    def test_unchanged_rerun_does_not_reload(self):
        self.assert_reloads("setup_macos_integrations && setup_macos_integrations", 1)

    def test_script_or_plist_change_reloads(self):
        for file in ("scripts/clean-unlocked-ssh-keys.sh", "mac/com.egigoka.clean-unlocked-ssh-keys.plist"):
            with self.subTest(file=file):
                self.assert_reloads(f'''
                    setup_macos_integrations || exit
                    echo changed >> "$HOME/{file}"
                    setup_macos_integrations
                ''', 2)

    def test_unloaded_service_is_loaded_again(self):
        self.assert_reloads('''
            setup_macos_integrations || exit
            rm "$HOME/loaded"
            setup_macos_integrations
        ''', 2)

    def test_failed_bootstrap_does_not_save_hashes(self):
        self.assert_reloads('''
            FAIL_BOOTSTRAP=1
            setup_macos_integrations
            test "$?" = 23 || exit 1
            test ! -f "$HOME/.local/state/configs/launchd/com.egigoka.clean-unlocked-ssh-keys.sha256" || exit 1
            FAIL_BOOTSTRAP=0
            setup_macos_integrations
        ''', 2)


if __name__ == "__main__":
    unittest.main()

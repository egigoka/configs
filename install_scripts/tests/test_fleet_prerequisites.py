#!/usr/bin/env python3
import os
import pathlib
import subprocess
import tempfile
import unittest

MODULE = pathlib.Path(__file__).resolve().parents[1] / "setup/packages.sh"


class FleetPrerequisiteTests(unittest.TestCase):
    def run_shell(self, script):
        with tempfile.TemporaryDirectory() as directory:
            return subprocess.run(
                ["/bin/bash", "-c", f'source "{MODULE}"\n' + script],
                env=dict(os.environ, TMPDIR=directory, HOME=directory),
                text=True, capture_output=True, timeout=5,
            )

    def test_cua_dependencies_use_distribution_package_names(self):
        result = self.run_shell("""
            install_if_missing() { printf '%s: %s\\n' "$ID" "$*"; }
            SETUP_OS=Linux
            for ID in debian arch opensuse-tumbleweed rocky; do
                install_cua_runtime_packages || exit
            done
        """)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "debian: libxi6 libxkbcommon0",
            "arch: libxi libxkbcommon",
            "opensuse-tumbleweed: libXi6 libxkbcommon0",
            "rocky: libXi libxkbcommon",
        ])

    def test_cua_dependency_install_failure_propagates(self):
        result = self.run_shell("""
            SETUP_OS=Linux ID=debian
            install_if_missing() { return 27; }
            install_cua_runtime_packages
        """)
        self.assertEqual(result.returncode, 27)

    def test_starship_download_failure_does_not_run_partial_script(self):
        result = self.run_shell("""
            ID=rocky
            command() {
                if [ "$*" = "-v starship" ]; then return 1; fi
                builtin command "$@"
            }
            install_if_missing() { echo unexpected-package-install; return 91; }
            curl() {
                printf 'echo partial-script-ran\\n' >"${@: -1}"
                return 42
            }
            install_starship
            result=$?
            test -z "$(find "$TMPDIR" -maxdepth 1 -type f)" || exit 90
            exit "$result"
        """)
        self.assertEqual(result.returncode, 42, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_starship_installer_failure_propagates_and_cleans_up(self):
        result = self.run_shell("""
            ID=rocky
            command() {
                if [ "$*" = "-v starship" ]; then return 1; fi
                builtin command "$@"
            }
            curl() {
                printf 'printf "args: %%s\\\\n" "$*"\\nexit 23\\n' >"${@: -1}"
            }
            install_starship
            result=$?
            test -z "$(find "$TMPDIR" -maxdepth 1 -type f)" || exit 90
            exit "$result"
        """)
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertIn("--yes --bin-dir", result.stdout)

    def test_wireguard_accepts_passwordless_sudo_without_validation(self):
        network = MODULE.parent / "steamos/network.sh"
        result = self.run_shell(f'''
            source "{network}"
            CONFIGS_DIR="$HOME"
            sudo() {{
                printf 'sudo %s\\n' "$*"
                [ "$*" = '-n true' ]
            }}
            setup_steamos_wireguard
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("private key not on this machine", result.stderr)
        self.assertIn("sudo -n true", result.stdout)
        self.assertNotIn("sudo -v", result.stdout)

    def test_wireguard_falls_back_to_sudo_validation(self):
        network = MODULE.parent / "steamos/network.sh"
        result = self.run_shell(f'''
            source "{network}"
            CONFIGS_DIR="$HOME"
            sudo() {{
                printf 'sudo %s\\n' "$*"
                [ "$*" = '-v' ]
            }}
            setup_steamos_wireguard
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("private key not on this machine", result.stderr)
        self.assertIn("sudo -v", result.stdout)


if __name__ == "__main__":
    unittest.main()

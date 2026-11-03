#!/usr/bin/env python3
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("fish"), "Fish is required")
class FisherInstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name).resolve()
        self.config = self.directory / "xdg/fish"
        self.plugin = self.directory / "plugin"
        (self.config / "functions").mkdir(parents=True)
        (self.plugin / "functions").mkdir(parents=True)
        self.plugin_file = self.plugin / "functions/fleet_fixture.fish"
        self.target = self.config / "functions/fleet_fixture.fish"
        self.plugin_file.write_text("function fleet_fixture; echo upstream; end\n")

    def install(self, plugin=None, extra_path=""):
        script = f'''
            source "{ROOT}/install_scripts/install_fisher.fish"
            fisher install "{plugin or self.plugin}"
        '''
        return subprocess.run(
            ["fish", "--no-config", "-c", script],
            env=dict(os.environ, HOME=str(self.directory),
                     XDG_CONFIG_HOME=str(self.directory / "xdg"),
                     PATH=extra_path + os.environ["PATH"]),
            text=True, capture_output=True, timeout=8,
        )

    def test_identical_unmanaged_file_is_adopted(self):
        self.target.write_bytes(self.plugin_file.read_bytes())
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Cannot install", result.stderr)
        self.assertIn("~/plugin", (self.config / "fish_plugins").read_text())
        self.assertEqual(self.target.read_bytes(), self.plugin_file.read_bytes())

    def test_conflicting_local_edit_is_preserved_and_fails(self):
        self.target.write_text("function fleet_fixture; echo local; end\n")
        result = self.install()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Cannot install", result.stderr)
        self.assertIn("echo local", self.target.read_text())

    def test_failed_download_returns_failure(self):
        binary_dir = self.directory / "bin"
        binary_dir.mkdir()
        curl = binary_dir / "curl"
        curl.write_text("#!/bin/sh\nexit 22\n")
        curl.chmod(0o755)
        result = self.install("invalid/fleet-fixture", str(binary_dir) + ":")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Invalid plugin name or host unavailable", result.stderr)


if __name__ == "__main__":
    unittest.main()

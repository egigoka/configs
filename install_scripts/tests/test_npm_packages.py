#!/usr/bin/env python3

import json
import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class NpmPackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.binaries = self.directory / "bin"
        self.binaries.mkdir()
        self.packages = self.directory / "node_modules"
        self.trace = self.directory / "trace"
        self.environment = dict(
            os.environ, PATH=f"{self.binaries}:{os.environ['PATH']}",
            TEST_ROOT=str(self.packages), TEST_TRACE=str(self.trace),
        )
        npm = self.binaries / "npm"
        npm.write_text('''#!/bin/bash
echo "$*" >>"$TEST_TRACE"
case "$1" in
  root) [ "${TEST_ROOT_FAIL:-0}" = 0 ] || exit 1; echo "$TEST_ROOT" ;;
  view) [ "${TEST_VIEW_FAIL:-0}" = 0 ] || exit 1; echo 2.0.0 ;;
  install) exit "${TEST_INSTALL_FAIL:-0}" ;;
  *) exit 99 ;;
esac
''')
        npm.chmod(0o755)

    def install_fixture(self, name="@scope/tool", version="2.0.0", string_bin=False):
        package = self.packages / name
        package.mkdir(parents=True)
        target = package / "cli.js"
        target.write_text("#!/bin/sh\nexit 0\n")
        target.chmod(0o755)
        command = name.split("/")[-1]
        (self.binaries / command).symlink_to(target)
        metadata = {"version": version, "bin": "cli.js" if string_bin else {command: "cli.js"}}
        (package / "package.json").write_text(json.dumps(metadata))
        return package

    def run_helper(self, *packages):
        return subprocess.run(
            ["/bin/bash", "-c", f'set -euo pipefail\nsource "{ROOT}/install_scripts/npm_packages.sh"\n'
             'install_latest_npm_packages "$@"', "test", *packages],
            env=self.environment, text=True, capture_output=True, timeout=5,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)

    def installs(self):
        return [line for line in self.trace.read_text().splitlines() if line.startswith("install ")]

    def test_current_scoped_and_unscoped_packages_skip_but_check_registry(self):
        self.install_fixture()
        self.install_fixture("other", string_bin=True)
        result = self.run_helper("@scope/tool", "other")
        self.assert_success(result)
        self.assertEqual(self.installs(), [])
        self.assertEqual(result.stdout.count("skipping installation"), 2)
        self.assertIn("view @scope/tool@latest version", self.trace.read_text())
        self.assertIn("view other@latest version", self.trace.read_text())

    def test_only_pending_packages_install_in_one_command(self):
        self.install_fixture()
        self.install_fixture("old", version="1.0.0")
        self.assert_success(self.run_helper("@scope/tool", "old", "missing"))
        self.assertEqual(self.installs(), ["install --global old@latest missing@latest"])

    def test_missing_command_target_or_execute_permission_reinstalls(self):
        package = self.install_fixture()
        command = self.binaries / "tool"
        command.unlink()
        self.assert_success(self.run_helper("@scope/tool"))
        command.symlink_to(package / "cli.js")
        (package / "cli.js").chmod(0o644)
        self.assert_success(self.run_helper("@scope/tool"))
        (package / "cli.js").unlink()
        self.assert_success(self.run_helper("@scope/tool"))
        self.assertEqual(len(self.installs()), 3)

    def test_command_from_different_installation_reinstalls(self):
        self.install_fixture()
        command = self.binaries / "tool"
        command.unlink()
        command.write_text("#!/bin/sh\nexit 0\n")
        command.chmod(0o755)
        self.assert_success(self.run_helper("@scope/tool"))
        self.assertEqual(len(self.installs()), 1)

    def test_unreadable_metadata_and_registry_or_root_failure_reinstall(self):
        package = self.install_fixture()
        for metadata in ("invalid json", "[]", '{"version": "2.0.0"}'):
            with self.subTest(metadata=metadata):
                (package / "package.json").write_text(metadata)
                self.assert_success(self.run_helper("@scope/tool"))
        for failure in ("TEST_VIEW_FAIL", "TEST_ROOT_FAIL"):
            self.environment[failure] = "1"
            self.assert_success(self.run_helper("@scope/tool"))
            self.environment.pop(failure)
        self.assertEqual(len(self.installs()), 5)

    def test_install_failure_propagates(self):
        self.environment["TEST_INSTALL_FAIL"] = "17"
        result = self.run_helper("missing")
        self.assertEqual(result.returncode, 17, result.stderr)


if __name__ == "__main__":
    unittest.main()

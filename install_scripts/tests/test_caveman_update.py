#!/usr/bin/env python3

import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "install_scripts/update_caveman.sh"
REPOSITORY = "https://github.com/JuliusBrussee/caveman.git"


class CavemanUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.remote = self.directory / "upstream"
        self.remote.mkdir()
        self.destination = self.directory / "opencode"
        (self.destination / "plugins/caveman").mkdir(parents=True)
        (self.destination / "opencode.json").write_text("custom config\n")
        (self.destination / "plugins/caveman/server.js").write_text("custom server\n")
        self.binaries = self.directory / "bin"
        self.binaries.mkdir()
        self.trace = self.directory / "trace"
        self.checkout = self.directory / "cache/configs/caveman"
        config = self.directory / "gitconfig"
        config.write_text(f'[url "{self.remote.as_uri()}"]\n\tinsteadOf = {REPOSITORY}\n')
        self.environment = dict(
            os.environ, HOME=str(self.directory), XDG_CACHE_HOME=str(self.directory / "cache"),
            PATH=f"{self.binaries}:{os.environ['PATH']}", TEST_TRACE=str(self.trace),
            TEST_REAL_GIT=shutil.which("git"), GIT_CONFIG_GLOBAL=str(config),
            GIT_CONFIG_NOSYSTEM="1", GIT_AUTHOR_NAME="Setup Test",
            GIT_AUTHOR_EMAIL="setup@example.invalid", GIT_COMMITTER_NAME="Setup Test",
            GIT_COMMITTER_EMAIL="setup@example.invalid",
        )
        self.git("init", "-q", str(self.remote))
        installer = self.remote / "installer/install.js"
        installer.parent.mkdir()
        installer.write_text('''const fs = require('fs');
const path = require('path');
const target = path.join(process.env.XDG_CONFIG_HOME, 'opencode');
fs.appendFileSync(process.env.TEST_TRACE, 'installer\\n');
fs.writeFileSync(path.join(target, 'opencode.json'), 'upstream config');
fs.writeFileSync(path.join(target, 'plugins/caveman/server.js'), 'upstream server');
fs.writeFileSync(path.join(target, 'asset'), fs.readFileSync(path.join(__dirname, '../asset')));
fs.writeFileSync(path.join(target, 'AGENTS.md'), 'generated rules');
if (process.env.TEST_INSTALL_FAIL) process.exit(17);
''')
        self.commit("first")
        self.stub("git", '''echo "git $*" >>"$TEST_TRACE"
if [ "${TEST_FETCH_FAIL:-0}" = 1 ] && [ "${3:-}" = fetch ]; then exit 18; fi
exec "$TEST_REAL_GIT" "$@"
''')
        self.stub("npx", 'echo "npx $*" >>"$TEST_TRACE"\nexit "${TEST_NPX_STATUS:-0}"\n')

    def stub(self, name, body):
        binary = self.binaries / name
        binary.write_text("#!/bin/bash\n" + body)
        binary.chmod(0o755)

    def git(self, *arguments):
        return subprocess.run(
            [self.environment["TEST_REAL_GIT"], *arguments], env=self.environment,
            check=True, capture_output=True, text=True, timeout=5,
        ).stdout.strip()

    def commit(self, content):
        (self.remote / "asset").write_text(content)
        self.git("-C", str(self.remote), "add", ".")
        self.git("-C", str(self.remote), "commit", "-qm", content)

    def update(self):
        result = subprocess.run(
            ["/bin/bash", str(SCRIPT), str(self.destination)], env=self.environment,
            capture_output=True, text=True, timeout=8,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.destination / "opencode.json").read_text(), "custom config\n")
        self.assertEqual((self.destination / "plugins/caveman/server.js").read_text(), "custom server\n")
        return result

    def test_current_source_still_fetches_and_repairs_missing_assets(self):
        self.update()
        (self.destination / "asset").unlink()
        self.update()
        trace = self.trace.read_text()
        self.assertEqual(trace.count("git clone "), 1)
        self.assertEqual(trace.count(" fetch --depth=1 origin HEAD"), 1)
        self.assertEqual(trace.splitlines().count("installer"), 2)
        self.assertNotIn("npx ", trace)
        self.assertEqual((self.destination / "asset").read_text(), "first")
        self.assertFalse((self.destination / "AGENTS.md").exists())

    def test_upstream_revision_changes_refresh_assets(self):
        self.update()
        self.commit("second")
        self.update()
        self.assertEqual((self.destination / "asset").read_text(), "second")

    def test_fetch_failure_falls_back_to_npx(self):
        self.update()
        self.environment["TEST_FETCH_FAIL"] = "1"
        result = self.update()
        self.assertIn("falling back to npx", result.stderr)
        self.assertIn("npx -y --allow-git=root github:JuliusBrussee/caveman -- --only opencode --force --non-interactive", self.trace.read_text())

    def test_dirty_checkout_and_wrong_origin_remain_untouched(self):
        self.update()
        (self.checkout / "asset").write_text("local edit")
        self.update()
        self.assertEqual((self.checkout / "asset").read_text(), "local edit")
        self.git("-C", str(self.checkout), "checkout", "--", "asset")
        self.git("-C", str(self.checkout), "remote", "set-url", "origin", "https://example.invalid/foreign")
        self.update()
        self.assertEqual(self.trace.read_text().count("npx "), 2)

    def test_non_checkout_cache_is_preserved(self):
        self.checkout.mkdir(parents=True)
        (self.checkout / "keep").write_text("keep")
        self.update()
        self.assertEqual((self.checkout / "keep").read_text(), "keep")
        self.assertIn("npx ", self.trace.read_text())

    def test_installer_failure_restores_custom_files(self):
        self.environment.update(TEST_INSTALL_FAIL="1", TEST_NPX_STATUS="17")
        result = self.update()
        self.assertIn("caveman update failed", result.stderr)
        self.assertIn("falling back to npx", result.stderr)
        self.assertIn("npx ", self.trace.read_text())


if __name__ == "__main__":
    unittest.main()

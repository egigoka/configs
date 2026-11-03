#!/usr/bin/env python3

import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "install_scripts"


class NodeBuildCacheTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.checkout = self.directory / "plugin"
        self.checkout.mkdir()
        self.binaries = self.directory / "bin"
        self.binaries.mkdir()
        self.trace = self.directory / "trace"
        self.environment = dict(
            os.environ, PATH=f"{self.binaries}:{os.environ['PATH']}",
            TEST_TRACE=str(self.trace), TEST_NODE_VERSION="node-1", TEST_NPM_VERSION="npm-1",
            GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
            GIT_AUTHOR_NAME="Setup Test", GIT_AUTHOR_EMAIL="setup@example.invalid",
            GIT_COMMITTER_NAME="Setup Test", GIT_COMMITTER_EMAIL="setup@example.invalid",
        )
        self.environment.pop("NODE_ENV", None)
        self.git("init", "-q")
        self.commit("first revision")
        (self.checkout / ".git/info/exclude").write_text("node_modules/\ndist/\n")
        self.stub("node", 'printf "%s\\n" "$TEST_NODE_VERSION"\n')
        self.stub("npm", '''
if [ "$1" = --version ]; then echo "$TEST_NPM_VERSION"; exit; fi
echo "npm $*" >>"$TEST_TRACE"
case "$*" in
  ci*) mkdir -p node_modules ;;
  'run build')
    [ "${TEST_BUILD_FAIL:-0}" = 0 ] || exit 17
    mkdir -p dist
    [ "${TEST_MISSING_OUTPUT:-0}" = 0 ] || exit 0
    echo built >dist/index.js
    ;;
  'run test:v2') exit "${TEST_TEST_FAIL:-0}" ;;
esac
''')

    def stub(self, name, body):
        path = self.binaries / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)

    def git(self, *arguments):
        return subprocess.run(
            ["git", "-C", str(self.checkout), *arguments], env=self.environment,
            text=True, capture_output=True, check=True, timeout=5,
        ).stdout.strip()

    def commit(self, value):
        (self.checkout / "source").write_text(value)
        self.git("add", "source")
        self.git("commit", "-m", value)

    def build(self, recipe="", context="", errexit=False):
        script = f'source "{SCRIPTS}/node_build.sh"\n'
        if errexit:
            script += "set -euo pipefail\n"
        script += recipe or "recipe() { npm ci --no-audit --no-fund && npm run build && npm run test:v2; }\n"
        script += 'build_node_checkout "$1" recipe "$2"\n'
        return subprocess.run(
            ["/bin/bash", "-c", script, "test", str(self.checkout), context],
            env=self.environment, text=True, capture_output=True, timeout=5,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)

    def build_count(self):
        return self.trace.read_text().splitlines().count("npm run build")

    def test_unchanged_checkout_skips_install_build_and_tests(self):
        self.assert_success(self.build())
        result = self.build(errexit=True)
        self.assert_success(result)
        self.assertIn("build is current, skipping", result.stdout)
        self.assertEqual(self.build_count(), 1)
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_revision_runtime_recipe_and_context_changes_rebuild(self):
        self.assert_success(self.build())
        self.commit("second revision")
        self.assert_success(self.build())
        self.environment["TEST_NODE_VERSION"] = "node-2"
        self.assert_success(self.build())
        self.environment["TEST_NPM_VERSION"] = "npm-2"
        self.assert_success(self.build())
        self.environment["NODE_ENV"] = "production"
        self.assert_success(self.build())
        self.assert_success(self.build(context="bun-2"))
        recipe = "recipe() { npm ci --ignore-scripts && npm run build && npm run test:v2; }\n"
        self.assert_success(self.build(recipe=recipe, context="bun-2"))
        self.assertEqual(self.build_count(), 7)

    def test_missing_output_or_dependencies_rebuild(self):
        self.assert_success(self.build())
        (self.checkout / "dist/index.js").unlink()
        self.assert_success(self.build())
        shutil.rmtree(self.checkout / "node_modules")
        self.assert_success(self.build())
        self.assertEqual(self.build_count(), 3)

    def test_failed_rebuild_discards_previous_success(self):
        self.assert_success(self.build())
        self.environment.update(TEST_NODE_VERSION="node-2", TEST_BUILD_FAIL="1")
        result = self.build()
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertFalse((self.checkout / ".git/configs-node-build").exists())
        self.environment.update(TEST_NODE_VERSION="node-1", TEST_BUILD_FAIL="0")
        self.assert_success(self.build())
        self.assertEqual(self.build_count(), 3)

    def test_failed_tests_and_missing_output_never_cache_success(self):
        self.environment["TEST_TEST_FAIL"] = "19"
        result = self.build(errexit=True)
        self.assertEqual(result.returncode, 19, result.stderr)
        self.assertFalse((self.checkout / ".git/configs-node-build").exists())
        self.environment["TEST_TEST_FAIL"] = "0"
        self.environment["TEST_MISSING_OUTPUT"] = "1"
        (self.checkout / "dist/index.js").unlink()
        result = self.build()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("build did not produce", result.stderr)
        self.assertFalse((self.checkout / ".git/configs-node-build").exists())
        self.environment["TEST_MISSING_OUTPUT"] = "0"
        self.assert_success(self.build())
        self.assertEqual(self.build_count(), 3)

    def stub_installer_git(self):
        self.environment["TEST_REAL_GIT"] = shutil.which("git")
        self.stub("git", '''
if [ "$1" = -C ]; then
  case "$3" in
    remote) printf 'https://github.com/egigoka/%s.git\\n' "${2##*/}"; exit ;;
    fetch) echo "fetch $2" >>"$TEST_TRACE"; exit ;;
  esac
fi
exec "$TEST_REAL_GIT" "$@"
''')

    def test_auth_installer_still_fetches_and_reuses_successful_build(self):
        destination = self.directory / ".local/share/opencode-codex-auth"
        destination.parent.mkdir(parents=True)
        self.checkout.rename(destination)
        self.checkout = destination
        self.git("update-ref", "refs/remotes/origin/main", "HEAD")
        self.environment["HOME"] = str(self.directory)
        self.stub_installer_git()
        script = (
            f'source "{SCRIPTS}/setup/agents/opencode.sh"\n'
            "install_opencode_codex_auth_fork || exit\n"
            "install_opencode_codex_auth_fork\n"
        )
        result = subprocess.run(
            ["/bin/bash", "-c", script], env=self.environment,
            text=True, capture_output=True, timeout=5,
        )
        self.assert_success(result)
        self.assertEqual(self.build_count(), 1)
        self.assertEqual(self.trace.read_text().count("fetch "), 2)

    def test_v2_installer_caches_each_plugin_and_preserves_dirty_checkout_guard(self):
        plugin_root = self.directory / "plugins"
        plugin_root.mkdir()
        names = [line.split()[0] for line in (SCRIPTS / "opencode_plugins.lock").read_text().splitlines() if line.strip()]
        for name in names:
            destination = plugin_root / name
            shutil.copytree(self.checkout, destination)
            subprocess.run(
                ["git", "-C", str(destination), "update-ref", "refs/remotes/origin/main", "HEAD"],
                env=self.environment, check=True, capture_output=True, timeout=5,
            )
        self.stub_installer_git()
        self.stub("bun", "echo bun-1\n")
        self.environment["OPENCODE_PLUGIN_DIR"] = str(plugin_root)
        command = ["/bin/bash", str(SCRIPTS / "install_opencode_plugins.sh")]
        for _ in range(2):
            result = subprocess.run(
                command, env=self.environment, text=True, capture_output=True, timeout=8,
            )
            self.assert_success(result)
        self.assertEqual(self.build_count(), len(names))
        self.assertEqual(self.trace.read_text().count("fetch "), len(names) * 2)
        first_plugin = plugin_root / names[0]
        (first_plugin / "source").write_text("local edit")
        result = subprocess.run(
            command, env=self.environment, text=True, capture_output=True, timeout=5,
        )
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Preserve local edits", result.stderr)
        self.assertEqual((first_plugin / "source").read_text(), "local edit")


if __name__ == "__main__":
    unittest.main()

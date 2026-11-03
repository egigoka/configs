#!/usr/bin/env python3

import json
import os
import pathlib
import shlex
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "install_scripts"


class GitHubReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.binaries = self.directory / "bin"
        self.binaries.mkdir()
        self.trace = self.directory / "trace"
        self.environment = dict(
            os.environ, HOME=str(self.directory), CONFIGS_DIR=str(ROOT),
            PATH=f"{self.binaries}:{os.environ['PATH']}", TEST_TRACE=str(self.trace),
        )
        self.environment.pop("CUA_DRIVER_VERSION", None)
        self.stub("gh", "exit 1\n")
        self.stub("curl", "echo 'curl: (22) HTTP 403' >&2; exit 22\n")

    def stub(self, name, body):
        path = self.binaries / name
        path.write_text(
            '#!/bin/bash\nprintf "%s %s\\n" "${0##*/}" "$*" >>"$TEST_TRACE"\n' + body
        )
        path.chmod(0o755)

    def response(self, name, data):
        self.stub(name, f"printf '%s\\n' {shlex.quote(json.dumps(data))}\n")

    def run_bash(self, script):
        return subprocess.run(
            ["/bin/bash", "-c", script], cwd=self.directory, env=self.environment,
            text=True, capture_output=True, timeout=5,
        )

    def lookup(self, repository="Graphify-Labs/graphify", prefix=""):
        return self.run_bash(
            f'source "{SCRIPTS}/github_release.sh"\n'
            f"github_release_tag {shlex.quote(repository)} {shlex.quote(prefix)}"
        )

    def agent_task(self, task):
        return self.run_bash(f'source "{SCRIPTS}/setup/agents/opencode.sh"\n{task}')

    def test_authenticated_gh_avoids_rate_limited_curl(self):
        self.response("gh", {"tag_name": "v1.2.3"})
        result = self.lookup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "v1.2.3")
        self.assertEqual(self.trace.read_text().splitlines(), ["gh api repos/Graphify-Labs/graphify/releases/latest"])

    def test_anonymous_fallback_selects_component_prerelease(self):
        self.response("curl", [
            {"tag_name": "other-v2.0.0"},
            {"tag_name": "cua-driver-rs-v0.38.0", "prerelease": True},
            {"tag_name": "cua-driver-rs-v0.37.0"},
        ])
        result = self.lookup("trycua/cua", "cua-driver-rs-v")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "cua-driver-rs-v0.38.0")
        self.assertIn("https://api.github.com/repos/trycua/cua/releases?per_page=50", self.trace.read_text())

    def test_component_lookup_requests_only_tags_in_default_release_order(self):
        self.response("gh", [
            {"tag_name": "other-v2.0.0"},
            {"tag_name": "cua-driver-rs-v0.38.0"},
            {"tag_name": "cua-driver-rs-v0.37.0"},
        ])
        result = self.lookup("trycua/cua", "cua-driver-rs-v")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "cua-driver-rs-v0.38.0")
        trace = self.trace.read_text()
        self.assertIn("gh api graphql -f owner=trycua -f name=cua", trace)
        self.assertIn("releases(first: 50) { nodes { tagName } }", trace)
        self.assertNotIn("orderBy", trace)
        self.assertNotIn("releases?per_page", trace)
        self.assertNotIn("curl", trace)

    def test_graphql_failure_falls_back_to_authenticated_rest(self):
        self.stub("gh", '''
if [ "$2" = graphql ]; then exit 1; fi
echo '[{"tag_name":"cua-driver-rs-v0.38.0","prerelease":true}]'
''')
        result = self.lookup("trycua/cua", "cua-driver-rs-v")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "cua-driver-rs-v0.38.0")
        trace = self.trace.read_text()
        self.assertIn("gh api graphql", trace)
        self.assertIn("gh api repos/trycua/cua/releases?per_page=50", trace)
        self.assertNotIn("curl", trace)

    def test_http_failure_does_not_invoke_json_parser(self):
        self.stub("python3", "echo parser-should-not-run >&2; exit 99\n")
        result = self.lookup()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Could not fetch GitHub releases", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertNotIn("python3", self.trace.read_text())

    def test_invalid_release_metadata_has_concise_error(self):
        for data in (None, {}, [], {"tag_name": "../../invalid"}, "not a release"):
            with self.subTest(data=data):
                self.response("gh", data)
                result = self.lookup()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("invalid or missing release metadata", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
        self.stub("gh", "echo invalid-json\n")
        result = self.lookup()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("Traceback", result.stderr)

    def test_graphify_lookup_failure_keeps_installed_binary_and_configures_platforms(self):
        self.stub("uv", "exit 99\n")
        self.stub("graphify", 'if [ "$1" = --version ]; then echo "graphify 0.9.100"; fi\n')
        result = self.agent_task("configure_graphify_agent")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("keeping graphify 0.9.100", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        trace = self.trace.read_text()
        self.assertIn("graphify install --platform agents", trace)
        self.assertIn("graphify install --platform hermes", trace)
        self.assertNotIn("uv tool install", trace)

    def test_graphify_missing_binary_fails_cleanly_on_lookup_failure(self):
        self.stub("uv", "exit 99\n")
        # A shadowed, unusable binary makes this independent of host installs.
        self.stub("graphify", "exit 1\n")
        result = self.agent_task("configure_graphify_agent")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Graphify is not installed", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_graphify_install_pins_python_and_configures_both_platforms(self):
        self.response("gh", {"tag_name": "v0.9.101"})
        self.environment["UV_PYTHON"] = "3.14t"
        self.stub("graphify", 'if [ "$1" = --version ]; then echo "graphify 0.9.100"; fi\n')
        self.stub("uv", '''
mkdir -p "$HOME/.local/bin"
cp "$HOME/bin/graphify" "$HOME/.local/bin/graphify"
''')
        result = self.agent_task("configure_graphify_agent")
        self.assertEqual(result.returncode, 0, result.stderr)
        trace = self.trace.read_text()
        self.assertIn(
            "uv tool install --force --python cpython@3.13 graphifyy @ "
            "https://github.com/Graphify-Labs/graphify/releases/download/"
            "v0.9.101/graphifyy-0.9.101-py3-none-any.whl", trace,
        )
        self.assertIn("graphify install --platform agents", trace)
        self.assertIn("graphify install --platform hermes", trace)

    def test_graphify_matching_version_skips_install(self):
        self.response("gh", {"tag_name": "v0.9.101"})
        self.stub("uv", "exit 99\n")
        self.stub("graphify", 'if [ "$1" = --version ]; then echo "graphify 0.9.101"; fi\n')
        result = self.agent_task("configure_graphify_agent")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("uv tool install", self.trace.read_text())

    def test_graphify_install_failure_stops_platform_configuration(self):
        self.response("gh", {"tag_name": "v0.9.101"})
        self.stub("uv", "exit 17\n")
        self.stub("graphify", "exit 1\n")
        result = self.agent_task("configure_graphify_agent")
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertNotIn("graphify install --platform", self.trace.read_text())

    def test_cua_lookup_failure_keeps_installed_binary(self):
        self.stub("cua-driver", "echo 'cua-driver 0.37.0'\n")
        result = self.agent_task("install_cua_driver")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("keeping cua-driver 0.37.0", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertNotIn("releases/download", self.trace.read_text())

    def test_cua_missing_binary_fails_cleanly_on_lookup_failure(self):
        self.stub("cua-driver", "exit 1\n")
        result = self.agent_task("install_cua_driver")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("CUA driver is not installed", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_cua_matching_version_skips_download(self):
        self.response("gh", [{"tag_name": "cua-driver-rs-v0.38.0", "prerelease": True}])
        self.stub("cua-driver", "echo 'cua-driver 0.38.0'\n")
        result = self.agent_task("install_cua_driver")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("curl", self.trace.read_text())

    def test_cua_version_pin_avoids_network(self):
        self.environment["CUA_DRIVER_VERSION"] = "0.38.0"
        result = self.run_bash(f'bash "{SCRIPTS}/install_cua_driver.sh" --version')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "0.38.0")
        self.assertFalse(self.trace.exists())

    def run_opencode_installer(self, version="opencode v2.2.5", help_status=0):
        self.environment["OPENCODE_INSTALL_DIR"] = str(self.binaries)
        if version is not None:
            self.stub("opencode", (
                f'if [ "$1" = --version ]; then echo {shlex.quote(version)}; '
                f'else exit {help_status}; fi\n'
            ))
        return self.run_bash(f'bash "{SCRIPTS}/install_opencode.sh"')

    def test_opencode_matching_version_skips_download_after_cli_check(self):
        self.response("gh", {"tag_name": "v2.2.5"})
        result = self.run_opencode_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already installed, skipping", result.stdout)
        trace = self.trace.read_text()
        self.assertIn("opencode run --help", trace)
        self.assertNotIn("curl", trace)

    def test_opencode_changed_or_unsupported_version_runs_installer(self):
        self.response("gh", {"tag_name": "v2.2.5"})
        for version in ("opencode v2.2.4", "opencode v1.9.0"):
            with self.subTest(version=version):
                self.trace.unlink(missing_ok=True)
                result = self.run_opencode_installer(version)
                self.assertEqual(result.returncode, 22, result.stderr)
                self.assertIn("releases/latest/download/install.sh", self.trace.read_text())

    def test_opencode_broken_cli_runs_installer(self):
        self.response("gh", {"tag_name": "v2.2.5"})
        result = self.run_opencode_installer(help_status=1)
        self.assertEqual(result.returncode, 22, result.stderr)
        self.assertIn("releases/latest/download/install.sh", self.trace.read_text())

    def test_opencode_lookup_failure_still_runs_installer(self):
        result = self.run_opencode_installer()
        self.assertEqual(result.returncode, 22, result.stderr)
        self.assertIn("releases/latest/download/install.sh", self.trace.read_text())

    def test_opencode_missing_binary_runs_installer(self):
        result = self.run_opencode_installer(version=None)
        self.assertEqual(result.returncode, 22, result.stderr)
        self.assertIn("releases/latest/download/install.sh", self.trace.read_text())


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3

import hashlib
import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "install_scripts/update_selected_agent_skills.sh"
GROUPS = (
    ("1" * 40, (
        "code-review", "codebase-design", "domain-modeling", "improve-codebase-architecture",
        "wizard", "writing-for-agents", "grilling",
    )),
    ("2" * 40, (
        "blast-radius", "technical-writing", "typescript-best-practices", "show-me-your-work",
        "principle-type-system-discipline", "principle-boundary-discipline",
        "principle-encode-lessons-in-structure",
    )),
    ("3" * 40, (
        "sol-loop", "full-send", "full-stop", "file-pr", "babysit-pr", "leaving-pr-comments",
    )),
)


class SelectedSkillPerformanceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.configs = self.directory / "configs"
        self.hermes = self.directory / "hermes"
        binaries = self.directory / "bin"
        binaries.mkdir()
        porter = self.configs / "install_scripts/port_selected_agent_skills.py"
        porter.parent.mkdir(parents=True)
        porter.write_text('raise RuntimeError("the current installation must not run the porter")\n')
        self.porter_ref = hashlib.sha256(porter.read_bytes()).hexdigest()
        self.roots = [self.configs / name / "skills" for name in (
            "opencode-macos", "opencode-other", "opencode-steamos",
        )] + [self.hermes / "skills"]
        for root in self.roots:
            for ref, names in GROUPS:
                for name in names:
                    skill = root / name
                    skill.mkdir(parents=True)
                    (skill / "SKILL.md").write_text("installed skill\n")
                    (skill / "LICENSE").write_text("installed license\n")
                    (skill / "UPSTREAM").write_text(self.metadata(ref))
        git = binaries / "git"
        git.write_text('''#!/bin/bash
printf '%s\n' "$*" >>"$TEST_TRACE"
if [ "$1" = ls-remote ]; then
  [ "${TEST_REMOTE_FAILURE:-0}" = 0 ] || exit 17
  case "$2" in
    *mattpocock*) ref=1111111111111111111111111111111111111111 ;;
    *cursor*) ref=2222222222222222222222222222222222222222 ;;
    *t3dotgg*) ref=3333333333333333333333333333333333333333 ;;
    *) exit 18 ;;
  esac
  printf '%s\trefs/heads/main\n' "$ref"
  exit 0
fi
# Deliberately stop every update before any checkout or installation can occur.
exit 19
''')
        git.chmod(0o755)
        self.trace = self.directory / "trace"
        self.environment = dict(
            os.environ, HOME=str(self.directory), HERMES_HOME=str(self.hermes),
            PATH=f"{binaries}:{os.environ['PATH']}", TEST_TRACE=str(self.trace),
        )

    def metadata(self, ref):
        return f"repository: fixture\ncommit: {ref}\nporter_sha256: {self.porter_ref}\n"

    def run_updater(self):
        return subprocess.run(
            ["/bin/bash", str(SCRIPT), str(self.configs)], env=self.environment,
            text=True, capture_output=True, timeout=8,
        )

    def calls(self):
        return self.trace.read_text().splitlines()

    def test_current_skills_skip_checkout_and_remain_unchanged(self):
        before = {path: path.read_bytes() for root in self.roots for path in root.rglob("*") if path.is_file()}
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already current", result.stdout)
        self.assertEqual(len(self.calls()), 3)
        self.assertTrue(all(call.startswith("ls-remote ") for call in self.calls()))
        self.assertEqual(before, {path: path.read_bytes() for path in before})

    def test_fields_can_be_reordered_and_first_values_win(self):
        upstream = self.roots[-1] / "leaving-pr-comments/UPSTREAM"
        upstream.write_text(
            f"porter_sha256: {self.porter_ref}\nporter_sha256: stale\n"
            f"commit: {GROUPS[-1][0]}\ncommit: stale\n"
        )
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already current", result.stdout)

    def test_each_destination_and_repository_rejects_stale_metadata(self):
        for root in self.roots:
            for ref, names in GROUPS:
                with self.subTest(root=root.name, skill=names[-1]):
                    upstream = root / names[-1] / "UPSTREAM"
                    upstream.write_text(self.metadata("0" * 40))
                    result = self.run_updater()
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("retaining installed selected skills", result.stderr)
                    self.assertNotIn("already current", result.stdout)
                    self.assertTrue(self.calls()[-1].startswith("init "))
                    upstream.write_text(self.metadata(ref))

    def test_missing_or_stale_first_fields_require_an_update(self):
        upstream = self.roots[-1] / "leaving-pr-comments/UPSTREAM"
        commit = f"commit: {GROUPS[-1][0]}\n"
        porter = f"porter_sha256: {self.porter_ref}\n"
        for content in (
            commit, porter, commit + "porter_sha256: stale\n" + porter,
            "commit: stale\n" + commit + porter,
        ):
            with self.subTest(content=content):
                upstream.write_text(content)
                result = self.run_updater()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("retaining installed selected skills", result.stderr)
                self.assertTrue(self.calls()[-1].startswith("init "))

    def test_failed_update_fails_when_installed_asset_is_missing(self):
        (self.roots[-1] / "leaving-pr-comments/LICENSE").unlink()
        result = self.run_updater()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("one or more selected skills are missing", result.stderr)

    def test_remote_failure_retains_installed_skills(self):
        self.environment["TEST_REMOTE_FAILURE"] = "1"
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("retaining installed selected skills", result.stderr)
        self.assertEqual(len(self.calls()), 1)

    def test_remote_failure_fails_when_skill_is_missing(self):
        self.environment["TEST_REMOTE_FAILURE"] = "1"
        (self.roots[-1] / "leaving-pr-comments/SKILL.md").unlink()
        result = self.run_updater()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("one or more selected skills are missing", result.stderr)
        self.assertEqual(len(self.calls()), 1)


if __name__ == "__main__":
    unittest.main()

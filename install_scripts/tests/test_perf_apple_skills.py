#!/usr/bin/env python3

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "update_apple_agent_skills.sh"


class AppleSkillPerformanceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.checkout = self.directory / "checkout"
        self.binaries = self.directory / "bin"
        self.binaries.mkdir()
        self.trace = self.directory / "trace"
        self.export = self.directory / "export"
        self.export.mkdir()
        self.roots = [
            self.checkout / f"opencode-{platform}" / "skills"
            for platform in ("macos", "other", "steamos")
        ] + [self.directory / "hermes" / "skills"]
        self.environment = dict(
            os.environ, HOME=str(self.directory), PATH=str(self.binaries),
            HERMES_HOME=str(self.directory / "hermes"),
            APPLE_TEST_CALLS=str(self.trace), APPLE_TEST_EXPORT=str(self.export),
        )
        for command in ("awk", "basename", "cat", "cp", "date", "diff", "dirname",
                        "grep", "mkdir", "mktemp", "mv", "rm"):
            executable = shutil.which(command)
            self.assertIsNotNone(executable)
            self.write_binary(command, f"exec {shlex.quote(executable)} \"$@\"\n")
        self.write_binary("python3", f"exec {shlex.quote(sys.executable)} \"$@\"\n")
        self.write_binary("xcrun", '''
[ "${APPLE_TEST_EXPORT_FAIL:-0}" = 0 ] || exit 19
[ "$*" != "" ] || exit 20
cp -R "$APPLE_TEST_EXPORT" "$5"
''')
        self.write_binary("xcodebuild", "printf 'Xcode 27.1\\nBuild version 18B123\\n'\n")
        for root in self.roots:
            self.write_skill(root, "iphone-duo", "static body")
            self.write_skill(root, "uikit-app-modernization", "installed body")
        self.write_skill(self.export, "uikit-app-modernization", "updated body")
        self.write_skill(self.export, "app-resizability", "new body")

    def write_binary(self, name, body):
        binary = self.binaries / name
        binary.write_text(
            "#!/bin/bash\n"
            f"printf '%s\\n' {shlex.quote(name)} >>\"$APPLE_TEST_CALLS\"\n" + body
        )
        binary.chmod(0o755)

    def write_skill(self, root, name, body):
        directory = root / name
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "SKILL.md").write_text(
            f"---\nname: {name}\ndescription: Example skill\n---\n{body}\n"
        )
        return directory

    def run_updater(self):
        self.trace.write_text("")
        return subprocess.run(
            ["/bin/bash", str(SCRIPT), str(self.checkout)], env=self.environment,
            capture_output=True, text=True, timeout=10,
        )

    def calls(self, command):
        return self.trace.read_text().splitlines().count(command)

    def test_batch_validation_uses_one_interpreter_and_one_xcode_query(self):
        for number in range(10):
            self.write_skill(self.export, f"sample-{number}", "sample body")
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls("python3"), 1)
        self.assertEqual(self.calls("xcodebuild"), 1)
        self.assertEqual(self.calls("dirname"), 0)
        self.assertEqual(self.calls("basename"), 0)
        for root in self.roots:
            for skill in self.export.iterdir():
                self.assertEqual((root / skill.name / "SKILL.md").read_bytes(),
                                 (skill / "SKILL.md").read_bytes())
                upstream = (root / skill.name / "UPSTREAM").read_text()
                self.assertIn("xcode_version: 27.1\n", upstream)
                self.assertIn("xcode_build: 18B123\n", upstream)

    def test_unchanged_export_preserves_installed_files_and_metadata(self):
        self.assertEqual(self.run_updater().returncode, 0)
        installed = self.roots[0] / "app-resizability"
        upstream = installed / "UPSTREAM"
        upstream.write_text("preserve existing metadata\n")
        before = {path: path.stat().st_mtime_ns for root in self.roots
                  for path in root.rglob("*") if path.is_file()}
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls("cp"), 1)  # Only the fake Xcode export copies.
        self.assertEqual(self.calls("mv"), 0)
        self.assertEqual(before, {path: path.stat().st_mtime_ns for path in before})
        self.assertEqual(upstream.read_text(), "preserve existing metadata\n")

    def test_support_file_changes_replace_tree_and_remove_stale_files(self):
        self.assertEqual(self.run_updater().returncode, 0)
        for root in self.roots:
            (root / "app-resizability" / "stale.txt").write_text("stale")
        (self.export / "app-resizability" / "reference.txt").write_text("updated")
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        for root in self.roots:
            installed = root / "app-resizability"
            self.assertFalse((installed / "stale.txt").exists())
            self.assertEqual((installed / "reference.txt").read_text(), "updated")

    def test_invalid_last_skill_never_publishes_earlier_valid_skill(self):
        invalid = self.export / "uikit-app-modernization" / "SKILL.md"
        invalid.write_text("invalid frontmatter")
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("retaining installed Apple skills", result.stderr)
        self.assertIn("failed validation: uikit-app-modernization", result.stderr)
        for root in self.roots:
            self.assertFalse((root / "app-resizability").exists())
            self.assertIn("installed body", (root / "uikit-app-modernization" / "SKILL.md").read_text())

    def test_unsafe_support_files_still_fail_with_missing_required_skills(self):
        (self.export / "app-resizability" / "link").symlink_to("SKILL.md")
        (self.roots[-1] / "uikit-app-modernization" / "SKILL.md").unlink()
        result = self.run_updater()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("symlink rejected", result.stderr)
        self.assertIn("required skills are missing", result.stderr)

    def test_export_failure_retains_existing_skills(self):
        self.environment["APPLE_TEST_EXPORT_FAIL"] = "1"
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("xcrun agent skills export failed", result.stderr)
        self.assertEqual(self.calls("python3"), 0)
        self.assertEqual(self.calls("xcodebuild"), 0)

    def test_no_xcode_fills_missing_vendored_skills_and_preserves_existing(self):
        (self.binaries / "xcrun").unlink()
        canonical = self.roots[0] / "uikit-app-modernization"
        (canonical / "UPSTREAM").write_text("source: xcrun agent skills export\n")
        missing = self.roots[-1] / "uikit-app-modernization" / "SKILL.md"
        missing.unlink()
        (self.roots[1] / "uikit-app-modernization" / "SKILL.md").write_text("local skill")
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(missing.read_bytes(), (canonical / "SKILL.md").read_bytes())
        self.assertEqual((self.roots[1] / "uikit-app-modernization" / "SKILL.md").read_text(), "local skill")
        self.assertEqual(self.calls("python3"), 0)
        self.assertEqual(self.calls("basename"), 0)


if __name__ == "__main__":
    unittest.main()

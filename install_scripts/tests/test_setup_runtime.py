#!/usr/bin/env python3

import os
import pathlib
import pty
import random
import re
import select
import shlex
import signal
import subprocess
import tempfile
import time
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULES = ROOT / "install_scripts/setup"


class SetupRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.environment = dict(os.environ, TMPDIR=str(self.directory), SETUP_JOBS="2")

    def run_bash(self, script, **kwargs):
        return subprocess.run(
            ["/bin/bash", "-c", script],
            cwd=self.directory,
            env=self.environment,
            text=True,
            capture_output=True,
            timeout=8,
            **kwargs,
        )

    def progress_source(self):
        return f'source "{MODULES}/progress.sh"; setup_progress_init 2 || exit'

    def run_entrypoint(self, *arguments, fail_phase=""):
        checkout = self.directory / "checkout"
        modules = checkout / "install_scripts/setup"
        modules.mkdir(parents=True)
        (checkout / "setup.sh").write_text((ROOT / "setup.sh").read_text())
        (modules / "progress.sh").write_text((MODULES / "progress.sh").read_text())
        (checkout / "install_scripts/epm.sh").touch()
        for name in ("packages", "agents", "platforms", "user-config"):
            (modules / f"{name}.sh").touch()
        phases = [
            "initialize_setup_context", "prepare_host_packages", "setup_platform_prerequisites",
            "install_agent_tools", "setup_platform_integrations", "setup_cli_configs",
            "setup_macos_integrations", "setup_agent_configs", "setup_file_listing_config",
            "setup_desktop_configs", "configure_codex",
        ]
        (modules / "core.sh").write_text(
            'record_phase() { echo "$1" >>trace; [ "${FAIL_PHASE:-}" != "$1" ]; }\n'
            + "\n".join(f"{name}() {{ record_phase {name}; }}" for name in phases)
        )
        binaries = self.directory / "bin"
        binaries.mkdir()
        fish = binaries / "fish"
        fish.write_text("#!/bin/bash\necho fish >>trace\n")
        fish.chmod(0o755)
        return subprocess.run(
            ["/bin/bash", str(checkout / "setup.sh"), *arguments], cwd=self.directory,
            env=dict(self.environment, PATH=f"{binaries}:{os.environ['PATH']}", FAIL_PHASE=fail_phase),
            text=True, capture_output=True, timeout=5,
        )

    def test_entrypoint_finishes_all_phases_and_launches_fish(self):
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("[9/9] Desktop configuration · done", result.stderr)
        phases = (self.directory / "trace").read_text().splitlines()
        self.assertEqual(len(phases), 11)
        self.assertEqual(phases[-1], "fish")
        self.assertNotIn("configure_codex", phases)

    def test_entrypoint_codex_only_stops_before_other_phases(self):
        result = self.run_entrypoint("--codex-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("[1/1] Codex configuration · done", result.stderr)
        self.assertEqual(
            (self.directory / "trace").read_text().splitlines(),
            ["initialize_setup_context", "configure_codex"],
        )

    def test_entrypoint_required_failure_stops_before_fish(self):
        result = self.run_entrypoint(fail_phase="install_agent_tools")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Agent tools · failed", result.stderr)
        self.assertEqual((self.directory / "trace").read_text().splitlines()[-1], "install_agent_tools")
        self.assertNotIn("Setup finished", result.stderr)

    def test_plain_progress_preserves_state_and_reports_failure(self):
        result = self.run_bash(self.progress_source() + """
            change_context() { context=retained; }
            fail_step() { return 7; }
            setup_step context change_context
            test "$context" = retained || exit 3
            setup_step failure fail_step
            test "$?" = 7 || exit 4
            setup_progress_finish
        """)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("\x1b", result.stderr)
        self.assertIn("[2/2] failure · failed (exit 7)", result.stderr)
        self.assertIn("1 warning(s)", result.stderr)

    def test_parallel_workers_obey_limit_and_keep_success_logs(self):
        result = self.run_bash(self.progress_source() + """
            work() { echo "start $1" >>trace; sleep 0.1; echo "end $1" >>trace; echo "log $1"; }
            a() { work a; }; b() { work b; }; c() { work c; }; d() { work d; }
            setup_parallel downloads a b c d
        """)
        self.assertEqual(result.returncode, 0, result.stderr)
        active = peak = 0
        for event in (self.directory / "trace").read_text().splitlines():
            active += 1 if event.startswith("start") else -1
            peak = max(peak, active)
            self.assertLessEqual(active, 2)
        self.assertEqual((active, peak), (0, 2))
        self.assertNotIn("Done ", result.stderr)
        logs = list(self.directory.glob("configs-setup.*/tasks.*/*.log"))
        self.assertEqual(len(logs), 4)
        self.assertEqual({path.read_text().strip() for path in logs}, {f"log {name}" for name in "abcd"})

    def test_one_job_runs_foreground_before_workers(self):
        self.environment["SETUP_JOBS"] = "1"
        result = self.run_bash(self.progress_source() + """
            foreground() { echo foreground >>trace; }
            a() { echo a >>trace; }; b() { echo b >>trace; }
            setup_parallel downloads --foreground foreground a b
        """)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.directory / "trace").read_text().splitlines(), ["foreground", "a", "b"])

    def test_foreground_overlaps_workers_without_exceeding_limit(self):
        result = self.run_bash(self.progress_source() + """
            foreground() {
              while [ ! -f worker.started ]; do sleep 0.01; done
              test ! -f second.started || return 8
              echo foreground >foreground.finished
            }
            a() {
              touch worker.started
              while [ ! -f foreground.finished ]; do sleep 0.01; done
            }
            b() { touch second.started; }
            setup_parallel downloads --foreground foreground a b
        """)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.directory / "second.started").exists())

    def assert_process_stopped(self, pid):
        result = subprocess.run(["ps", "-p", str(pid), "-o", "stat="], text=True, capture_output=True)
        self.assertTrue(not result.stdout.strip() or result.stdout.strip().startswith("Z"), result.stdout)

    def test_failed_worker_prints_log_and_cancels_descendants(self):
        result = self.run_bash(self.progress_source() + """
            fail_task() {
              while [ ! -f child.pid ]; do sleep 0.01; done
              echo deliberate-error; return 17
            }
            slow_task() { sleep 30 & echo $! >child.pid; wait; }
            pending_task() { touch should-not-run; }
            setup_parallel downloads fail_task slow_task pending_task
        """)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("deliberate-error", result.stderr)
        self.assertIn("exit 17", result.stderr)
        self.assertFalse((self.directory / "should-not-run").exists())
        self.assert_process_stopped(int((self.directory / "child.pid").read_text()))

    def test_direct_worker_exit_does_not_hang(self):
        result = self.run_bash(self.progress_source() + """
            direct_exit() { exit 19; }
            setup_parallel downloads direct_exit
        """)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("exit 19", result.stderr)

    def test_termination_cancels_descendants(self):
        script = self.progress_source() + """
            trap 'exit 143' TERM
            slow_task() { sleep 30 & echo $! >child.pid; wait; }
            setup_parallel downloads slow_task
        """
        process = subprocess.Popen(
            ["/bin/bash", "-c", script], cwd=self.directory, env=self.environment,
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            start_new_session=True,
        )
        try:
            deadline = time.monotonic() + 5
            while not (self.directory / "child.pid").exists():
                if time.monotonic() >= deadline:
                    self.fail("Worker did not start")
                time.sleep(0.01)
            os.killpg(process.pid, signal.SIGTERM)
            _, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 143, stderr)
            self.assert_process_stopped(int((self.directory / "child.pid").read_text()))
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
            process.communicate()

    def test_terminal_progress_fits_width_and_honors_no_color(self):
        for no_color in (False, True):
            with self.subTest(no_color=no_color):
                environment = dict(self.environment, TERM="xterm-256color", COLUMNS="40")
                environment.pop("NO_COLOR", None)
                if no_color:
                    environment["NO_COLOR"] = "1"
                master, slave = pty.openpty()
                try:
                    result = subprocess.run(
                        ["/bin/bash", "-c", self.progress_source() + """
                            setup_progress_draw 1 2 'A long task label that must fit a narrow terminal'
                            setup_progress_draw 1 2 waiting 1
                        """],
                        cwd=self.directory, env=environment, stdout=subprocess.PIPE,
                        stderr=slave, timeout=5,
                    )
                    self.assertEqual(result.returncode, 0)
                    output = b""
                    # macOS can discard unread PTY output when its last slave
                    # closes. Drain it while this process still holds the slave.
                    while select.select([master], [], [], 0.1)[0]:
                        chunk = os.read(master, 4096)
                        if not chunk:
                            break
                        output += chunk
                    text = output.decode()
                    self.assertIn("\x1b[2K", text)
                    self.assertEqual("\x1b[36m" in text, not no_color)
                    plain = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text)
                    for line in plain.splitlines():
                        if "━" in line:
                            self.assertLess(len(line), 40, line)
                finally:
                    if slave is not None:
                        os.close(slave)
                    os.close(master)

    def test_invalid_job_count_fails_before_work(self):
        for value in ("0", "-1", "oops", "01"):
            with self.subTest(value=value):
                self.environment["SETUP_JOBS"] = value
                result = self.run_bash(self.progress_source())
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("positive integer", result.stderr)

    def test_brew_inventory_cache_handles_aliases_and_new_packages(self):
        result = self.run_bash(f'source "{MODULES}/packages.sh"\n' + """
            SETUP_OS=Darwin
            brew() {
              echo "$*" >>brew.calls
              case "$*" in
                'list --formula -1') echo fzf ;;
                'list --cask -1') echo android-studio ;;
                'list --formula python3'|'install missing') return 0 ;;
                *) return 1 ;;
              esac
            }
            install() { brew install "$@"; }
            install_if_missing fzf android-studio python3 missing missing
        """)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.directory / "brew.calls").read_text().splitlines()
        self.assertEqual(calls.count("list --formula -1"), 1)
        self.assertEqual(calls.count("list --cask -1"), 1)
        self.assertEqual(calls.count("list --formula python3"), 1)
        self.assertEqual(calls.count("install missing"), 1)
        self.assertNotIn("install fzf", calls)
        self.assertNotIn("install android-studio", calls)

    def test_normal_absolute_links_skip_python_on_install_and_rerun(self):
        result = self.run_bash(f'source "{MODULES}/core.sh"\n' + """
            python3() { echo python >>python.calls; command python3 "$@"; }
            mkdir source
            install_link "$PWD/source" "$PWD/home/link" || exit 1
            install_link "$PWD/source" "$PWD/home/link" || exit 1
            test "$(readlink home/link)" = ../source
        """)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.directory / "python.calls").exists())

    def test_link_targets_match_relpath_for_shared_and_unrelated_parents(self):
        rng = random.Random(0)
        cases = [
            (self.directory, self.directory / "nested"),
            (pathlib.Path("/Applications/RocketSim.app"), self.directory),
            (pathlib.Path("/"), self.directory),
        ]
        for _ in range(50):
            source = self.directory.joinpath(*(rng.choices(["a", "ab", "space dir", "[glob]"], k=rng.randrange(1, 5))))
            parent = self.directory.joinpath(*(rng.choices(["a", "ab", "space dir", "[glob]"], k=rng.randrange(1, 5))))
            cases.append((source, parent))
        script = f'source "{MODULES}/core.sh"\n'
        destinations = []
        for index, (source, parent) in enumerate(cases):
            destination = parent / f"link-{index}"
            destinations.append(destination)
            script += f"install_link {shlex.quote(str(source))} {shlex.quote(str(destination))} || exit 1\n"
        result = self.run_bash(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        for (source, parent), destination in zip(cases, destinations):
            self.assertEqual(os.readlink(destination), os.path.relpath(source, parent))

    def test_link_normalization_and_backups_remain_intact(self):
        result = self.run_bash(f'source "{MODULES}/core.sh"\n' + """
            mkdir -p source home
            echo original >home/link
            install_link "$PWD/source" "$PWD/home/link" || exit 1
            test "$(cat home/link.preinstall)" = original || exit 2
            install_link "$PWD/source/../source" "$PWD/home/other" || exit 3
            test "$(readlink home/other)" = ../source || exit 4
            install_link "$PWD//source" "$PWD/home/repeated" || exit 5
            test "$(readlink home/repeated)" = ../source || exit 6
            install_link "$PWD/source" plain-link || exit 7
            test "$(readlink plain-link)" = source || exit 8
            ln -s "$PWD/source" home/absolute-link
            install_link "$PWD/source" "$PWD/home/absolute-link" || exit 9
            test "$(readlink home/absolute-link)" = ../source
        """)
        self.assertEqual(result.returncode, 0, result.stderr)


    def test_link_batch_checks_current_links_and_repairs_changes(self):
        result = self.run_bash(f'source "{MODULES}/core.sh"\n' + """
            mkdir -p 'source space' home
            echo original >home/replaced
            install_links "$PWD/source space" "$PWD/home/current" \
              "$PWD/source space" "$PWD/home/replaced" || exit 1
            test "$(cat home/replaced.preinstall)" = original || exit 2
            # Correct relative links must not invoke the per-link installer.
            eval "$(declare -f install_link | sed '1s/install_link/original_install_link/')"
            install_link() { echo "$2" >>repairs; original_install_link "$@"; }
            install_links "$PWD/source space" "$PWD/home/current" \
              "$PWD/source space" "$PWD/home/replaced" || exit 3
            test ! -f repairs || exit 4
            rm home/current
            ln -s "$PWD/source space" home/current
            install_links "$PWD/source space" "$PWD/home/current" || exit 5
            test "$(readlink home/current)" = '../source space' || exit 6
            test "$(wc -l <repairs | tr -d ' ')" = 1 || exit 7
            rm home/current
            ln -s ../missing home/current
            install_links "$PWD/source space" "$PWD/home/current" || exit 8
            test "$(readlink home/current)" = '../source space' || exit 9
            install_links '../source space' home/relative || exit 10
            test "$(readlink home/relative)" = '../source space' || exit 11
            install_links "$PWD/missing" "$PWD/home/dangling" || exit 12
            test "$(readlink home/dangling)" = ../missing || exit 13
        """)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_link_batch_propagates_check_and_repair_failures(self):
        result = self.run_bash(f'source "{MODULES}/core.sh"\n' + """
            install_link() { return 17; }
            install_links missing destination
            test "$?" = 17 || exit 1
            python3() { return 23; }
            install_links missing destination
            test "$?" = 23 || exit 2
            install_links odd
            test "$?" != 0 || exit 3
        """)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()

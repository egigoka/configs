#!/usr/bin/env python3

import os
import pathlib
import subprocess
import tempfile
import unittest


MODULES = pathlib.Path(__file__).resolve().parents[1] / "setup"


class AgentPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.environment = dict(os.environ, HOME=str(self.directory), SETUP_JOBS="4")

    def run_setup(self, overrides="", script="install_agent_tools", **kwargs):
        return subprocess.run(
            ["/bin/bash", "-c", f'''
source "{MODULES}/agents.sh"
source "{MODULES}/progress.sh"
setup_progress_init 1 || exit
CONFIGS_DIR=$HOME/checkout
OPENCODE_CONFIG_DIR=$CONFIGS_DIR/opencode
task() {{ [ "${{TEST_FAIL:-}}" != "$1" ]; }}
prepare_opencode_tools() {{ task prepare; }}
install_opencode_tools() {{ task packages; }}
install_cua_driver() {{ task cua; }}
install_opencode_builds() {{ task builds; }}
install_usage() {{ task usage; }}
configure_graphify_agent() {{ task graphify; }}
bash() {{ task swiftui; }}
update_setup_caveman() {{ task caveman; }}
update_setup_unslop_skill() {{ task unslop; }}
update_setup_selected_skills() {{ task selected; }}
update_setup_apple_skills() {{ task apple; }}
{overrides}
{script}
'''], env=self.environment, text=True, capture_output=True, timeout=8, **kwargs,
        )

    def test_all_workers_overlap_packages_and_join_before_config(self):
        result = self.run_setup(overrides='''
prepare_opencode_tools() { :; }
task() {
  touch "$HOME/$1.started"
  for ((i=0; i<100; i++)); do
    if [ "$1" = packages ]; then
      if [ -f "$HOME/builds.started" ] && [ -f "$HOME/graphify.started" ] && [ -f "$HOME/unslop.started" ]; then
        touch "$HOME/$1.done"
        return
      fi
    elif [ -f "$HOME/packages.started" ]; then
      touch "$HOME/$1.done"
      return
    fi
    sleep 0.01
  done
  return 17
}
''', script='''
install_agent_tools || exit
[ "$SETUP_AGENT_SKILLS_READY" = 1 ] || exit 18
for name in packages cua builds usage graphify swiftui caveman unslop selected apple; do
  [ -f "$HOME/$name.done" ] || exit 19
done
# Later configuration must not repeat live skill checks from this run.
setup_parallel() { exit 20; }
bash() { :; }
configure_caveman_session_models() { touch "$HOME/configured"; }
install_link() { :; }
install_links() { :; }
configure_claude_mcp_servers() { :; }
configure_codex() { :; }
setup_agent_configs || exit
[ -f "$HOME/configured" ]
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_required_failures_keep_config_barrier_closed(self):
        for name in ("prepare", "packages", "cua", "builds", "usage", "graphify", "swiftui", "caveman", "unslop", "selected", "apple"):
            with self.subTest(name=name):
                self.environment["TEST_FAIL"] = name
                result = self.run_setup(script='''
install_agent_tools
status=$?
[ "$SETUP_AGENT_SKILLS_READY" = 0 ] || exit 21
exit "$status"
''')
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertNotEqual(result.returncode, 21, result.stderr)

    def test_foreground_retry_reads_input_and_restores_custom_ssh(self):
        self.environment["GIT_SSH_COMMAND"] = "custom-ssh"
        result = self.run_setup(overrides='''
install_opencode_builds() {
  if [ "${GIT_TERMINAL_PROMPT:-}" = 0 ]; then
    [ "$GIT_SSH_COMMAND" = 'custom-ssh -oBatchMode=yes' ] || exit 22
    [ "$SSH_ASKPASS_REQUIRE" = force ] || exit 23
    return 17
  fi
  [ "$GIT_SSH_COMMAND" = custom-ssh ] || return 24
  read -r answer
  [ "$answer" = authorize ]
}
''', input="authorize\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Retrying OpenCode builds in foreground", result.stderr)


if __name__ == "__main__":
    unittest.main()

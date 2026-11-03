#!/usr/bin/env python3

import json
import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULES = ROOT / "install_scripts/setup"
SERVERS = ("cua-driver", "xcode", "mobile-mcp", "xcodebuild-mcp", "safari-mcp", "sentry")


class AgentConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        binaries = self.directory / "bin"
        binaries.mkdir()
        self.trace = self.directory / "trace"
        self.environment = dict(
            os.environ, HOME=str(self.directory), PATH=f"{binaries}:{os.environ['PATH']}",
            TEST_TRACE=str(self.trace), SETUP_JOBS="4",
        )
        self.environment.pop("CLAUDE_CONFIG_DIR", None)
        claude = binaries / "claude"
        claude.write_text('''#!/bin/bash
echo "$*" >>"$TEST_TRACE"
case "$2" in
  get) [ "$3" != "${TEST_MISSING:-}" ] ;;
  add) exit "${TEST_ADD_STATUS:-0}" ;;
  *) exit 99 ;;
esac
''')
        claude.chmod(0o755)

    def write_config(self, servers=None):
        if servers is None:
            servers = {name: {"command": name} for name in SERVERS}
            servers["sentry"] = {"type": "http", "url": "https://mcp.sentry.dev/mcp"}
        (self.directory / ".claude.json").write_text(json.dumps({"mcpServers": servers}))

    def run_config(self, script="configure_claude_mcp_servers"):
        return subprocess.run(
            ["/bin/bash", "-c", f'source "{MODULES}/agents/configs.sh"\n{script}'],
            env=self.environment, text=True, capture_output=True, timeout=8,
        )

    def calls(self):
        return self.trace.read_text().splitlines() if self.trace.exists() else []

    def test_existing_user_registrations_need_no_cli_calls(self):
        self.write_config()
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [])

    def test_missing_user_entry_checks_other_scopes_before_adding(self):
        self.write_config({name: {"command": name} for name in SERVERS if name != "mobile-mcp"})
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ["mcp get mobile-mcp"])
        self.trace.unlink()
        self.environment["TEST_MISSING"] = "mobile-mcp"
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [
            "mcp get mobile-mcp",
            "mcp add -s user mobile-mcp -e MOBILEMCP_DISABLE_TELEMETRY=1 -- mcp-server-mobile",
        ])

    def test_missing_or_unreadable_config_falls_back_to_cli(self):
        for content in (None, "invalid json", "[]", '{"mcpServers": []}'):
            with self.subTest(content=content):
                config = self.directory / ".claude.json"
                if content is not None:
                    config.write_text(content)
                result = self.run_config()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls(), [f"mcp get {name}" for name in SERVERS])
                self.trace.unlink()

    def test_invalid_server_entries_fall_back_to_cli(self):
        self.write_config(dict(zip(SERVERS, ({}, [], None, {"command": 3}, {"type": "http"}, {"type": "unknown"}))))
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [f"mcp get {name}" for name in SERVERS])

    def test_custom_config_directory_uses_cli(self):
        self.write_config()
        self.environment["CLAUDE_CONFIG_DIR"] = str(self.directory / "custom")
        result = self.run_config()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [f"mcp get {name}" for name in SERVERS])

    def test_add_failure_stops_later_registrations(self):
        self.environment.update(TEST_MISSING="cua-driver", TEST_ADD_STATUS="17")
        result = self.run_config()
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertEqual(self.calls(), ["mcp get cua-driver", "mcp add -s user cua-driver -- cua-driver mcp"])

    def test_skill_updates_overlap_and_finish_before_config_writes(self):
        result = self.run_config(f'''
source "{MODULES}/progress.sh"
setup_progress_init 1 || exit
CONFIGS_DIR=$HOME/checkout
OPENCODE_CONFIG_DIR=$CONFIGS_DIR/opencode
mkdir -p "$OPENCODE_CONFIG_DIR"
worker() {{
  touch "$HOME/$1.started"
  for ((i=0; i<100; i++)); do
    if [ -f "$HOME/caveman.started" ]; then
      touch "$HOME/$1.done"
      return
    fi
    sleep 0.01
  done
  return 1
}}
update_setup_unslop_skill() {{ worker unslop; }}
update_setup_selected_skills() {{ worker selected; }}
update_setup_apple_skills() {{ worker apple; }}
update_setup_caveman() {{
  touch "$HOME/caveman.started"
  for ((i=0; i<100; i++)); do
    if [ -f "$HOME/unslop.started" ] && [ -f "$HOME/selected.started" ] && [ -f "$HOME/apple.started" ]; then
      touch "$HOME/caveman.done"
      return
    fi
    sleep 0.01
  done
  return 1
}}
configure_caveman_session_models() {{
  for task in caveman unslop selected apple; do
    [ -f "$HOME/$task.done" ] || exit 11
  done
  echo config >>"$TEST_TRACE"
}}
bash() {{ :; }}
install_link() {{ :; }}
install_links() {{ :; }}
configure_claude_mcp_servers() {{ :; }}
configure_codex() {{ :; }}
setup_agent_configs
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ["config"])

    def test_swiftui_update_overlaps_tools_and_finishes_before_return(self):
        result = self.run_config(f'''
source "{MODULES}/agents.sh"
source "{MODULES}/progress.sh"
setup_progress_init 1 || exit
CONFIGS_DIR=$HOME/checkout
OPENCODE_CONFIG_DIR=$CONFIGS_DIR/opencode
prepare_opencode_tools() {{ :; }}
install_opencode_builds() {{ :; }}
update_setup_vendor_skills() {{ :; }}
update_setup_caveman() {{ echo caveman >>"$TEST_TRACE"; }}
configure_graphify_agent() {{ echo graphify >>"$TEST_TRACE"; }}
install_usage() {{ :; }}
install_cua_driver() {{ :; }}
bash() {{
  [ "$1" = "$CONFIGS_DIR/install_scripts/update_swiftui_expert_skill.sh" ] || return 12
  [ "$2" = "$OPENCODE_CONFIG_DIR" ] || return 13
  touch "$HOME/swiftui.started"
  for ((i=0; i<100; i++)); do
    if [ -f "$HOME/tools.started" ]; then
      touch "$HOME/swiftui.done"
      return
    fi
    sleep 0.01
  done
  return 14
}}
install_opencode_tools() {{
  touch "$HOME/tools.started"
  for ((i=0; i<100; i++)); do
    [ ! -f "$HOME/swiftui.started" ] || return 0
    sleep 0.01
  done
  return 15
}}
install_agent_tools || exit
[ -f "$HOME/swiftui.done" ] || exit 16
[ "$SETUP_AGENT_SKILLS_READY" -eq 1 ] || exit 17
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ["graphify", "caveman"])

    def test_build_retry_waits_for_workers_and_keeps_terminal_environment(self):
        for retry_status in (0, 29):
            with self.subTest(retry_status=retry_status):
                self.trace.unlink(missing_ok=True)
                result = self.run_config(f'''
source "{MODULES}/agents.sh"
source "{MODULES}/progress.sh"
setup_progress_init 1 || exit
CONFIGS_DIR=$HOME/checkout
OPENCODE_CONFIG_DIR=$CONFIGS_DIR/opencode
unset GIT_TERMINAL_PROMPT GIT_ASKPASS SSH_ASKPASS GCM_INTERACTIVE GIT_SSH_COMMAND
rm -f "$HOME/tools.done" "$HOME/vendor.done"
prepare_opencode_tools() {{ :; }}
install_opencode_tools() {{ touch "$HOME/tools.done"; }}
install_cua_driver() {{ :; }}
install_usage() {{ :; }}
prepare_external_agent_skills() {{ :; }}
update_setup_vendor_skills() {{ touch "$HOME/vendor.done"; }}
install_opencode_builds() {{
  if [ "${{GIT_TERMINAL_PROMPT:-}}" = 0 ]; then
    [ "$GIT_ASKPASS:$SSH_ASKPASS:$GCM_INTERACTIVE" = false:false:Never ] || exit 31
    case "$GIT_SSH_COMMAND" in *-oBatchMode=yes) ;; *) exit 32 ;; esac
    echo background >>"$TEST_TRACE"
    return 23
  fi
  [ -f "$HOME/tools.done" ] && [ -f "$HOME/vendor.done" ] || return 33
  [ -z "${{GIT_ASKPASS+x}}${{SSH_ASKPASS+x}}${{GCM_INTERACTIVE+x}}${{GIT_SSH_COMMAND+x}}" ] || return 34
  echo foreground >>"$TEST_TRACE"
  return {retry_status}
}}
install_agent_tools
status=$?
[ "$status" -eq {retry_status} ] || exit 35
[ "$SETUP_AGENT_SKILLS_READY" -eq {int(retry_status == 0)} ] || exit 36
''')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls(), ["background", "foreground"])

    def test_one_job_runs_updates_once_with_terminal_access(self):
        self.environment["SETUP_JOBS"] = "1"
        result = self.run_config(f'''
source "{MODULES}/agents.sh"
source "{MODULES}/progress.sh"
setup_progress_init 1 || exit
CONFIGS_DIR=$HOME/checkout
OPENCODE_CONFIG_DIR=$CONFIGS_DIR/opencode
unset GIT_TERMINAL_PROMPT
prepare_opencode_tools() {{ echo prepare >>"$TEST_TRACE"; }}
install_opencode_tools() {{ echo tools >>"$TEST_TRACE"; }}
install_cua_driver() {{ echo cua >>"$TEST_TRACE"; }}
install_opencode_builds() {{
  [ -z "${{GIT_TERMINAL_PROMPT+x}}" ] || return 31
  echo builds >>"$TEST_TRACE"
}}
install_usage() {{ echo usage >>"$TEST_TRACE"; }}
configure_graphify_agent() {{ echo graphify >>"$TEST_TRACE"; }}
bash() {{
  [ "$1" = "$CONFIGS_DIR/install_scripts/update_swiftui_expert_skill.sh" ] || return 32
  echo swiftui >>"$TEST_TRACE"
}}
update_setup_caveman() {{ echo caveman >>"$TEST_TRACE"; }}
update_setup_unslop_skill() {{ echo unslop >>"$TEST_TRACE"; }}
update_setup_selected_skills() {{ echo selected >>"$TEST_TRACE"; }}
update_setup_apple_skills() {{ echo apple >>"$TEST_TRACE"; }}
install_agent_tools || exit
[ "$SETUP_AGENT_SKILLS_READY" -eq 1 ] || exit 33
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [
            "prepare", "tools", "cua", "builds", "usage", "graphify", "swiftui",
            "caveman", "unslop", "selected", "apple",
        ])


if __name__ == "__main__":
    unittest.main()

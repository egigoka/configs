#!/usr/bin/env bash

# Bash 3.2-compatible progress output and bounded, independent task execution.

setup_progress_init() {
  SETUP_PROGRESS_TOTAL=$1
  SETUP_PROGRESS_DONE=0
  SETUP_PROGRESS_WARNINGS=0
  SETUP_PROGRESS_STARTED=$SECONDS
  SETUP_PROGRESS_TTY=0
  SETUP_PROGRESS_COLOR=
  SETUP_PROGRESS_RESET=
  if [ -t 2 ] && [ "${TERM:-dumb}" != dumb ]; then
    SETUP_PROGRESS_TTY=1
    if [ -z "${NO_COLOR+x}" ]; then
      SETUP_PROGRESS_COLOR=$'\033[36m'
      SETUP_PROGRESS_RESET=$'\033[0m'
    fi
  fi

  SETUP_JOBS=${SETUP_JOBS:-4}
  case "$SETUP_JOBS" in
    ''|*[!0-9]*|0|0*)
      printf 'SETUP_JOBS must be a positive integer\n' >&2
      return 1
      ;;
  esac
  # Avoid arithmetic overflow and excessive concurrency on small hosts.
  if [ "${#SETUP_JOBS}" -gt 2 ] || [ "$SETUP_JOBS" -gt 32 ]; then
    SETUP_JOBS=32
  fi
  SETUP_LOG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/configs-setup.XXXXXX") || return
  printf 'Setup logs: %s\n' "$SETUP_LOG_DIR" >&2
}

setup_progress_draw() {
  local done=$1 total=$2 label=$3 live=${4:-0}
  local width=24 filled empty bar rest percent counters available
  percent=$((done * 100 / total))
  if [ "$SETUP_PROGRESS_TTY" -eq 1 ]; then
    [ "${COLUMNS:-80}" -ge 80 ] || width=12
    printf -v counters ' %3d%%  %d/%d  ' "$percent" "$done" "$total"
    available=$((${COLUMNS:-80} - width - ${#counters} - 3))
    if [ "$available" -gt 3 ] && [ "${#label}" -gt "$available" ]; then
      label=${label:0:available-3}...
    elif [ "$available" -le 3 ]; then
      label=
    fi
    filled=$((done * width / total))
    empty=$((width - filled))
    printf -v bar '%*s' "$filled" ''
    printf -v rest '%*s' "$empty" ''
    bar=${bar// /━}
    rest=${rest// /─}
    [ "$live" -eq 0 ] || printf '\r\033[2K' >&2
    printf '  %s%s%s%s%s%s' \
      "$SETUP_PROGRESS_COLOR" "$bar" "$SETUP_PROGRESS_RESET" "$rest" \
      "$counters" "$label" >&2
    [ "$live" -eq 1 ] || printf '\n' >&2
  elif [ "$live" -eq 0 ]; then
    printf '[%d/%d] %s\n' "$done" "$total" "$label" >&2
  fi
}

setup_step() {
  local label=$1 started=$SECONDS status
  shift
  setup_progress_draw "$SETUP_PROGRESS_DONE" "$SETUP_PROGRESS_TOTAL" "$label"
  "$@"
  status=$?
  SETUP_PROGRESS_DONE=$((SETUP_PROGRESS_DONE + 1))
  if [ "$status" -eq 0 ]; then
    setup_progress_draw "$SETUP_PROGRESS_DONE" "$SETUP_PROGRESS_TOTAL" \
      "$label · done ($((SECONDS - started))s)"
  else
    SETUP_PROGRESS_WARNINGS=$((SETUP_PROGRESS_WARNINGS + 1))
    setup_progress_draw "$SETUP_PROGRESS_DONE" "$SETUP_PROGRESS_TOTAL" \
      "$label · failed (exit $status)"
  fi
  return "$status"
}

setup_progress_finish() {
  printf '\nSetup finished in %ss' "$((SECONDS - SETUP_PROGRESS_STARTED))" >&2
  if [ "$SETUP_PROGRESS_WARNINGS" -gt 0 ]; then
    printf ' with %s warning(s)' "$SETUP_PROGRESS_WARNINGS" >&2
  fi
  printf '. Logs: %s\n' "$SETUP_LOG_DIR" >&2
}

# Only queue tasks with disjoint outputs and no terminal input. An optional
# foreground function keeps package-manager and authentication prompts visible.
setup_parallel() (
  local label=$1 foreground='' task pid status index running=0 next=0 done=0 failed=0 tick=0
  local frames='|/-o' group_dir task_label worker_limit=$SETUP_JOBS
  local -a tasks
  # EXIT traps can run after function locals disappear in Bash 3.2. This array
  # belongs to the subshell, so cleanup retains it without changing the caller.
  SETUP_PARALLEL_PIDS=()
  shift
  if [ "${1:-}" = --foreground ]; then
    foreground=$2
    shift 2
  fi
  tasks=("$@")
  [ "${#tasks[@]}" -gt 0 ] || return 0
  group_dir=$(mktemp -d "$SETUP_LOG_DIR/tasks.XXXXXX") || return

  # Each worker owns a process group, so cancellation also stops its installers.
  # shellcheck disable=SC2329
  setup_parallel_cleanup() {
    local worker
    trap '' HUP INT TERM
    for worker in "${SETUP_PARALLEL_PIDS[@]}"; do
      [ -z "$worker" ] || kill -TERM -- "-$worker" 2>/dev/null || true
    done
    for worker in "${SETUP_PARALLEL_PIDS[@]}"; do
      [ -z "$worker" ] || wait "$worker" 2>/dev/null || true
    done
    if [ "$SETUP_PROGRESS_TTY" -eq 1 ]; then
      printf '\r\033[2K' >&2
    fi
  }
  trap setup_parallel_cleanup EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  if [ -n "$foreground" ]; then
    if [ "$SETUP_JOBS" -eq 1 ]; then
      "$foreground" || return
      foreground=
    else
      worker_limit=$((SETUP_JOBS - 1))
    fi
  fi

  while [ "$done" -lt "${#tasks[@]}" ]; do
    while [ "$next" -lt "${#tasks[@]}" ] && [ "$running" -lt "$worker_limit" ]; do
      task=${tasks[$next]}
      set -m
      (
        # Disable nested job control so all descendants stay in this group.
        set +m
        "$task" >"$group_dir/$task.log" 2>&1
        status=$?
        printf '%s\n' "$status" >"$group_dir/$next.status"
        exit "$status"
      ) </dev/null &
      SETUP_PARALLEL_PIDS[next]=$!
      # Keep process groups, but suppress Bash's asynchronous job notices.
      set +m
      next=$((next + 1))
      running=$((running + 1))
    done

    if [ -n "$foreground" ]; then
      "$foreground"
      status=$?
      foreground=
      worker_limit=$SETUP_JOBS
      if [ "$status" -ne 0 ]; then
        return "$status"
      fi
    fi

    for ((index = 0; index < next; index++)); do
      pid=${SETUP_PARALLEL_PIDS[$index]}
      [ -n "$pid" ] || continue
      # A worker may exit directly without writing its status file.
      if [ -f "$group_dir/$index.status" ] || ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid"
        status=$?
        SETUP_PARALLEL_PIDS[index]=
        running=$((running - 1))
        done=$((done + 1))
        task=${tasks[$index]}
        task_label=${task#update_setup_}
        task_label=${task_label#configure_}
        task_label=${task_label#install_}
        task_label=${task_label//_/ }
        if [ "$SETUP_PROGRESS_TTY" -eq 1 ]; then
          printf '\r\033[2K' >&2
        fi
        if [ "$status" -eq 0 ]; then
          setup_progress_draw "$done" "${#tasks[@]}" "$label · $task_label done"
        else
          failed=1
          setup_progress_draw "$done" "${#tasks[@]}" "$label · $task_label failed (exit $status)"
          cat "$group_dir/$task.log" >&2
          printf 'Task log: %s/%s.log\n' "$group_dir" "$task" >&2
        fi
      fi
    done
    [ "$failed" -eq 0 ] || return 1
    if [ "$next" -lt "${#tasks[@]}" ] && [ "$running" -lt "$worker_limit" ]; then
      continue
    fi
    if [ "$done" -lt "${#tasks[@]}" ]; then
      setup_progress_draw "$done" "${#tasks[@]}" \
        "$label · $running running ${frames:tick%4:1}" 1
      tick=$((tick + 1))
      sleep 0.2
    fi
  done
)

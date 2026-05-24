#!/usr/bin/env bash

STATE_FILE="/tmp/sketchybar_timer_state"
LAST_DURATION_FILE="/tmp/sketchybar_timer_last_duration"
TIMER_SCRIPT="${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/timer.sh"

if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

write_state() {
  printf '%s\n' "$2" >"$LAST_DURATION_FILE"
  cat >"$STATE_FILE" <<EOF
status=$1
duration=$2
remaining=$3
end_time=$4
EOF
}

refresh_bar() {
  if command -v sketchybar >/dev/null 2>&1; then
    NAME=timer "$TIMER_SCRIPT" >/dev/null 2>&1 || true
  fi
}

format_time() {
  local total=$1
  local hours=$((total / 3600))
  local minutes=$(((total % 3600) / 60))
  local seconds=$((total % 60))

  if [ "$hours" -gt 0 ]; then
    printf "%d:%02d:%02d" "$hours" "$minutes" "$seconds"
  else
    printf "%02d:%02d" "$minutes" "$seconds"
  fi
}

parse_duration() {
  local input=${1// /}
  local a b c

  if [[ "$input" =~ ^[0-9]+$ ]]; then
    echo $((input * 60))
    return 0
  fi

  if [[ "$input" =~ ^[0-9]+:[0-9]{1,2}$ ]]; then
    IFS=: read -r a b <<<"$input"
    echo $((10#$a * 60 + 10#$b))
    return 0
  fi

  if [[ "$input" =~ ^[0-9]+:[0-9]{1,2}:[0-9]{1,2}$ ]]; then
    IFS=: read -r a b c <<<"$input"
    echo $((10#$a * 3600 + 10#$b * 60 + 10#$c))
    return 0
  fi

  return 1
}

current_remaining() {
  local now remaining_value
  now=$(date +%s)

  case "${status:-idle}" in
    running)
      remaining_value=$((end_time - now))
      [ "$remaining_value" -lt 0 ] && remaining_value=0
      echo "$remaining_value"
      ;;
    paused) echo "${remaining:-0}" ;;
    *) echo 0 ;;
  esac
}

print_status() {
  local remaining_value last_value
  remaining_value=$(current_remaining)
  last_value="none"
  [ -f "$LAST_DURATION_FILE" ] && last_value=$(format_time "$(cat "$LAST_DURATION_FILE")")

  printf 'timer\n'
  printf '  state      %s\n' "${status:-idle}"
  printf '  remaining  %s\n' "$(format_time "$remaining_value")"
  printf '  last       %s\n' "$last_value"
}

start_timer() {
  local seconds=$1 now
  now=$(date +%s)
  write_state running "$seconds" "$seconds" $((now + seconds))
  refresh_bar
  printf 'timer started  %s\n' "$(format_time "$seconds")"
}

start_last() {
  local seconds=1800
  [ -f "$LAST_DURATION_FILE" ] && seconds=$(cat "$LAST_DURATION_FILE")
  start_timer "$seconds"
}

pause_timer() {
  local remaining_value
  remaining_value=$(current_remaining)
  write_state paused "${duration:-$remaining_value}" "$remaining_value" 0
  refresh_bar
  printf 'timer paused   %s\n' "$(format_time "$remaining_value")"
}

resume_timer() {
  local remaining_value now
  remaining_value=${remaining:-0}
  now=$(date +%s)
  write_state running "${duration:-$remaining_value}" "$remaining_value" $((now + remaining_value))
  refresh_bar
  printf 'timer resumed  %s\n' "$(format_time "$remaining_value")"
}

reset_timer() {
  rm -f "$STATE_FILE"
  refresh_bar
  printf 'timer reset    00:00\n'
}

print_help() {
  printf 'commands\n'
  printf '  timer <MM:SS | HH:MM:SS | M>\n'
  printf '  timer last|l     start last timer, default 30m\n'
  printf '  timer toggle|t   pause/resume\n'
  printf '  timer reset|r    reset to 00:00\n'
  printf '  timer status|s   show status\n'
}

case "${1:-}" in
  "") print_status ;;
  help|h|--help|-h) print_help ;;
  start)
    shift
    seconds=$(parse_duration "${1:-30}") || exit 1
    start_timer "$seconds"
    ;;
  last|again|l) start_last ;;
  pause) pause_timer ;;
  resume) resume_timer ;;
  toggle|t)
    if [ "${status:-idle}" = "running" ]; then pause_timer; else resume_timer; fi
    ;;
  reset|stop|clear|r) reset_timer ;;
  status|s) print_status ;;
  *)
    seconds=$(parse_duration "$1") || {
      printf 'usage: timer [start <duration>|last|pause|resume|toggle|reset|status|<duration>]\n' >&2
      exit 1
    }
    start_timer "$seconds"
    ;;
esac

#!/usr/bin/env bash

STATE_FILE="/tmp/sketchybar_timer_state"
LAST_DURATION_FILE="/tmp/sketchybar_timer_last_duration"
PENDING_LEFT_CLICK_FILE="/tmp/sketchybar_timer_pending_left_click"

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

start_last_timer() {
  local seconds=1800

  if [ -f "$LAST_DURATION_FILE" ]; then
    seconds=$(cat "$LAST_DURATION_FILE")
  elif [ -n "${duration:-}" ] && [ "${duration:-0}" -gt 0 ]; then
    seconds=$duration
  fi

  now=$(date +%s)
  write_state running "$seconds" "$seconds" $((now + seconds))
  NAME=timer "$CONFIG_DIR/plugins/timer.sh"
  exit 0
}

now_float() {
  perl -MTime::HiRes=time -e 'printf "%.3f", time'
}

toggle_or_reset_timer() {
  local now previous remaining

  now=$(now_float)

  if [ -f "$PENDING_LEFT_CLICK_FILE" ]; then
    previous=$(cat "$PENDING_LEFT_CLICK_FILE")
    if awk "BEGIN { exit !(($now - $previous) < 0.35) }"; then
      rm -f "$PENDING_LEFT_CLICK_FILE" "$STATE_FILE"
      NAME=timer "$CONFIG_DIR/plugins/timer.sh"
      exit 0
    fi
  fi

  printf '%s\n' "$now" >"$PENDING_LEFT_CLICK_FILE"
  sleep 0.35

  if [ "$(cat "$PENDING_LEFT_CLICK_FILE" 2>/dev/null)" = "$now" ]; then
    rm -f "$PENDING_LEFT_CLICK_FILE"
    # shellcheck disable=SC1090
    source "$STATE_FILE"
    if [ "${status:-idle}" = "running" ]; then
      remaining=$((end_time - $(date +%s)))
      [ "$remaining" -lt 0 ] && remaining=0
      write_state paused "${duration:-$remaining}" "$remaining" 0
    elif [ "${status:-idle}" = "paused" ]; then
      now_seconds=$(date +%s)
      write_state running "${duration:-${remaining:-0}}" "${remaining:-0}" $((now_seconds + ${remaining:-0}))
    fi
    NAME=timer "$CONFIG_DIR/plugins/timer.sh"
  fi

  exit 0
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

if [ "${BUTTON:-}" = "right" ]; then
  case "${status:-idle}" in
    idle|done) start_last_timer ;;
    running|paused) ;;
  esac
fi

if [ "${BUTTON:-}" = "left" ] && { [ "${status:-idle}" = "running" ] || [ "${status:-idle}" = "paused" ]; }; then
  toggle_or_reset_timer
fi

case "${status:-idle}" in
  running)
    now=$(date +%s)
    remaining=$((end_time - now))
    [ "$remaining" -lt 0 ] && remaining=0
    button=$(osascript -e 'button returned of (display dialog "timer is running" buttons {"Reset", "Pause", "Cancel"} default button "Pause" cancel button "Cancel")' 2>/dev/null) || exit 0

    case "$button" in
      Pause) write_state paused "${duration:-$remaining}" "$remaining" 0 ;;
      Reset) rm -f "$STATE_FILE" ;;
    esac
    ;;
  paused)
    button=$(osascript -e 'button returned of (display dialog "timer is paused" buttons {"Reset", "Resume", "Cancel"} default button "Resume" cancel button "Cancel")' 2>/dev/null) || exit 0

    case "$button" in
      Resume)
        now=$(date +%s)
        write_state running "${duration:-${remaining:-0}}" "${remaining:-0}" $((now + ${remaining:-0}))
        ;;
      Reset) rm -f "$STATE_FILE" ;;
    esac
    ;;
  done)
    rm -f "$STATE_FILE"
    ;;
  *)
    input=$(osascript -e 'text returned of (display dialog "" default answer "5" buttons {"Cancel", "Start"} default button "Start" cancel button "Cancel" with title "TIMER")' 2>/dev/null) || exit 0
    seconds=$(parse_duration "$input") || exit 0
    [ "$seconds" -le 0 ] && exit 0
    now=$(date +%s)
    write_state running "$seconds" "$seconds" $((now + seconds))
    ;;
esac

NAME=timer "$CONFIG_DIR/plugins/timer.sh"

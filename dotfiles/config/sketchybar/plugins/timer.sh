#!/usr/bin/env bash

STATE_FILE="/tmp/sketchybar_timer_state"

now=$(date +%s)
label="00:00"
color="0xffffffff"

if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

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

if [ "${status:-idle}" = "running" ]; then
  remaining=$((end_time - now))

  if [ "$remaining" -le 0 ]; then
    status="done"
    remaining=0
    cat >"$STATE_FILE" <<EOF
status=done
duration=${duration:-0}
remaining=0
end_time=0
EOF
  fi

  label=$(format_time "$remaining")
elif [ "${status:-idle}" = "paused" ]; then
  label=$(format_time "${remaining:-0}")
  color="0x99ffffff"
elif [ "${status:-idle}" = "done" ]; then
  label="00:00"
  if [ $((now % 2)) -eq 0 ]; then
    color="0xffff7777"
  else
    color="0x40ff7777"
  fi
fi

sketchybar --set "$NAME" label="$label" label.color="$color"

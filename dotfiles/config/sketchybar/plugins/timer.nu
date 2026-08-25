#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

use timer_state.nu [read-timer-state write-timer-state]

def format-time [total: int] {
  let safe_total = ([$total 0] | math max)
  let hours = ($safe_total // 3600)
  let minutes = (($safe_total mod 3600) // 60)
  let seconds = ($safe_total mod 60)
  if $hours > 0 { $"($hours):($minutes | fill --alignment right --character 0 --width 2):($seconds | fill --alignment right --character 0 --width 2)" } else { $"($minutes | fill --alignment right --character 0 --width 2):($seconds | fill --alignment right --character 0 --width 2)" }
}

export def timer-properties [now?: int] {
  let current_time = ($now | default (date now | format date "%s" | into int))
  mut state = (read-timer-state)
  mut color = "0xff@base05@"
  mut label = "00:00"

  if $state.status == "running" {
    let remaining = ($state.end_time - $current_time)
    if $remaining <= 0 {
      $state = { status: done duration: ($state.duration | default 0) remaining: 0 end_time: 0 }
      write-timer-state $state
      $label = "00:00"
    } else {
      $label = (format-time $remaining)
    }
  } else if $state.status == "paused" {
    $label = (format-time ($state.remaining | default 0))
    $color = "0xff@base04@"
  } else if $state.status == "stopwatch_running" {
    $label = (format-time (($state.elapsed | default 0) + ($current_time - ($state.start_time | default $current_time))))
  } else if $state.status == "stopwatch_paused" {
    $label = (format-time ($state.elapsed | default 0))
    $color = "0xff@base04@"
  } else if $state.status == "done" {
    if (($current_time mod 2) == 0) { $color = "0xff@base08@" } else { $color = "0x40@base08@" }
  }

  { label: $label color: $color }
}

def main [] {
  let sketchybar = ($env.SKETCHYBAR? | default "/opt/homebrew/bin/sketchybar")
  let properties = (timer-properties)
  ^$sketchybar --set timer $"label=($properties.label)" $"label.color=($properties.color)"
}

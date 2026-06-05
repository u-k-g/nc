#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

const state_file = "/tmp/sketchybar_timer_state.json"

def read-state [] {
  if ($state_file | path exists) { open $state_file } else { { status: idle duration: 0 remaining: 0 end_time: 0 elapsed: 0 start_time: 0 } }
}

def write-state [state: record] {
  $state | save --force $state_file
}

def format-time [total: int] {
  let safe_total = ([$total 0] | math max)
  let hours = ($safe_total // 3600)
  let minutes = (($safe_total mod 3600) // 60)
  let seconds = ($safe_total mod 60)
  if $hours > 0 { $"($hours):($minutes | fill --alignment right --character 0 --width 2):($seconds | fill --alignment right --character 0 --width 2)" } else { $"($minutes | fill --alignment right --character 0 --width 2):($seconds | fill --alignment right --character 0 --width 2)" }
}

def main [] {
  let now = (date now | format date "%s" | into int)
  mut state = (read-state)
  mut color = "0xffffffff"
  mut label = "00:00"

  if $state.status == "running" {
    let remaining = ($state.end_time - $now)
    if $remaining <= 0 {
      $state = { status: done duration: ($state.duration | default 0) remaining: 0 end_time: 0 }
      write-state $state
      $label = "00:00"
    } else {
      $label = (format-time $remaining)
    }
  } else if $state.status == "paused" {
    $label = (format-time ($state.remaining | default 0))
    $color = "0x99ffffff"
  } else if $state.status == "stopwatch_running" {
    $label = (format-time (($state.elapsed | default 0) + ($now - ($state.start_time | default $now))))
  } else if $state.status == "stopwatch_paused" {
    $label = (format-time ($state.elapsed | default 0))
    $color = "0x99ffffff"
  } else if $state.status == "done" {
    if (($now mod 2) == 0) { $color = "0xffff7777" } else { $color = "0x40ff7777" }
  }

  ^sketchybar --set timer $"label=($label)" $"label.color=($color)"
}

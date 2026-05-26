#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

const state_file = "/tmp/sketchybar_timer_state.json"
const last_duration_file = "/tmp/sketchybar_timer_last_duration"
const nu_bin = "/etc/profiles/per-user/uzair/bin/nu"

def read-state [] {
  if ($state_file | path exists) { open $state_file } else { { status: idle duration: 0 remaining: 0 end_time: 0 elapsed: 0 start_time: 0 } }
}

def write-state [status: string, duration: int, remaining: int, end_time: int] {
  $duration | save --force $last_duration_file
  { status: $status duration: $duration remaining: $remaining end_time: $end_time elapsed: 0 start_time: 0 } | save --force $state_file
}

def write-stopwatch [status: string, elapsed: int, start_time: int] {
  { status: $status duration: 0 remaining: 0 end_time: 0 elapsed: $elapsed start_time: $start_time } | save --force $state_file
}

def refresh-bar [] {
  try { with-env { NAME: timer } { ^$nu_bin --no-config-file (($env.CONFIG_DIR? | default ($env.HOME + "/.config/sketchybar")) | path join plugins timer.nu) } }
}

def format-time [total: int] {
  let safe_total = ([$total 0] | math max)
  let hours = ($safe_total // 3600)
  let minutes = (($safe_total mod 3600) // 60)
  let seconds = ($safe_total mod 60)
  if $hours > 0 { $"($hours):($minutes | fill --alignment right --character 0 --width 2):($seconds | fill --alignment right --character 0 --width 2)" } else { $"($minutes | fill --alignment right --character 0 --width 2):($seconds | fill --alignment right --character 0 --width 2)" }
}

def parse-duration [input: string] {
  let clean = ($input | str replace --all ' ' '')
  if ($clean =~ '^\d+(\.\d+)?$') { return (($clean | into float) * 60 | into int) }
  let parts = ($clean | split row ':')
  if (($parts | length) == 2) { return (((($parts.0 | into int) * 60) + ($parts.1 | into int))) }
  if (($parts | length) == 3) { return (((($parts.0 | into int) * 3600) + (($parts.1 | into int) * 60) + ($parts.2 | into int))) }
  error make { msg: "invalid duration" }
}

def current-remaining [state: record] {
  let now = (date now | format date "%s" | into int)
  if $state.status == "running" { [($state.end_time - $now) 0] | math max } else if $state.status == "paused" { $state.remaining | default 0 } else { 0 }
}

def current-elapsed [state: record] {
  let now = (date now | format date "%s" | into int)
  if $state.status == "stopwatch_running" { ($state.elapsed | default 0) + ($now - ($state.start_time | default $now)) } else if $state.status == "stopwatch_paused" { $state.elapsed | default 0 } else { 0 }
}

def start-timer [seconds: int] {
  let now = (date now | format date "%s" | into int)
  write-state running $seconds $seconds ($now + $seconds)
  refresh-bar
  print $"timer started  (format-time $seconds)"
}

def start-stopwatch [] {
  let now = (date now | format date "%s" | into int)
  write-stopwatch stopwatch_running 0 $now
  refresh-bar
  print "stopwatch started  00:00"
}

def main [command?: string, duration?: string] {
  let state = (read-state)
  match ($command | default status) {
    "help" | "h" | "--help" | "-h" => { print "commands\n  timer <MM:SS | HH:MM:SS | M>\n  timer stopwatch|sw start stopwatch\n  timer last|l     start last timer, default 30m\n  timer toggle|t   pause/resume\n  timer reset|r    reset to 00:00\n  timer status|s   show status" }
    "status" | "s" => { print $"timer\n  state      ($state.status | default idle)\n  remaining  (format-time (current-remaining $state))\n  elapsed    (format-time (current-elapsed $state))\n  last       (if ($last_duration_file | path exists) { format-time (open $last_duration_file | str trim | into int) } else { 'none' })" }
    "stopwatch" | "sw" => { start-stopwatch }
    "last" | "again" | "l" => { start-timer (if ($last_duration_file | path exists) { open $last_duration_file | str trim | into int } else { 1800 }) }
    "pause" => { if $state.status == "stopwatch_running" { let elapsed = (current-elapsed $state); write-stopwatch stopwatch_paused $elapsed 0; refresh-bar; print $"stopwatch paused   (format-time $elapsed)" } else { let remaining = (current-remaining $state); write-state paused ($state.duration | default $remaining) $remaining 0; refresh-bar; print $"timer paused   (format-time $remaining)" } }
    "resume" => { if $state.status == "stopwatch_paused" { let now = (date now | format date "%s" | into int); write-stopwatch stopwatch_running ($state.elapsed | default 0) $now; refresh-bar; print $"stopwatch resumed  (format-time ($state.elapsed | default 0))" } else { let remaining = ($state.remaining | default 0); let now = (date now | format date "%s" | into int); write-state running ($state.duration | default $remaining) $remaining ($now + $remaining); refresh-bar; print $"timer resumed  (format-time $remaining)" } }
    "toggle" | "t" => { if ($state.status in [running stopwatch_running]) { main pause } else { main resume } }
    "reset" | "stop" | "clear" | "r" => { rm --force $state_file; refresh-bar; print "timer reset    00:00" }
    "start" => { start-timer (parse-duration ($duration | default "30")) }
    _ => { start-timer (parse-duration ($command | default "30")) }
  }
}

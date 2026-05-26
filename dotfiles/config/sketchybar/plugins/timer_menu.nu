#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

const state_file = "/tmp/sketchybar_timer_state.json"
const last_duration_file = "/tmp/sketchybar_timer_last_duration"
const pending_left_click_file = "/tmp/sketchybar_timer_pending_left_click"
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
  with-env { NAME: timer } { ^$nu_bin --no-config-file (($env.CONFIG_DIR? | default ($env.HOME + "/.config/sketchybar")) | path join plugins timer.nu) }
}

def parse-duration [input: string] {
  let clean = ($input | str replace --all ' ' '')
  if ($clean =~ '^\d+(\.\d+)?$') { return (($clean | into float) * 60 | into int) }
  let parts = ($clean | split row ':')
  if (($parts | length) == 2) { return (((($parts.0 | into int) * 60) + ($parts.1 | into int))) }
  if (($parts | length) == 3) { return (((($parts.0 | into int) * 3600) + (($parts.1 | into int) * 60) + ($parts.2 | into int))) }
  error make { msg: "invalid duration" }
}

def start-last-timer [state: record] {
  let seconds = (if ($last_duration_file | path exists) { open $last_duration_file | str trim | into int } else if (($state.duration? | default 0) > 0) { $state.duration } else { 1800 })
  let now = (date now | format date "%s" | into int)
  write-state running $seconds $seconds ($now + $seconds)
  refresh-bar
}

def current-elapsed [state: record] {
  let now = (date now | format date "%s" | into int)
  if $state.status == "stopwatch_running" { ($state.elapsed | default 0) + ($now - ($state.start_time | default $now)) } else if $state.status == "stopwatch_paused" { $state.elapsed | default 0 } else { 0 }
}

def start-stopwatch [] {
  let now = (date now | format date "%s" | into int)
  write-stopwatch stopwatch_running 0 $now
  refresh-bar
}

def start-timer-dialog [] {
  let input = (try { ^osascript -e 'text returned of (display dialog "" default answer "5" buttons {"Cancel", "Start"} default button "Start" cancel button "Cancel" with title "TIMER")' err> /dev/null | str trim } catch { return })
  let seconds = (try { parse-duration $input } catch { return })
  if $seconds <= 0 { return }
  let now = (date now | format date "%s" | into int)
  write-state running $seconds $seconds ($now + $seconds)
  refresh-bar
}

def toggle-or-reset-timer [state: record] {
  let now = ((date now | into int) // 1000000)
  if ($pending_left_click_file | path exists) {
    let previous = (open $pending_left_click_file | str trim | into int)
    if (($now - $previous) < 350) {
      rm --force $pending_left_click_file $state_file
      refresh-bar
      return
    }
  }

  $now | save --force $pending_left_click_file
  sleep 350ms
  if (($pending_left_click_file | path exists) and ((open $pending_left_click_file | str trim | into int) == $now)) {
    rm --force $pending_left_click_file
    let current = (read-state)
    if $current.status == "running" {
      let remaining = ([($current.end_time - (date now | format date "%s" | into int)) 0] | math max)
      write-state paused ($current.duration | default $remaining) $remaining 0
    } else if $current.status == "paused" {
      let remaining = ($current.remaining | default 0)
      let now_seconds = (date now | format date "%s" | into int)
      write-state running ($current.duration | default $remaining) $remaining ($now_seconds + $remaining)
    } else if $current.status == "stopwatch_running" {
      write-stopwatch stopwatch_paused (current-elapsed $current) 0
    } else if $current.status == "stopwatch_paused" {
      let now_seconds = (date now | format date "%s" | into int)
      write-stopwatch stopwatch_running ($current.elapsed | default 0) $now_seconds
    }
    refresh-bar
  }
}

def idle-left-click [] {
  let now = ((date now | into int) // 1000000)
  if ($pending_left_click_file | path exists) {
    let previous = (open $pending_left_click_file | str trim | into int)
    if (($now - $previous) < 350) {
      rm --force $pending_left_click_file
      start-timer-dialog
      return
    }
  }

  $now | save --force $pending_left_click_file
  sleep 350ms
  if (($pending_left_click_file | path exists) and ((open $pending_left_click_file | str trim | into int) == $now)) {
    rm --force $pending_left_click_file
    start-stopwatch
  }
}

def dialog-button [message: string, buttons: string, default_button: string] {
  let script = ('button returned of (display dialog "' + $message + '" buttons {' + $buttons + '} default button "' + $default_button + '" cancel button "Cancel")')
  ^osascript -e $script err> /dev/null | str trim
}

def main [] {
  let state = (read-state)
  let button = ($env.BUTTON? | default "")

  if $button == "left" and ($state.status in [idle done]) { idle-left-click; return }
  if $button == "right" and ($state.status in [idle done]) { start-last-timer $state; return }
  if $button == "left" and ($state.status in [running paused stopwatch_running stopwatch_paused]) { toggle-or-reset-timer $state; return }

  match ($state.status | default idle) {
    running | stopwatch_running => {
      let remaining = ([($state.end_time - (date now | format date "%s" | into int)) 0] | math max)
      let is_stopwatch = ($state.status == "stopwatch_running")
      let message = (if $is_stopwatch { "stopwatch is running" } else { "timer is running" })
      let choice = (try { dialog-button $message '"Reset", "Pause", "Cancel"' "Pause" } catch { return })
      if $choice == "Pause" {
        if $is_stopwatch { write-stopwatch stopwatch_paused (current-elapsed $state) 0 } else { write-state paused ($state.duration | default $remaining) $remaining 0 }
      } else if $choice == "Reset" { rm --force $state_file }
    }
    paused | stopwatch_paused => {
      let is_stopwatch = ($state.status == "stopwatch_paused")
      let message = (if $is_stopwatch { "stopwatch is paused" } else { "timer is paused" })
      let choice = (try { dialog-button $message '"Reset", "Resume", "Cancel"' "Resume" } catch { return })
      if $choice == "Resume" {
        let now = (date now | format date "%s" | into int)
        if $is_stopwatch { write-stopwatch stopwatch_running ($state.elapsed | default 0) $now } else { write-state running ($state.duration | default ($state.remaining | default 0)) ($state.remaining | default 0) ($now + ($state.remaining | default 0)) }
      } else if $choice == "Reset" { rm --force $state_file }
    }
    done => { rm --force $state_file }
    _ => { start-timer-dialog }
  }

  refresh-bar
}

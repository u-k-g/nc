const legacy_state_path = "/tmp/sketchybar_timer_state.json"
const legacy_last_duration_path = "/tmp/sketchybar_timer_last_duration"

def runtime-dir [] {
  let temporary = ($env.TMPDIR? | default "" | str trim)
  if not ($temporary | is-empty) { return $temporary }

  let fallback = ($env.HOME | path join "Library" "Caches" "sketchybar")
  mkdir $fallback
  try { ^/bin/chmod 700 $fallback }
  $fallback
}

export def timer-state-path [] {
  runtime-dir | path join "sketchybar_timer_state.json"
}

export def last-duration-path [] {
  runtime-dir | path join "sketchybar_timer_last_duration"
}

export def pending-click-path [] {
  runtime-dir | path join "sketchybar_timer_pending_left_click"
}

export def default-timer-state [] {
  { status: idle duration: 0 remaining: 0 end_time: 0 elapsed: 0 start_time: 0 }
}

def migrate-legacy-file [legacy: string, destination: string] {
  if (($env.SKETCHYBAR_SKIP_LEGACY_MIGRATION? | default "") == "1") { return }
  if ($destination | path exists) or not ($legacy | path exists) { return }
  if (try { ($legacy | path type) == "symlink" } catch { true }) { return }

  let owner = (try { ^/usr/bin/stat -f %u $legacy | str trim | into int } catch { null })
  let current_owner = (try { ^/usr/bin/id -u | str trim | into int } catch { null })
  if $owner != $current_owner { return }

  try {
    mv $legacy $destination
    ^/bin/chmod 600 $destination
  }
}

def safe-int [value: any] {
  try { $value | into int } catch { 0 }
}

export def read-timer-state [] {
  let path = (timer-state-path)
  migrate-legacy-file $legacy_state_path $path
  if not ($path | path exists) { return (default-timer-state) }

  let state = (try { open $path } catch { null })
  if ($state == null) or not (($state | describe) | str starts-with "record") {
    return (default-timer-state)
  }

  let status = ($state.status? | default idle | into string)
  if not ($status in [idle running paused done stopwatch_running stopwatch_paused]) {
    return (default-timer-state)
  }

  {
    status: $status
    duration: (safe-int ($state.duration? | default 0))
    remaining: (safe-int ($state.remaining? | default 0))
    end_time: (safe-int ($state.end_time? | default 0))
    elapsed: (safe-int ($state.elapsed? | default 0))
    start_time: (safe-int ($state.start_time? | default 0))
  }
}

def atomic-write [contents: string, path: string] {
  let temporary = $"($path).($nu.pid).tmp"
  try {
    $contents | save --force $temporary
    ^/bin/chmod 600 $temporary
    mv --force $temporary $path
  } catch {
    try { rm --force $temporary }
    error make { msg: $"failed to update ($path)" }
  }
}

export def write-timer-state [state: record] {
  atomic-write ($state | to json) (timer-state-path)
}

export def read-last-duration [] {
  let path = (last-duration-path)
  migrate-legacy-file $legacy_last_duration_path $path
  if not ($path | path exists) { return null }
  try { open $path | str trim | into int } catch { null }
}

export def write-last-duration [duration: int] {
  atomic-write ($duration | into string) (last-duration-path)
}

export def write-pending-click [timestamp: int] {
  atomic-write ($timestamp | into string) (pending-click-path)
}

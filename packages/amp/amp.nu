const default_cutoff = 15

def state-dir []: nothing -> string {
  let state_root = (
    $env.XDG_STATE_HOME?
    | default ($env.HOME | path join ".local" "state")
  )

  $state_root | path join "nc" "amp"
}

def deadline-file []: nothing -> string {
  state-dir | path join "deadline"
}

def cutoff-file []: nothing -> string {
  state-dir | path join "cutoff"
}

def sleep-disabled []: nothing -> bool {
  let setting = (
    ^/usr/bin/pmset -g
    | lines
    | where { $in =~ '^\s*SleepDisabled\s+' }
    | get --optional 0
  )

  if $setting == null {
    false
  } else {
    ($setting | str trim | split row --regex '\s+' | last | into int) == 1
  }
}

def battery-percentage [] {
  let percentage = (
    ^/usr/bin/pmset -g batt
    | parse --regex '(?P<percentage>\d+)%'
    | get --optional 0.percentage
  )

  if $percentage == null {
    null
  } else {
    $percentage | into int
  }
}

def clear-deadline []: nothing -> nothing {
  let file = deadline-file
  if ($file | path exists) {
    rm --force $file
  }
}

def clear-cutoff []: nothing -> nothing {
  let file = cutoff-file
  if ($file | path exists) {
    rm --force $file
  }
}

def read-deadline [] {
  let file = deadline-file
  if not ($file | path exists) {
    return null
  }

  try {
    open --raw $file | str trim | into int
  } catch {
    null
  }
}

def read-cutoff []: nothing -> int {
  let file = cutoff-file
  if not ($file | path exists) {
    return $default_cutoff
  }

  try {
    let cutoff = (open --raw $file | str trim | into int)
    if $cutoff >= 1 and $cutoff <= 100 {
      $cutoff
    } else {
      $default_cutoff
    }
  } catch {
    $default_cutoff
  }
}

def set-sleep-disabled [value: int]: nothing -> nothing {
  let result = (
    do {
      ^/usr/bin/sudo -n /usr/bin/pmset -a disablesleep $value
    }
    | complete
  )

  if $result.exit_code != 0 {
    let detail = ($result.stderr | str trim)
    error make {
      msg: (
        if ($detail | is-empty) {
          "amp could not change the macOS sleep override"
        } else {
          $detail
        }
      )
    }
  }
}

def disable []: nothing -> nothing {
  set-sleep-disabled 0
  clear-deadline
  clear-cutoff
}

def enable [cutoff: int, minutes?: int]: nothing -> nothing {
  if $minutes != null and $minutes <= 0 {
    error make { msg: "minutes must be greater than zero" }
  }

  if $cutoff < 1 or $cutoff > 100 {
    error make { msg: "percent must be between 1 and 100" }
  }

  let battery = battery-percentage
  if $battery != null and $battery <= $cutoff {
    error make {
      msg: $"amp: battery is at ($battery)%; refusing to disable sleep at or below ($cutoff)%"
    }
  }

  set-sleep-disabled 1
  mkdir (state-dir)
  $cutoff | into string | save --force (cutoff-file)

  if $minutes == null {
    clear-deadline
    print $"amp: on until toggled off or battery reaches ($cutoff)%"
  } else {
    let deadline = (
      (date now | format date "%s" | into int)
      + ($minutes * 60)
    )
    $deadline | into string | save --force (deadline-file)

    let ends_at = (
      $deadline
      | into datetime --format "%s"
      | format date "%Y-%m-%d %H:%M:%S"
    )
    print $"amp: on for ($minutes) minute\(s\); normal sleep returns by ($ends_at) or at ($cutoff)% battery"
  }
}

def status []: nothing -> nothing {
  let cutoff = read-cutoff
  let battery = battery-percentage
  let battery_text = if $battery == null { "unknown" } else { $battery | into string }

  if not (sleep-disabled) {
    print $"amp: off \(battery ($battery_text)%\)"
    return
  }

  let deadline = read-deadline
  let now = (date now | format date "%s" | into int)
  if $deadline != null and $deadline > $now {
    let remaining = ((($deadline - $now) / 60) | math ceil | into int)
    print $"amp: on for about ($remaining) more minute\(s\) \(battery ($battery_text)%, cutoff ($cutoff)%\)"
  } else {
    print $"amp: on without a timer \(battery ($battery_text)%, cutoff ($cutoff)%\)"
  }
}

def guard []: nothing -> nothing {
  if not (sleep-disabled) {
    clear-deadline
    clear-cutoff
    return
  }

  let cutoff = read-cutoff
  let battery = battery-percentage
  if $battery != null and $battery <= $cutoff {
    disable
    do {
      ^/usr/bin/logger -t amp $"normal sleep restored at ($battery)% battery"
    } | complete | ignore
    return
  }

  let deadline = read-deadline
  if $deadline == null {
    return
  }

  let now = (date now | format date "%s" | into int)
  if $deadline <= $now {
    disable
    do {
      ^/usr/bin/logger -t amp "normal sleep restored after timer expired"
    } | complete | ignore
  }
}

def main [
  action?: string                    # Minutes, on, off, or status.
  --percent (-p): int = 15           # Battery percentage at which normal sleep is restored.
] {
  let action = $action | default "toggle"

  if $action == "toggle" {
    if sleep-disabled {
      disable
      print "amp: off; normal lid-close sleep restored"
    } else {
      enable $percent
    }
  } else if $action == "on" {
    enable $percent
  } else if $action == "off" {
    disable
    print "amp: off; normal lid-close sleep restored"
  } else if $action == "status" {
    status
  } else if $action == "guard" {
    guard
  } else if $action =~ '^\d+$' {
    enable $percent ($action | into int)
  } else {
    error make { msg: "usage: amp [MINUTES|on|off|status] [-p PERCENT]" }
  }
}

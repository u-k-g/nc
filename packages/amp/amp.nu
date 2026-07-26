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

def show-help []: nothing -> nothing {
  print "Keep DarwinBook awake while its lid is closed.

Usage:
  amp                         Toggle the sleep override on or off
  amp on                      Keep running until toggled off or battery cutoff
  amp <minutes>               Keep running for a limited time
  amp off                     Restore normal lid-close sleep
  amp status                  Show state, timer, battery, and cutoff

Options:
  -p, --percent <1-100>       Restore normal sleep at this battery level
                              [default: 15]
  -h, --help                  Show this help

Examples:
  amp                         Toggle using the 15% cutoff
  amp 60                      Stay awake for 60 minutes
  amp 60 -p 25                Stay awake for 60 minutes or until 25% battery
  amp on --percent 20         Stay awake indefinitely or until 20% battery
  amp off                     Turn the override off immediately

The timer and battery guard run independently of the terminal.
Do not put the MacBook in a bag while the override is active."
}

def usage-error [message: string] {
  error make {
    msg: $message
    help: "Run `amp --help` for usage."
  }
}

def parse-arguments [arguments: list] {
  mut action = ""
  mut percent = $default_cutoff
  mut index = 0

  while $index < ($arguments | length) {
    let argument = ($arguments | get $index | into string)

    if $argument in ["-h" "--help"] {
      return {
        help: true
        action: "toggle"
        percent: $percent
      }
    }

    if $argument in ["-p" "--percent"] {
      if ($index + 1) >= ($arguments | length) {
        usage-error $"($argument) requires a percentage"
      }

      let value = ($arguments | get ($index + 1) | into string)
      if not ($value =~ '^\d+$') {
        usage-error $"invalid percentage: ($value)"
      }
      $percent = $value | into int
      $index += 2
      continue
    }

    if ($argument | str starts-with "--percent=") {
      let value = ($argument | str replace "--percent=" "")
      if not ($value =~ '^\d+$') {
        usage-error $"invalid percentage: ($value)"
      }
      $percent = $value | into int
      $index += 1
      continue
    }

    if ($argument | str starts-with "-") {
      usage-error $"unknown option: ($argument)"
    }

    if not ($action | is-empty) {
      usage-error $"unexpected argument: ($argument)"
    }

    $action = $argument
    $index += 1
  }

  {
    help: false
    action: (if ($action | is-empty) { "toggle" } else { $action })
    percent: $percent
  }
}

def --wrapped main [...arguments] {
  let parsed = parse-arguments $arguments
  if $parsed.help {
    show-help
    return
  }

  let action = $parsed.action
  let percent = $parsed.percent

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

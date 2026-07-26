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

def lid-closed []: nothing -> bool {
  ^/usr/sbin/ioreg -r -k AppleClamshellState -d 1
  | lines
  | any { $in =~ '"AppleClamshellState"\s*=\s*Yes' }
}

def sleep-displays []: nothing -> nothing {
  let result = (
    do {
      ^/usr/bin/pmset displaysleepnow
    }
    | complete
  )

  if $result.exit_code != 0 {
    let detail = ($result.stderr | str trim)
    ^/usr/bin/logger -t amp (
      if ($detail | is-empty) {
        "could not put displays to sleep"
      } else {
        $"could not put displays to sleep: ($detail)"
      }
    )
  }
}

def display-state [] {
  let script = '
    ObjC.import("CoreGraphics");
    const id = $.CGMainDisplayID();
    JSON.stringify({
      active: Boolean($.CGDisplayIsActive(id)),
      asleep: Boolean($.CGDisplayIsAsleep(id)),
      builtin: Boolean($.CGDisplayIsBuiltin(id))
    });
  '
  let result = (
    do {
      ^/usr/bin/osascript -l JavaScript -e $script
    }
    | complete
  )

  if $result.exit_code == 0 {
    try {
      $result.stdout
      | str trim
      | from json
      | insert available true
    } catch {
      {
        available: false
        active: null
        asleep: null
        builtin: null
      }
    }
  } else {
    {
      available: false
      active: null
      asleep: null
      builtin: null
    }
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
  let now = (date now | format date "%s" | into int)
  if $deadline != null and $deadline <= $now {
    disable
    do {
      ^/usr/bin/logger -t amp "normal sleep restored after timer expired"
    } | complete | ignore
    return
  }

  if (lid-closed) {
    sleep-displays
  }
}

def test-lid []: nothing -> nothing {
  if not (sleep-disabled) {
    error make {
      msg: "amp is off"
      help: "Run `amp on`, then run `amp test`."
    }
  }

  if (lid-closed) {
    error make {
      msg: "the lid must be open when the test starts"
    }
  }

  let started_at = (date now | format date "%s" | into int)
  let started_battery = battery-percentage

  mut previous_at = $started_at
  mut closed_at = 0
  mut max_gap = 0
  mut closed_samples = 0
  mut display_off_samples = 0
  mut first_display_off_at = 0
  mut display_woke_after_sleep = false
  mut override_stayed_on = true
  mut inferred_sleep = false
  mut last_report_at = 0

  print "AMP LID TEST"
  print "Close the lid, leave it closed for at least 60 seconds, then reopen it."
  print "The test ends automatically after reopening. Ctrl-C cancels."
  print ""
  print "Waiting for lid close..."

  loop {
    sleep 2sec

    let now = (date now | format date "%s" | into int)
    let gap = $now - $previous_at
    if $gap > $max_gap {
      $max_gap = $gap
    }
    $previous_at = $now

    let closed = lid-closed
    let display = display-state
    let display_off = (
      $display.available
      and ($display.asleep or (not $display.active) or (not $display.builtin))
    )

    if not (sleep-disabled) {
      $override_stayed_on = false
    }

    if $closed {
      if $closed_at == 0 {
        $closed_at = $now
        $last_report_at = $now
        print $"  (date now | format date '%H:%M:%S') lid=closed; sampling every 2 seconds"
      }

      $closed_samples += 1
      if $display_off {
        $display_off_samples += 1
        if $first_display_off_at == 0 {
          $first_display_off_at = $now
          print $"  (date now | format date '%H:%M:%S') display=asleep"
        }
      } else if $first_display_off_at != 0 {
        $display_woke_after_sleep = true
      }

      if ($now - $last_report_at) >= 10 {
        let display_text = if not $display.available {
          "unknown"
        } else if $display_off {
          "asleep"
        } else {
          "awake"
        }
        print $"  (date now | format date '%H:%M:%S') heartbeat; display=($display_text)"
        $last_report_at = $now
      }
    } else if $closed_at != 0 {
      break
    } else if $gap > 10 {
      $inferred_sleep = true
      break
    }

    if ($now - $started_at) >= 300 {
      error make {
        msg: "test timed out after 5 minutes"
        help: "Reopen the lid and run `amp test` again."
      }
    }
  }

  let ended_at = (date now | format date "%s" | into int)
  let ended_battery = battery-percentage
  let closed_seconds = if $closed_at == 0 { 0 } else { $ended_at - $closed_at }
  let heartbeat_passed = (
    (not $inferred_sleep)
    and $closed_samples > 0
    and $max_gap <= 6
  )
  let display_passed = (
    $first_display_off_at != 0
    and ($first_display_off_at - $closed_at) <= 20
    and (not $display_woke_after_sleep)
  )
  let overall_passed = (
    $heartbeat_passed
    and $display_passed
    and $override_stayed_on
    and $closed_seconds >= 55
  )

  print ""
  print "AMP TEST RESULT"
  print $"  overall:          (if $overall_passed { 'PASS' } else { 'FAIL' })"
  print $"  lid closed:       ($closed_seconds)s \(need at least 55s\)"
  print $"  system awake:     (if $heartbeat_passed { 'PASS' } else { 'FAIL' }) \(max heartbeat gap ($max_gap)s\)"
  print $"  display asleep:   (if $display_passed { 'PASS' } else { 'FAIL' }) \(($display_off_samples)/($closed_samples) closed-lid samples\)"
  print $"  override active:  (if $override_stayed_on { 'PASS' } else { 'FAIL' })"
  print $"  battery:          ($started_battery)% -> ($ended_battery)%"
}

def show-help []: nothing -> nothing {
  print "Keep DarwinBook awake while its lid is closed.

Usage:
  amp                         Toggle the sleep override on or off
  amp on                      Keep running until toggled off or battery cutoff
  amp <minutes>               Keep running for a limited time
  amp off                     Restore normal lid-close sleep
  amp status                  Show state, timer, battery, and cutoff
  amp test                    Test lid, display, heartbeat, and sleep override

Options:
  -p, --percent <1-100>       Restore normal sleep at this battery level
                              [default: 15]
  -h, --help                  Show this help

Examples:
  amp                         Toggle using the 15% cutoff
  amp 60                      Stay awake for 60 minutes
  amp 60 -p 25                Stay awake for 60 minutes or until 25% battery
  amp on --percent 20         Stay awake indefinitely or until 20% battery
  amp test                    Close for one minute, reopen, and get a report
  amp off                     Turn the override off immediately

Closing the lid explicitly sleeps the displays while processes keep running.
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
    if (sleep-disabled) {
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
  } else if $action == "test" {
    test-lid
  } else if $action == "guard" {
    guard
  } else if $action =~ '^\d+$' {
    enable $percent ($action | into int)
  } else {
    error make { msg: "usage: amp [MINUTES|on|off|status] [-p PERCENT]" }
  }
}

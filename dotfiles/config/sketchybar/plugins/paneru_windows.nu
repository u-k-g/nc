#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

const max_items = 12
const focused_color = "0xff@base05@"
const unfocused_color = "0x80@base05@"
const legacy_pid_file = "/tmp/sketchybar_paneru_windows.pid"
const nu_bin = "/etc/profiles/per-user/uzair/bin/nu"

def env-default [name: string, fallback: string] {
  $env | get --optional $name | default $fallback
}

def runtime-dir [] {
  let temporary = ($env.TMPDIR? | default "" | str trim)
  if not ($temporary | is-empty) { return $temporary }

  let fallback = ($env.HOME | path join "Library" "Caches" "sketchybar")
  mkdir $fallback
  try { ^/bin/chmod 700 $fallback }
  $fallback
}

def pid-file [] {
  runtime-dir | path join "sketchybar_paneru_windows.pid"
}

def stop-subscriber-from [path: string] {
  if not ($path | path exists) { return }

  let pid = (try { open $path | str trim | into int } catch { null })
  if ($pid == null) or ($pid == $nu.pid) { return }

  let owner = (try { ^/bin/ps -p $pid -o uid= | str trim | into int } catch { null })
  let current_owner = (try { ^/usr/bin/id -u | str trim | into int } catch { null })
  let command = (try { ^/bin/ps -p $pid -o command= | str trim } catch { "" })
  if ($owner == $current_owner) and ($command | str contains "paneru_windows.nu") {
    try { ^/bin/kill $pid err> /dev/null }
  }
}

def kill-existing [] {
  let current_pid_file = (pid-file)
  stop-subscriber-from $current_pid_file

  if $legacy_pid_file != $current_pid_file {
    stop-subscriber-from $legacy_pid_file
    try { rm --force $legacy_pid_file }
  }

  $nu.pid | save --force $current_pid_file
  try { ^/bin/chmod 600 $current_pid_file }
}

def shell-escape [value: any] {
  $value | into string | str replace --all '\' '\\' | str replace --all '"' '\"'
}

def app-label [name: string] {
  if ($name | is-empty) { return "?" }
  let capitals = ($name | str replace --all --regex '[^A-Z]' '')
  if (($capitals | str length) == 2) { $capitals } else { $name | str substring 0..1 }
}

def resolve-icon [name: string, cache: list] {
  let cached = ($cache | where name == $name | get --optional 0.icon | default null)
  if $cached != null { return { icon: $cached cache: $cache } }

  let config_dir = (env-default CONFIG_DIR ($env.HOME + "/.config/sketchybar"))
  let icon_map = ($config_dir | path join "plugins" "icon_map.nu")

  let icon = (try {
    let result = (^$nu_bin --no-config-file $icon_map $name | complete)
    let icon = ($result.stdout | str trim | lines | first | default "")
    if ($result.exit_code == 0) and (not ($icon | is-empty)) { $icon } else { ":default:" }
  } catch {
    ":default:"
  })

  { icon: $icon cache: ($cache | append { name: $name icon: $icon }) }
}

def paneru-state [] {
  let paneru = (env-default PANERU "/etc/profiles/per-user/uzair/bin/paneru")
  let result = (^$paneru query state --json | complete)
  if ($result.exit_code != 0) or ($result.stdout | str trim | is-empty) {
    return null
  }

  $result.stdout | from json
}

def active-windows [state: record] {
  let active = ($state.active | default {})
  let active_native = ($active.native_workspace_id? | default null)
  let active_virtual = ($active.virtual_workspace_number? | default null)
  let focused_window_id = ($active.focused_window_id? | default null)

  let workspace = (
    $state.virtual_workspaces
    | default []
    | where native_workspace_id == $active_native
    | where number == $active_virtual
    | first
    | default null
  )

  if $workspace == null { return [] }

  $workspace.windows
    | default []
    | each {|window|
    let raw_name = ($window.app_name? | default "" | str trim)
    let name = (if ($raw_name | is-empty) { "Unknown" } else { $raw_name })
    let window_id = ($window.window_id? | default null)
    {
      id: $window_id,
      name: $name,
      focused: (($window.focused? | default false) or ($window_id == $focused_window_id)),
    }
  }
}

def update-sketchybar [icon_cache: list] {
  let sketchybar = (env-default SKETCHYBAR "/opt/homebrew/bin/sketchybar")
  let state = (try { paneru-state } catch { null })
  if $state == null { return { window_ids: [] icon_cache: $icon_cache } }

  let active = (active-windows $state | first $max_items)
  mut cache = $icon_cache
  mut windows = []
  for window in $active {
    let resolved = (resolve-icon $window.name $cache)
    $cache = $resolved.cache
    $windows = ($windows | append ($window | insert icon $resolved.icon))
  }
  mut args = []

  for index in 0..(($max_items) - 1) {
    let item = $"paperwm_($index)"

    if $index < ($windows | length) {
      let window = ($windows | get $index)
      let color = (if $window.focused { $focused_color } else { $unfocused_color })
      $args = ($args | append [--set $item drawing=on])

      if $window.icon == ":default:" {
        $args = ($args | append [
          icon.drawing=off
          label.drawing=on
          $"label=(shell-escape (app-label $window.name))"
          "label.font=DepartureMono Nerd Font Mono:Regular:14.0"
          $"label.color=($color)"
        ])
      } else {
        $args = ($args | append [
          label.drawing=off
          icon.drawing=on
          $"icon=($window.icon)"
          $"icon.color=($color)"
        ])
      }
    } else {
      $args = ($args | append [--set $item drawing=off])
    }
  }

  if ($args | length) > 0 {
    ^$sketchybar ...$args
  }

  { window_ids: ($windows | get id) icon_cache: $cache }
}

def update-focus [window_ids: list, focused_window_id: any] {
  let sketchybar = (env-default SKETCHYBAR "/opt/homebrew/bin/sketchybar")
  mut args = []

  for window in ($window_ids | enumerate) {
    let item = $"paperwm_($window.index)"
    let color = (if $window.item == $focused_window_id { $focused_color } else { $unfocused_color })
    $args = ($args | append [
      --set $item
      $"icon.color=($color)"
      $"label.color=($color)"
    ])
  }

  if ($args | length) > 0 {
    ^$sketchybar ...$args
  }
}

def update-settled-windows [icon_cache: list] {
  let immediate = (update-sketchybar $icon_cache)

  # Paneru can publish a structural event before `query state` reflects the
  # complete batch. Reconcile once more after it has settled so stale window
  # slots cannot remain visible indefinitely.
  sleep 50ms
  update-sketchybar $immediate.icon_cache
}

def subscribe-loop [] {
  let paneru = (env-default PANERU "/etc/profiles/per-user/uzair/bin/paneru")
  mut icon_cache = []

  loop {
    try {
      let initial = (update-sketchybar $icon_cache)
      mut window_ids = $initial.window_ids
      $icon_cache = $initial.icon_cache

      for line in (^$paneru subscribe --json | lines) {
        let event = (try { $line | from json } catch { null })
        if $event == null { continue }

        let event_name = ($event.event? | default "")
        if $event_name == "window_focused" {
          let focused_window_id = ($event.window_id? | default null)
          if ($window_ids | any {|window_id| $window_id == $focused_window_id }) {
            update-focus $window_ids $focused_window_id
          } else {
            let updated = (update-settled-windows $icon_cache)
            $window_ids = $updated.window_ids
            $icon_cache = $updated.icon_cache
          }
        } else if $event_name != "window_title_changed" {
          let updated = (update-settled-windows $icon_cache)
          $window_ids = $updated.window_ids
          $icon_cache = $updated.icon_cache
        }
      }
    }
    sleep 1sec
  }
}

def main [mode?: string] {
  if $mode == "once" {
    update-sketchybar [] | ignore
  } else {
    kill-existing
    subscribe-loop
  }
}

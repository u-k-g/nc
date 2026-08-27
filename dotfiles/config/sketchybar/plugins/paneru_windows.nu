#!/usr/bin/env -S nu --no-config-file

const max_items = 12
const focused_color = "0xff@base05@"
const unfocused_color = "0x80@base05@"
const legacy_pid_file = "/tmp/sketchybar_paneru_windows.pid"

use icon_map.nu [icon-for-app load-icon-map]

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

def paneru-state [] {
  let paneru = (env-default PANERU "/run/current-system/sw/bin/paneru")
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

def render-windows [previous: list, windows: list] {
  let sketchybar = (env-default SKETCHYBAR "/opt/homebrew/bin/sketchybar")
  mut args = []

  for index in 0..(($max_items) - 1) {
    let item = $"paperwm_($index)"
    let current = ($windows | get --optional $index | default null)
    let old = ($previous | get --optional $index | default null)

    if $current == null {
      if $old != null { $args = ($args | append [--set $item drawing=off]) }
      continue
    }

    let identity_changed = (
      ($old == null)
      or ($old.id != $current.id)
      or ($old.name != $current.name)
      or ($old.icon != $current.icon)
    )
    let focus_changed = (($old == null) or ($old.focused != $current.focused))
    if not ($identity_changed or $focus_changed) { continue }

    let color = (if $current.focused { $focused_color } else { $unfocused_color })
    $args = ($args | append [--set $item])

    if $identity_changed {
      $args = ($args | append [drawing=on])

      if $current.icon == ":default:" {
        $args = ($args | append [
          icon.drawing=off
          label.drawing=on
          $"label=(shell-escape (app-label $current.name))"
          "label.font=DepartureMono Nerd Font Mono:Regular:14.0"
        ])
      } else {
        $args = ($args | append [
          label.drawing=off
          icon.drawing=on
          $"icon=($current.icon)"
        ])
      }
    }

    $args = ($args | append [$"icon.color=($color)" $"label.color=($color)"])
  }

  if ($args | length) > 0 {
    ^$sketchybar ...$args
  }
}

def update-sketchybar [previous: list, icon_map: list] {
  let state = (try { paneru-state } catch { null })
  if $state == null {
    return { windows: $previous focused_window_id: null }
  }

  let windows = (
    active-windows $state
    | first $max_items
    | each {|window| $window | insert icon (icon-for-app $window.name $icon_map) }
  )
  render-windows $previous $windows

  {
    windows: $windows
    focused_window_id: ($state.active.focused_window_id? | default null)
  }
}

def update-focus [windows: list, previous_focused_window_id: any, focused_window_id: any] {
  let sketchybar = (env-default SKETCHYBAR "/opt/homebrew/bin/sketchybar")
  mut args = []

  for window in ($windows | enumerate) {
    if not ($window.item.id in [$previous_focused_window_id $focused_window_id]) { continue }
    let item = $"paperwm_($window.index)"
    let color = (if $window.item.id == $focused_window_id { $focused_color } else { $unfocused_color })
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

def subscribe-loop [] {
  let paneru = (env-default PANERU "/run/current-system/sw/bin/paneru")
  let icon_map = (load-icon-map)
  mut windows = []
  mut focused_window_id: any = null

  loop {
    let initial = (update-sketchybar $windows $icon_map)
    $windows = $initial.windows
    $focused_window_id = $initial.focused_window_id

    for line in (^$paneru subscribe --json | lines) {
      let event = (try { $line | from json } catch { null })
      if $event == null { continue }

      let event_name = ($event.event? | default "")
      if $event_name in ["on_screen_changed" "window_focused"] {
        let event_focused_window_id = if $event_name == "window_focused" {
          $event.window_id? | default null
        } else {
          $event.active.focused_window_id? | default null
        }

        if ($event_focused_window_id != null) and ($event_focused_window_id != $focused_window_id) {
          if ($windows | any {|window| $window.id == $event_focused_window_id }) {
            update-focus $windows $focused_window_id $event_focused_window_id
            $windows = ($windows | each {|window| $window | upsert focused ($window.id == $event_focused_window_id) })
            $focused_window_id = $event_focused_window_id
          } else {
            let updated = (update-sketchybar $windows $icon_map)
            $windows = $updated.windows
            $focused_window_id = $updated.focused_window_id
          }
        }
      } else if $event_name in [
        "display_changed"
        "virtual_workspace_changed"
        "windows_changed"
      ] {
        let updated = (update-sketchybar $windows $icon_map)
        $windows = $updated.windows
        $focused_window_id = $updated.focused_window_id
      }
    }
    sleep 50ms
  }
}

def main [mode?: string] {
  if $mode == "once" {
    update-sketchybar [] (load-icon-map) | ignore
  } else {
    kill-existing
    subscribe-loop
  }
}

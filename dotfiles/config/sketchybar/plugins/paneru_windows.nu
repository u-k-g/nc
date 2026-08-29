#!/usr/bin/env -S nu --no-config-file

const max_items = 12
const once_attempts = 20
const focused_color = "0xff@base05@"
const unfocused_color = "0x80@base05@"

use icon_map.nu [icon-for-app load-icon-map]

def env-default [name: string, fallback: string] {
  $env | get --optional $name | default $fallback
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

def render-windows [windows: list] {
  let sketchybar = (env-default SKETCHYBAR "/opt/homebrew/bin/sketchybar")
  mut args = []

  for index in 0..(($max_items) - 1) {
    let item = $"paperwm_($index)"
    let current = ($windows | get --optional $index | default null)

    if $current == null {
      $args = ($args | append [--set $item drawing=off])
      continue
    }

    let color = (if $current.focused { $focused_color } else { $unfocused_color })
    $args = ($args | append [--set $item drawing=on])

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

    $args = ($args | append [$"icon.color=($color)" $"label.color=($color)"])
  }

  let result = (^$sketchybar ...$args | complete)
  $result.exit_code == 0
}

def update-sketchybar [previous: list, icon_map: list] {
  let state = (try { paneru-state } catch { null })
  if $state == null {
    return { windows: $previous focused_window_id: null synchronized: false }
  }

  let windows = (
    active-windows $state
    | first $max_items
    | each {|window| $window | insert icon (icon-for-app $window.name $icon_map) }
  )
  let synchronized = (render-windows $windows)

  {
    windows: $windows
    focused_window_id: ($state.active.focused_window_id? | default null)
    synchronized: $synchronized
  }
}

def main [] {
  let icon_map = (load-icon-map)
  for _ in 1..$once_attempts {
    let updated = (update-sketchybar [] $icon_map)
    if $updated.synchronized { return }
    sleep 100ms
  }
  exit 1
}

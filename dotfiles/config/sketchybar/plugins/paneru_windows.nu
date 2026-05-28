#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

const max_items = 12
const focused_color = "0xffffffff"
const unfocused_color = "0x60ffffff"
const pid_file = "/tmp/sketchybar_paneru_windows.pid"
const nu_bin = "/etc/profiles/per-user/uzair/bin/nu"

def env-default [name: string, fallback: string] {
  $env | get --optional $name | default $fallback
}

def kill-existing [] {
  if ($pid_file | path exists) {
    let pid = (try { open $pid_file | str trim | into int } catch { null })
    if ($pid != null) and ($pid != $nu.pid) {
      try { ^kill $pid err> /dev/null }
    }
  }

  $nu.pid | save --force $pid_file
}

def shell-escape [value: any] {
  $value | into string | str replace --all '\' '\\' | str replace --all '"' '\"'
}

def app-label [name: string] {
  let capitals = ($name | str replace --all --regex '[^A-Z]' '')
  if (($capitals | str length) == 2) { $capitals } else { $name | str substring 0..1 }
}

def icon-for-app [name: string] {
  let config_dir = (env-default CONFIG_DIR ($env.HOME + "/.config/sketchybar"))
  let icon_map = ($config_dir | path join "plugins" "icon_map.nu")

  try {
    let result = (^$nu_bin --no-config-file $icon_map $name | complete)
    let icon = ($result.stdout | str trim | lines | first | default "")
    if ($result.exit_code == 0) and (not ($icon | is-empty)) { $icon } else { ":default:" }
  } catch {
    ":default:"
  }
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
      let name = ($window.app_name? | default "Unknown")
      let window_id = ($window.window_id? | default null)
      {
        id: $window_id,
        name: $name,
        icon: (icon-for-app $name),
        focused: (($window.focused? | default false) or ($window_id == $focused_window_id)),
      }
    }
}

def update-sketchybar [] {
  let sketchybar = (env-default SKETCHYBAR "/opt/homebrew/bin/sketchybar")
  let state = (try { paneru-state } catch { null })
  if $state == null { return }

  let windows = (active-windows $state)
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
}

def subscribe-loop [] {
  let paneru = (env-default PANERU "/etc/profiles/per-user/uzair/bin/paneru")

  loop {
    update-sketchybar
    try {
      for line in (^$paneru subscribe --json | lines) {
        let event = (try { $line | from json } catch { null })
        if $event == null { continue }

        match ($event.event? | default "") {
          "window_title_changed" => {}
          _ => { update-sketchybar }
        }
      }
    }
    sleep 1sec
  }
}

def main [mode?: string] {
  kill-existing
  if $mode == "once" {
    update-sketchybar
  } else {
    subscribe-loop
  }
}

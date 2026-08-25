#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

# Paneru + SketchyBar configuration, invoked by sketchybarrc.
# Uses a fixed item pool controlled by the Paneru state subscriber.

def main [] {
  let config_dir = (
    $env.CONFIG_DIR?
    | default ($env.HOME | path join ".config" "sketchybar")
  )
  let plugin_dir = ($config_dir | path join "plugins")
  let sketchybar = ($env.SKETCHYBAR? | default "/opt/homebrew/bin/sketchybar")

  let bar = [
    "shadow=off"
    "height=37"
    "color=0x55@base00@"
    "position=top"
    "blur_radius=60"
    "notch_width=200"
    "padding_left=12"
    "padding_right=12"
  ]
  ^$sketchybar --bar ...$bar

  let defaults = [
    "padding_left=4"
    "padding_right=4"
    "icon.font=DepartureMono Nerd Font Mono:Regular:18.0"
    "label.font=DepartureMono Nerd Font Mono:Regular:15.0"
    "icon.color=0xff@base05@"
    "label.color=0xff@base05@"
    "icon.y_offset=0"
    "label.y_offset=0"
    "icon.padding_left=4"
    "icon.padding_right=4"
    "label.padding_left=4"
    "label.padding_right=4"
  ]
  ^$sketchybar --default ...$defaults

  let item_settings = [
    "drawing=off"
    "icon.drawing=on"
    "label.drawing=off"
    "icon.font=sketchybar-app-font:Regular:16.0"
    "icon.y_offset=0"
    "icon.color=0x80@base05@"
    "padding_left=4"
    "padding_right=4"
  ]
  mut left_items = []
  for index in 0..11 {
    let item = $"paperwm_($index)"
    $left_items = ($left_items | append [--add item $item left --set $item ...$item_settings])
  }
  ^$sketchybar ...$left_items

  let paneru_windows = ($plugin_dir | path join "paneru_windows.nu")
  let dns = ($plugin_dir | path join "dns.nu")
  let status = ($plugin_dir | path join "clock.nu")
  let timer_menu = ($plugin_dir | path join "timer_menu.nu")
  let volume = ($plugin_dir | path join "volume.nu")
  let battery = ($plugin_dir | path join "battery.nu")
  let right_items = [
    "--add" "item" "clock" "right"
    "--set" "clock" "update_freq=0" "script=" "label.align=right" "label.padding_right=10"
    "--add" "item" "dns" "right"
    "--set" "dns" "update_freq=0" $"script=($dns)" $"click_script=($dns)" "icon.drawing=off" "label=✱  ??" "label.width=58" "label.align=right" "width=62" "padding_right=0"
    "--subscribe" "dns" "system_woke"
    "--add" "item" "timer" "right"
    "--set" "timer" "update_freq=0" "script=" $"click_script=($timer_menu)" "icon.drawing=off" "label=00:00" "label.width=72" "label.align=right" "width=78" "padding_right=0"
    "--add" "item" "volume" "e"
    "--set" "volume" "icon.width=34" "icon.align=left" "label.width=58" "label.align=left" "width=108" $"script=($volume)"
    "--subscribe" "volume" "volume_change"
    "--add" "item" "battery" "q"
    "--set" "battery" "update_freq=0" "icon.width=34" "label.width=58" "width=108" $"script=($battery)"
    "--subscribe" "battery" "system_woke" "power_source_change"
  ]
  ^$sketchybar ...$right_items
  ^$sketchybar --update
  ^$paneru_windows once
  ^$status once
}

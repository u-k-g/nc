#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

# Paneru + SketchyBar configuration, invoked by sketchybarrc.
# Uses a fixed item pool controlled by the Paneru state subscriber.

def main [] {
  let config_dir = (
    $env.CONFIG_DIR?
    | default ($env.HOME | path join ".config" "sketchybar")
  )
  let plugin_dir = ($config_dir | path join "plugins")
  let temporary = ($env.TMPDIR? | default "" | str trim)
  let runtime_dir = if ($temporary | is-empty) {
    $env.HOME | path join "Library" "Caches" "sketchybar"
  } else {
    $temporary
  }
  let sketchybar = ($env.SKETCHYBAR? | default "/opt/homebrew/bin/sketchybar")

  mkdir $runtime_dir
  try { ^/bin/chmod 700 $runtime_dir }

  let bar = [
    "shadow=off"
    "height=37"
    "color=0x55000000"
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
    "icon.color=0xffffffff"
    "label.color=0xffffffff"
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
    "icon.color=0x60ffffff"
    "padding_left=4"
    "padding_right=4"
  ]
  for index in 0..11 {
    let item = $"paperwm_($index)"
    ^$sketchybar --add item $item left --set $item ...$item_settings
  }

  let paneru_windows = ($plugin_dir | path join "paneru_windows.nu")
  let subscriber_log = ($runtime_dir | path join "sketchybar_paneru_windows.log")
  let subscriber_label = "org.nixos.sketchybar.paneru-windows"
  let user_domain = $"gui/(^/usr/bin/id -u | str trim)"
  ^/bin/launchctl bootout $"($user_domain)/($subscriber_label)" | complete | ignore

  let subscriber = (
    ^/bin/launchctl submit
      -l $subscriber_label
      -o $subscriber_log
      -e $subscriber_log
      -- $paneru_windows
    | complete
  )
  if $subscriber.exit_code != 0 {
    print --stderr ($subscriber.stderr | str trim)
  }

  let clock = ($plugin_dir | path join "clock.nu")
  let dns = ($plugin_dir | path join "dns.nu")
  let timer = ($plugin_dir | path join "timer.nu")
  let timer_menu = ($plugin_dir | path join "timer_menu.nu")
  let volume = ($plugin_dir | path join "volume.nu")
  let battery = ($plugin_dir | path join "battery.nu")
  let right_items = [
    "--add" "item" "clock" "right"
    "--set" "clock" "update_freq=1" $"script=($clock)" "label.align=right" "label.padding_right=10"
    "--add" "item" "dns" "right"
    "--set" "dns" "update_freq=10" $"script=($dns)" $"click_script=($dns)" "icon.drawing=off" "label=✱  ??" "label.width=58" "label.align=right" "width=62" "padding_right=0"
    "--subscribe" "dns" "system_woke"
    "--add" "item" "timer" "right"
    "--set" "timer" "update_freq=1" $"script=($timer)" $"click_script=($timer_menu)" "icon.drawing=off" "label=00:00" "label.width=72" "label.align=right" "width=78" "padding_right=0"
    "--add" "item" "volume" "e"
    "--set" "volume" "icon.width=34" "icon.align=left" "label.width=58" "label.align=left" "width=108" $"script=($volume)"
    "--subscribe" "volume" "volume_change"
    "--add" "item" "battery" "q"
    "--set" "battery" "icon.width=34" "label.width=58" "width=108" "update_freq=120" $"script=($battery)"
    "--subscribe" "battery" "system_woke" "power_source_change"
  ]
  ^$sketchybar ...$right_items
  ^$sketchybar --update
}

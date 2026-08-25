#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

def volume-icon [volume: int] {
  if $volume >= 66 { "XXX" } else if $volume >= 33 { "|||" } else if $volume >= 10 { "||·" } else if $volume >= 1 { "|··" } else { "···" }
}

def main [] {
  let name = ($env.NAME? | default "volume")
  let sketchybar = ($env.SKETCHYBAR? | default "/opt/homebrew/bin/sketchybar")
  let sender = ($env.SENDER? | default "")
  let volume = if $sender == "volume_change" {
    $env.INFO? | default 0 | into int
  } else {
    try { ^/usr/bin/osascript -e 'output volume of (get volume settings)' | str trim | into int } catch { return }
  }
  let icon = (volume-icon $volume)
  ^$sketchybar --set $name $"icon=($icon)" $"label= ($volume)%"
}

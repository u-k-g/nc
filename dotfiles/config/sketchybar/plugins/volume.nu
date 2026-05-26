#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

def volume-icon [volume: int] {
  if $volume >= 66 { "XXX" } else if $volume >= 33 { "|||" } else if $volume >= 10 { "||·" } else if $volume >= 1 { "|··" } else { "···" }
}

def main [] {
  if (($env.SENDER? | default "") != "volume_change") { return }

  let name = ($env.NAME? | default "volume")
  let volume = ($env.INFO? | default 0 | into int)
  let icon = (volume-icon $volume)
  ^sketchybar --set $name $"icon=($icon)" $"label= ($volume)%"
}

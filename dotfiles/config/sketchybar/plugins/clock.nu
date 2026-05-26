#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

def main [] {
  let name = ($env.NAME? | default "clock")
  let label = (date now | format date '✱  %A %-m.%-d  ✱  %I:%M:%S' | str downcase)
  ^sketchybar --set $name $"label=($label)"
}

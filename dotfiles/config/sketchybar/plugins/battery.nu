#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

def battery-icon [percentage: int, charging: bool] {
  if $charging { return "›››" }
  if $percentage >= 80 { "|||" } else if $percentage >= 34 { "||·" } else if $percentage >= 11 { "|··" } else if $percentage == 10 { "!··" } else { "···" }
}

export def battery-properties [] {
  let info = (^/usr/bin/pmset -g batt)
  let percentage = ($info | parse --regex '(?P<percentage>\d+)%' | get --optional 0.percentage | into int)
  if $percentage == null { return null }

  {
    icon: (battery-icon $percentage ($info | str contains 'AC Power'))
    label: $" ($percentage)%"
  }
}

def main [] {
  let name = ($env.NAME? | default "battery")
  let sketchybar = ($env.SKETCHYBAR? | default "/opt/homebrew/bin/sketchybar")
  let properties = (battery-properties)
  if $properties == null { return }

  ^$sketchybar --set $name $"icon=($properties.icon)" $"label=($properties.label)"
}

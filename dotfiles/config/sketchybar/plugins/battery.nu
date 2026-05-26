#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

def battery-icon [percentage: int, charging: bool] {
  if $charging { return "›››" }
  if $percentage >= 80 { "|||" } else if $percentage >= 34 { "||·" } else if $percentage >= 11 { "|··" } else if $percentage == 10 { "!··" } else { "···" }
}

def main [] {
  let name = ($env.NAME? | default "battery")
  let info = (^pmset -g batt)
  let percentage = ($info | parse --regex '(?P<percentage>\d+)%' | get --optional 0.percentage | into int)
  if $percentage == null { return }

  let charging = ($info | str contains 'AC Power')
  let icon = (battery-icon $percentage $charging)
  ^sketchybar --set $name $"icon=($icon)" $"label= ($percentage)%"
}

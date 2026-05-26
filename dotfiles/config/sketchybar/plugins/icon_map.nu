#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

def match-pattern [name: string, pattern: string, star: bool] {
  if $star { $name | str starts-with $pattern } else { $name == $pattern }
}

def icon-for-app [name: string] {
  let source = ($env.CONFIG_DIR? | default ($env.HOME + "/.config/sketchybar") | path join plugins icon_map.data)
  mut patterns = []

  for line in (open $source | lines) {
    let trimmed = ($line | str trim)
    if ($trimmed | str ends-with ')') and not ($trimmed | str starts-with 'case ') and not ($trimmed | str starts-with 'for ') {
      $patterns = ($trimmed | parse --regex '"(?P<pattern>[^"]+)"(?P<star>\*)?' | each {|it| { pattern: $it.pattern star: (($it.star? | default '') == '*') } })
    }

    if ($trimmed | str starts-with 'icon_result=') {
      let icon = ($trimmed | parse --regex 'icon_result="(?P<icon>[^"]+)"' | get --optional 0.icon | default ':default:')
      for pattern in $patterns {
        if (match-pattern $name $pattern.pattern $pattern.star) { return $icon }
      }
      $patterns = []
    }
  }

  ':default:'
}

def main [...apps: string] {
  let names = (if (($apps | length) == 0) { [''] } else { $apps })
  $names | each {|name| icon-for-app $name } | str join ' '
}

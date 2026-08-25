#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

def match-pattern [name: string, pattern: string, star: bool] {
  if $star { $name | str starts-with $pattern } else { $name == $pattern }
}

export def load-icon-map [] {
  let plugin_dir = ($env.CONFIG_DIR? | default ($env.HOME + "/.config/sketchybar") | path join plugins)
  let compiled = ($plugin_dir | path join icon_map.nuon)
  if ($compiled | path exists) { return (open $compiled) }

  let source = ($plugin_dir | path join icon_map.data)
  mut patterns = []
  mut entries = []

  for line in (open $source | lines) {
    let trimmed = ($line | str trim)
    if ($trimmed | str ends-with ')') and not ($trimmed | str starts-with 'case ') and not ($trimmed | str starts-with 'for ') {
      $patterns = (
        $trimmed
        | split row '|'
        | each {|part|
            $part
            | str trim
            | parse --regex '^"(?P<pattern>[^"]+)"(?P<star>\*)?\)?$'
            | first
            | default null
          }
        | compact
        | each {|it| { pattern: $it.pattern star: (($it.star? | default '') == '*') } }
      )
    }

    if ($trimmed | str starts-with 'icon_result=') {
      let icon = ($trimmed | parse --regex 'icon_result="(?P<icon>[^"]+)"' | get --optional 0.icon | default ':default:')
      for pattern in $patterns {
        $entries = ($entries | append ($pattern | insert icon $icon))
      }
      $patterns = []
    }
  }

  $entries
}

export def icon-for-app [name: string, icon_map?: list] {
  let entries = ($icon_map | default (load-icon-map))
  for entry in $entries {
    if (match-pattern $name $entry.pattern $entry.star) { return $entry.icon }
  }

  ':default:'
}

def main [--dump, ...apps: string] {
  let icon_map = (load-icon-map)
  if $dump { return ($icon_map | to nuon) }

  let names = (if (($apps | length) == 0) { [''] } else { $apps })
  $names | each {|name| icon-for-app $name $icon_map } | str join ' '
}

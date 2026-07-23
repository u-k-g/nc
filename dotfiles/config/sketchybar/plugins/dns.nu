#!/usr/bin/env -S /etc/profiles/per-user/uzair/bin/nu --no-config-file

def dns-label [dns_command: string] {
  let status = (^$dns_command status | complete)
  if $status.exit_code != 0 {
    return "??"
  }

  let profile = ($status.stdout | str trim)
  if ($profile | str starts-with "mullvad") {
    "mv"
  } else if ($profile | str starts-with "cloudflare") {
    "cf"
  } else if ($profile | str starts-with "automatic") {
    "no"
  } else {
    "??"
  }
}

def main [] {
  let dns_command = ($env.DNS_COMMAND? | default "/run/current-system/sw/bin/dns")
  let sketchybar = ($env.SKETCHYBAR? | default "/opt/homebrew/bin/sketchybar")
  let sender = ($env.SENDER? | default "")

  if $sender == "mouse.clicked" {
    ^/usr/bin/sudo -n $dns_command cycle | complete | ignore
  }

  let name = ($env.NAME? | default "dns")
  let label = (dns-label $dns_command)
  ^$sketchybar --set $name $"label=✱  ($label)"
}

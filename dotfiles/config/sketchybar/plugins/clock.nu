#!/usr/bin/env -S nu --no-config-file

use battery.nu [battery-properties]
use dns.nu [dns-label]
use timer.nu [timer-properties]

export def clock-label [] {
  date now | format date '✱  %A %-m.%-d  ✱  %I:%M:%S' | str lowercase
}

def env-default [name: string, fallback: string] {
  $env | get --optional $name | default $fallback
}

export def update-status [include_dns: bool = false, include_battery: bool = false] {
  let sketchybar = (env-default SKETCHYBAR "/opt/homebrew/bin/sketchybar")
  let timer = (timer-properties)
  mut args = [
    --set clock $"label=(clock-label)"
    --set timer $"label=($timer.label)" $"label.color=($timer.color)"
  ]
  ^$sketchybar ...$args

  # Keep slower external status queries off the one-second clock/timer path.
  $args = []

  if $include_dns {
    let dns_command = (env-default DNS_COMMAND "/run/current-system/sw/bin/dns")
    $args = ($args | append [--set dns $"label=✱  (dns-label $dns_command)"])
  }

  if $include_battery {
    let battery = (battery-properties)
    if $battery != null {
      $args = ($args | append [
        --set battery
        $"icon=($battery.icon)"
        $"label=($battery.label)"
      ])
    }
  }

  if not ($args | is-empty) { ^$sketchybar ...$args }
}

def status-loop [] {
  mut tick = 0
  loop {
    update-status (($tick mod 10) == 0) (($tick mod 120) == 0)
    $tick = $tick + 1

    # Stay aligned to wall-clock seconds instead of drifting by update time.
    let now_ms = ((date now | into int) // 1_000_000)
    let wait_ms = (1000 - ($now_ms mod 1000))
    sleep ($wait_ms * 1ms)
  }
}

def main [mode?: string] {
  if $mode == "once" { update-status true true } else { status-loop }
}

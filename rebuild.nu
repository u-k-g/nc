#!/usr/bin/env nu

# Rebuild a NixOS / Darwin config. This intentionally delegates activation to
# nh instead of calling /run/current-system directly.
def main --wrapped [
  host: string = "" # The host to build.
  ...arguments      # Arguments passed to `nh {os,darwin} switch`, then nix after --.
]: nothing -> nothing {
  let host = if ($host | is-not-empty) {
    if $host != (hostname) {
      print $"(ansi yellow_bold)warn:(ansi reset) building local configuration for hostname that does not match the local machine"
    }

    $host
  } else {
    (hostname)
  }

  let args_split = $arguments | prepend "" | split list "--"
  let nh_flags = ["--hostname" $host] | append ($args_split | get 0 | where { $in != "" })
  let nix_flags = [
    "--accept-flake-config"
    "--extra-experimental-features" "pipe-operators"
  ] | append ($args_split | get --optional 1 | default [])

  if (uname | get kernel-name) == "Darwin" {
    nh darwin switch . ...$nh_flags -- ...$nix_flags
  } else {
    NH_BYPASS_ROOT_CHECK=true nh os switch . ...$nh_flags -- ...$nix_flags
  }
}

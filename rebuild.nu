#!/usr/bin/env nu

def build [
  installable: string
  options: list<string>
  arguments: list<string>
]: nothing -> string {
  let paths = (^nix build
    "--accept-flake-config"
    "--extra-experimental-features" "pipe-operators"
    "--print-out-paths"
    "--no-link"
    ...$options
    ...$arguments
    $installable)

  $paths | lines | last | str trim
}

# Build and activate a local NixOS or nix-darwin configuration. A different
# hostname is treated as a remote NixOS deployment unless --local is supplied.
def main [
  host: string = ""                     # Configuration name; defaults to this machine's hostname.
  --flake (-f): string = ""              # Flake reference; defaults to NC_FLAKE or the current directory.
  --target (-t): string = ""             # SSH target when it differs from the configuration name.
  --local (-l)                            # Build a non-matching configuration for the local machine.
  --action (-a): string = "switch"       # NixOS activation action, or "build" to skip activation.
  ...arguments: string                    # Additional arguments passed to nix build.
]: nothing -> nothing {
  let local_host = sys host | get hostname
  let configuration = if ($host | is-empty) { $local_host } else { $host }
  let flake = if ($flake | is-not-empty) {
    $flake
  } else {
    $env.NC_FLAKE? | default "."
  }
  let ssh_target = if ($target | is-empty) { $configuration } else { $target }
  let remote = not $local and (($target | is-not-empty) or $configuration != $local_host)

  if $remote {
    if not ($action in ["boot" "build" "dry-activate" "switch" "test"]) {
      error make { msg: $"unsupported NixOS activation action: ($action)" }
    }

    let installable = $"($flake)#nixosConfigurations.($configuration).config.system.build.toplevel"
    let system = build $installable [
      "--eval-store" "auto"
      "--store" $"ssh-ng://($ssh_target)"
    ] $arguments

    if $action == "build" {
      print $system
      return
    }

    ^ssh $ssh_target $"sudo ($system)/bin/switch-to-configuration ($action)"
    return
  }

  if (sys host | get name) == "Darwin" {
    if not ($action in ["activate" "build" "switch"]) {
      error make { msg: $"unsupported nix-darwin activation action: ($action)" }
    }

    let installable = $"($flake)#darwinConfigurations.($configuration).system"
    let system = build $installable [] $arguments

    if $action == "build" {
      print $system
      return
    }

    ^sudo $"($system)/sw/bin/darwin-rebuild" activate
  } else {
    if not ($action in ["boot" "build" "dry-activate" "switch" "test"]) {
      error make { msg: $"unsupported NixOS activation action: ($action)" }
    }

    let installable = $"($flake)#nixosConfigurations.($configuration).config.system.build.toplevel"
    let system = build $installable [] $arguments

    if $action == "build" {
      print $system
      return
    }

    ^sudo $"($system)/bin/switch-to-configuration" $action
  }
}

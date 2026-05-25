#!/usr/bin/env nu

def current-system-path [host: string] {
  if $host == "macbook" {
    "/run/current-system"
  } else {
    "/run/current-system"
  }
}

def target-attr [host: string] {
  if $host == "macbook" {
    $".#darwinConfigurations.($host).config.system.build.toplevel"
  } else {
    $".#nixosConfigurations.($host).config.system.build.toplevel"
  }
}

def substituters [] {
  "https://cache.nixos.org/ https://nix-community.cachix.org/"
}

def trusted-public-keys [] {
  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
}

def ssl-cert-file [] {
  "/etc/ssl/cert.pem"
}

def switch-command [host: string] {
  if $host == "macbook" {
    [
      sudo
      /run/current-system/sw/bin/darwin-rebuild
      switch
      --flake
      $".#($host)"
      --substituters
      (substituters)
      --option
      trusted-public-keys
      (trusted-public-keys)
      --option
      ssl-cert-file
      (ssl-cert-file)
    ]
  } else {
    [
      sudo
      nixos-rebuild
      switch
      --flake
      $".#($host)"
      --substituters
      (substituters)
      --option
      trusted-public-keys
      (trusted-public-keys)
      --option
      ssl-cert-file
      (ssl-cert-file)
    ]
  }
}

def main [
  host: string = "macbook"
  --switch(-s)
] {
  let attr = (target-attr $host)
  let result = ($env.PWD | path join $"result-($host)")

  print $"building ($attr)"
  nix --extra-experimental-features pipe-operators --substituters (substituters) --option trusted-public-keys (trusted-public-keys) --option ssl-cert-file (ssl-cert-file) build $attr --out-link $result

  let current = (current-system-path $host)
  if ($current | path exists) and ((which dix | is-not-empty)) {
    print $"\nclosure diff: ($current) -> ($result)"
    dix $current $result
  } else {
    print "\nclosure diff skipped: no current system or dix not installed"
  }

  if $switch {
    let cmd = (switch-command $host)
    print $"\nswitching with: ($cmd | str join ' ')"
    ^($cmd | get 0) ...($cmd | skip 1)
  } else {
    print $"\nbuild complete: ($result)"
    print "rerun with --switch to activate"
  }
}

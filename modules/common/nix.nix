{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.meta) getExe;

  registry = {
    default = inputs.nixpkgs;
    nixpkgs = inputs.nixpkgs;
    hjem = inputs.hjem;
    nix-darwin = inputs.nix-darwin;
    agenix = inputs.agenix;
    themes = inputs.themes;
  };

  nixRunShortcuts = pkgs.writeText "nix-run-shortcuts.nu" ''
    def --wrapped * [program: string = "", ...arguments] {
      if ($program | str contains "#") or ($program | str contains ":") {
        nix run $program -- ...$arguments
      } else {
        nix run ("default#" + $program) -- ...$arguments
      }
    }

    # `nix shell` execs $SHELL, which dev shells clobber with the stdenv
    # build bash. Spawn nushell explicitly unless a command was given.
    def --wrapped > [...arguments: string] {
      let installables = $arguments | each {
        if ($in | str contains "#") or ($in | str contains ":") {
          $in
        } else {
          "default#" + $in
        }
      }

      if ("-c" in $arguments) or ("--command" in $arguments) {
        nix shell ...$installables
      } else {
        nix shell ...$installables -c ${getExe pkgs.nushell}
      }
    }
  '';
in

{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    pkgs.nix-index
    pkgs.nix-output-monitor
    self.packages.${pkgs.stdenv.hostPlatform.system}.rebuild
  ];

  nix = {
    enable = true;
    package = pkgs.nixVersions.latest;
    channel.enable = false;

    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
      "default=${inputs.nixpkgs}"
      "nc=${self}"
    ];

    registry = lib.mapAttrs (_: flake: { inherit flake; }) registry;

    settings =
      (import <| self + /flake.nix).nixConfig
      // optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        ssl-cert-file = "/etc/ssl/cert.pem";
      };

    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };

    optimise.automatic = true;
  };

  home.users.${config.nc.user.name}.xdg.config.files."nushell/config.nu".text =
    lib.modules.mkAfter "source ${nixRunShortcuts}\n";
}

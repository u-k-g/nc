{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  registry = {
    default = inputs.nixpkgs;
    nixpkgs = inputs.nixpkgs;
    home-manager = inputs.home-manager;
    nix-darwin = inputs.nix-darwin;
    agenix = inputs.agenix;
    themes = inputs.themes;
  };
in

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [
    pkgs.nh
    pkgs.nix-index
    pkgs.nix-output-monitor
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

    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
        "pipe-operators"
      ];

      extra-substituters = [
        "https://nix-community.cachix.org/"
      ];

      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      builders-use-substitutes = true;
      flake-registry = "";
      http-connections = 50;
      keep-derivations = true;
      keep-outputs = true;
      show-trace = true;
      ssl-cert-file = "/etc/ssl/cert.pem";
      trusted-users = [
        "root"
        "@admin"
        "@wheel"
      ];
      use-xdg-base-directories = true;
      warn-dirty = false;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };

    optimise.automatic = true;
  };
}

{
  description = "Nix Flake Vault";

  nixConfig = {
    experimental-features = [
      "flakes"
      "nix-command"
      "pipe-operators"
    ];

    extra-substituters = [
      "https://nyx-cache.chaotic.cx/"
      "https://nix-community.cachix.org/"
    ];

    extra-trusted-public-keys = [
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    builders-use-substitutes = true;
    flake-registry = "";
    http-connections = 50;
    show-trace = true;
    trusted-users = [
      "root"
      "@admin"
      "@wheel"
    ];
    use-xdg-base-directories = true;
    warn-dirty = false;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    hermes-agent.url = "github:NousResearch/hermes-agent";

    hermes-desktop-web = {
      url = "github:lgc2333/hermes-agent-desktop-web/f1ae2bb3efe0ed25d73a65367f401a1eaf6781eb";
      flake = false;
    };

    codex = {
      url = "github:NixOS/nixpkgs/master";
    };

    t3 = {
      url = "github:pingdotgg/t3code";
      flake = false;
    };

    nixpkgs-install-media.url = "github:NixOS/nixpkgs/a3116115851d68b8952a2a4221cc25a84e56b532";

    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.home-manager.follows = "";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:RGBCube/disko/fix-bcachefs-unlock";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hjem = {
      url = "github:feel-co/hjem?ref=pull/167/merge";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-apple = {
      url = "github:apple/homebrew-apple";
      flake = false;
    };

    homebrew-felixkratz = {
      url = "github:FelixKratz/homebrew-formulae";
      flake = false;
    };

    homebrew-osx-cross-arm = {
      url = "github:osx-cross/homebrew-arm";
      flake = false;
    };

    homebrew-tinycast = {
      url = "github:abue-ammar/homebrew-tinycast";
      flake = false;
    };

    themes.url = "github:RGBCube/ThemeNix";

    paperwm = {
      url = "git+https://github.com/mogenson/PaperWM.spoon.git";
      flake = false;
    };

    paneru = {
      url = "github:u-k-g/paneru";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nix-darwin.follows = "nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "nix-darwin";
      inputs.home-manager.follows = "";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs.lib.attrsets) filterAttrs mapAttrs' nameValuePair;
      inherit (inputs.nixpkgs.lib.filesystem) readDir;
      inherit (inputs.nixpkgs.lib.strings) hasSuffix removeSuffix;

      readCoal =
        directory:
        readDir directory
        |> filterAttrs (name: _: hasSuffix ".nix" name)
        |> mapAttrs' (name: _: nameValuePair (removeSuffix ".nix" name) "${directory}/${name}");
    in
    (import "${inputs.flake-parts}/lib.nix" {
      lib = import ./lib inputs.nixpkgs.lib;

      builtinModules = readCoal "${inputs.flake-parts}/modules";
      extraModules = readCoal "${inputs.flake-parts}/extras";
    }).mkFlake
      { inherit inputs; }
      (
        { lib, ... }:
        let
          inherit (lib.filesystem) listFilesRecursive;
          inherit (lib.lists) filter;
          inherit (lib.strings) hasSuffix;
        in
        {
          systems = [
            "aarch64-darwin"
            "aarch64-linux"
            "x86_64-linux"
          ];

          imports = filter (hasSuffix ".mod.nix") (listFilesRecursive ./.);
        }
      );
}

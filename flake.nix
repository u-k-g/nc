{
  description = "Nix Collective";

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

    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
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

    home-manager = {
      url = "github:nix-community/home-manager";
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

    homebrew-cmux = {
      url = "github:manaflow-ai/homebrew-cmux";
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

    # Moving "latest release" URLs: flake.lock pins the content hash, and
    # `nix flake update` re-fetches them, re-pinning to the latest release.
    opencode-darwin-arm64 = {
      url = "https://github.com/anomalyco/opencode/releases/latest/download/opencode-darwin-arm64.zip";
      flake = false;
    };

    opencode-linux-x64 = {
      url = "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz";
      flake = false;
    };

    opencode-linux-x64-baseline = {
      url = "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64-baseline.tar.gz";
      flake = false;
    };

    opencode-desktop = {
      type = "file";
      url = "https://opencode.ai/download/stable/darwin-aarch64-dmg";
      flake = false;
    };

    # The release assets use versioned filenames, so consume the arm64 artifact
    # from the latest successful nightly release workflow. The lock file pins
    # its contents until `nix flake update` refreshes it.
    t3-code-nightly = {
      url = "https://nightly.link/pingdotgg/t3code/workflows/release.yml/main/desktop-mac-arm64.zip";
      flake = false;
    };

    themes.url = "github:RGBCube/ThemeNix";

    paperwm = {
      url = "github:u-k-g/PaperWM.spoon/a0fd35ae";
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
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
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

        perSystem =
          { pkgs, ... }:
          {
            formatter = pkgs.writeShellApplication {
              name = "nc-fmt";
              runtimeInputs = [
                pkgs.git
                pkgs.nixfmt
              ];
              text = ''
                if [ "$#" -eq 0 ]; then
                  git ls-files '*.nix' | xargs nixfmt
                else
                  nixfmt "$@"
                fi
              '';
            };
          };
      }
    );
}

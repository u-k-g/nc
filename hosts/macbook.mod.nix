{
  inputs,
  lib,
  self,
  ...
}:

let
  inherit (lib.attrsets) attrValues;
in

{
  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";

    specialArgs = {
      inherit inputs self;
    };

    modules =
      [
        inputs.home-manager.darwinModules.home-manager
        inputs.homebrew.darwinModules.nix-homebrew
      ]
      ++ attrValues self.commonModules
      ++ attrValues self.darwinModules
      ++ [
      ./macbook/default.nix
      ];
  };
}

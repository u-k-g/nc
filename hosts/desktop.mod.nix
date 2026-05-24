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
  flake.nixosConfigurations.desktop = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    specialArgs = {
      inherit inputs self;
    };

    modules =
      [ inputs.home-manager.nixosModules.home-manager ]
      ++ attrValues self.commonModules
      ++ attrValues self.nixosModules
      ++ [ ./desktop/default.nix ];
  };
}

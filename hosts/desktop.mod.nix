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
    specialArgs = {
      inherit inputs self;
    };

    modules = [
      inputs.chaotic.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
    ]
    ++ attrValues self.commonModules
    ++ attrValues self.nixosModules
    ++ [
      ./desktop/default.nix
    ];
  };
}

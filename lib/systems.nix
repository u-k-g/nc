{ self }:
let
  inherit (self.attrsets) attrValues;
in
{
  systems.darwinSystem =
    hostName: module:
    { inputs, ... }:
    {
      flake.darwinConfigurations.${hostName} = inputs.nix-darwin.lib.darwinSystem {
        lib = self;

        specialArgs = {
          inherit inputs;
          self = inputs.self;
        };

        modules = [
          inputs.homebrew.darwinModules.nix-homebrew
        ]
        ++ attrValues inputs.self.darwinModules
        ++ [
          module
          { networking.hostName = hostName; }
        ];
      };
    };

  systems.nixosSystem =
    hostName: module:
    { inputs, ... }:
    {
      flake.nixosConfigurations.${hostName} = inputs.nixpkgs.lib.nixosSystem {
        lib = self;

        specialArgs = {
          inherit inputs;
          self = inputs.self;
        };

        modules = [
          inputs.chaotic.nixosModules.default
        ]
        ++ attrValues inputs.self.nixosModules
        ++ [
          module
          { networking.hostName = hostName; }
        ];
      };
    };
}

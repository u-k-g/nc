{ inputs, self, ... }:

{
  flake.homeModules.default = self.homeModules.base;

  commonModules.home =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) attrValues;
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = singleton <| mkAliasOptionModule [ "home" ] [ "hjem" ];

      home = {
        clobberByDefault = true;
        extraModules = attrValues self.homeModules;
        specialArgs = { inherit inputs; };

        users.${config.nc.user.name}.directory = config.nc.user.homeDirectory;
      };
    };

  flake.nixosModules.home =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton inputs.hjem.nixosModules.hjem;
    };

  flake.darwinModules.home = inputs.hjem.darwinModules.hjem;
}

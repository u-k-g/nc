{
  config,
  inputs,
  lib,
  self,
  ...
}:

let
  inherit (lib.attrsets) attrValues;
in

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = attrValues self.homeModules;
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${config.nc.user.name} = {
      home = {
        username = config.nc.user.name;
        homeDirectory = config.nc.user.homeDirectory;
        stateVersion = "25.05";
      };
    };
  };
}

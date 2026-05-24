{ config, inputs, ... }:

{
  home-manager = {
    backupFileExtension = "hm-backup";
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${config.nc.user.name} = {
      home = {
        username = config.nc.user.name;
        homeDirectory = config.nc.user.homeDirectory;
        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };
}

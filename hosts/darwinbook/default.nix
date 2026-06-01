{ config, pkgs, ... }:

{
  nc.user = {
    name = "uzair";
    handle = "ukg";
    homeDirectory = "/Users/uzair";
  };

  system.stateVersion = 6;
  system.primaryUser = config.nc.user.name;

  home-manager.backupFileExtension = "backup";

  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.${config.nc.user.name} = {
    home = config.nc.user.homeDirectory;
    shell = pkgs.nushell;
  };

  programs.zsh.enable = true;
}

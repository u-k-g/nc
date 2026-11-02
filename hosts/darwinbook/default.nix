{ config, pkgs, ... }:

{
  nc.user = {
    name = "uzair";
    handle = "ukg";
    homeDirectory = "/Users/uzair";
  };

  system.stateVersion = 6;

  nc.darwin.nehir.enable = false;
  nc.darwin.paneru.enable = true;
  nc.syncthing.enable = true;

  # Autolith only runs on manara.
  nc.autolith.enable = false;

  system.primaryUser = config.nc.user.name;

  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.${config.nc.user.name} = {
    home = config.nc.user.homeDirectory;
    shell = pkgs.nushell;
  };

  programs.zsh.enable = true;
}

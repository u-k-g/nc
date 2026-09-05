{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.meta) getExe;
in
{
  nc.user = {
    name = "uzair";
    handle = "ukg";
    homeDirectory = "/Users/uzair";
  };

  system.stateVersion = 6;
  system.primaryUser = config.nc.user.name;

  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.${config.nc.user.name} = {
    home = config.nc.user.homeDirectory;
    shell = pkgs.nushell;
  };

  programs.zsh.enable = true;

  launchd.daemons.tailscale-allow-incoming = {
    command = "${getExe config.services.tailscale.package} set --shields-up=false";
    serviceConfig.KeepAlive.SuccessfulExit = false;
  };
}

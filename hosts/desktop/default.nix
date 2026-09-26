{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./hardware.nix ];

  nc.user = {
    name = "ukg";
    handle = "ukg";
    homeDirectory = "/home/ukg";
  };

  networking.hostName = "desktop";

  nc.nixos.workstation.enable = true;
  nc.nixos.niri.enable = true;
  nc.nixos.nvidia.enable = true;
  nc.autolith.enable = false;
  nc.radicle.enable = false;

  programs.blip.enable = true;

  services.desktopManager.plasma6.enable = lib.mkForce false;

  hardware.enableRedistributableFirmware = true;

  zramSwap.enable = true;

  users.users.${config.nc.user.name} = {
    isNormalUser = true;
    home = config.nc.user.homeDirectory;
    shell = pkgs.nushell;
    extraGroups = [
      "input"
      "networkmanager"
      "wheel"
    ];
  };

  system.stateVersion = "25.05";
}

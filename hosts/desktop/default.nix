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

  # Also available: "black-metal", "gruvbox-dark-hard", "rose-pine", and "matte-black".
  nc.themePreset = "grove";

  networking.hostName = "desktop";

  nc.nixos.nvidia.enable = true;
  nc.radicle.enable = false;

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

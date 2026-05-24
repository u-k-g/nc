{ config, pkgs, ... }:

{
  nc.user = {
    name = "ukg";
    handle = "ukg";
    homeDirectory = "/home/ukg";
  };

  networking.hostName = "desktop";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];

  users.users.${config.nc.user.name} = {
    isNormalUser = true;
    home = config.nc.user.homeDirectory;
    shell = pkgs.nushell;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  system.stateVersion = "25.05";
}

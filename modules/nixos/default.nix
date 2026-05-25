{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  services.openssh.enable = true;

  time.timeZone = "America/New_York";

  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = true;
}

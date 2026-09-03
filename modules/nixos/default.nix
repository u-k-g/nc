{
  lib,
  pkgs,
  ...
}:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  services.openssh.enable = true;

  programs.mosh.enable = true;

  time.timeZone = "America/New_York";

  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = true;

  system.activationScripts.binbash = {
    deps = lib.lists.singleton "binsh";
    text = ''
      ln -sfn "${pkgs.bashInteractive}/bin/bash" /bin/.bash.tmp
      mv /bin/.bash.tmp /bin/bash
    '';
  };
}

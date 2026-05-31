{ pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_cachyos;
    kernelParams = [ "amd_pstate=active" ];
  };

  powerManagement = {
    cpuFreqGovernor = "performance";
    powertop.enable = false;
  };

  services = {
    power-profiles-daemon.enable = false;
    tlp.enable = false;
  };

  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };

    gamemode.enable = true;
    gamescope.enable = true;
  };

  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  environment.systemPackages = with pkgs; [
    jdk17
    jdk21
    mangohud
    prismlauncher
    protonup-qt
  ];
}

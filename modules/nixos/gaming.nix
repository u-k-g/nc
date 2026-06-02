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
    # scx_lavd is latency-oriented and usually feels good on the desktop.
    # For Minecraft on the Ryzen 3 3100, compare generations with:
    # - "scx_bpfland": can improve gaming-oriented interactivity/frame pacing.
    # - "scx_rusty": can behave better for mixed desktop + game workloads.
    # - services.scx.enable = false: lets CachyOS/BORE handle scheduling itself.
    # Keep whichever gives the best 1% lows and least frametime spikes, not just
    # the highest average FPS.
    scheduler = "scx_lavd";
  };

  environment.systemPackages = with pkgs; [
    jdk17
    jdk21
    mangohud
    protonup-qt
  ];
}

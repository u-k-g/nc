{
  config,
  pkgs,
  ...
}:

{
  programs = {
    niri.enable = true;
    xwayland.enable = true;

    dsearch = {
      enable = true;
      systemd.enable = true;
    };

    dms-shell = {
      enable = true;
      quickshell.package = pkgs.quickshell;
      systemd.enable = true;

      enableAudioWavelength = true;
      enableCalendarEvents = true;
      enableClipboardPaste = true;
      enableDynamicTheming = true;
      enableSystemMonitoring = true;
      enableVPN = true;
    };
  };

  services.displayManager = {
    defaultSession = "niri";

    dms-greeter = {
      enable = true;
      configHome = config.nc.user.homeDirectory;
      compositor.name = "niri";
      quickshell.package = pkgs.quickshell;
    };
  };

  environment.systemPackages = with pkgs; [
    dgop
    dms-shell
    dsearch
    matugen
    niri
    niriswitcher
    nirius
    nwg-displays
    sunsetr
  ];
}

{
  pkgs,
  ...
}:

{
  services = {
    dbus.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;

    xserver = {
      enable = true;
      xkb.layout = "us";
    };

    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    desktopManager.plasma6.enable = true;
  };

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };

  environment.systemPackages = with pkgs; [
    kdePackages.ark
    kdePackages.kcalc
    kdePackages.spectacle
    kdePackages.dolphin
    wl-clipboard
    xclip
  ];
}

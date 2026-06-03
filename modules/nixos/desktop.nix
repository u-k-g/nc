{
  lib,
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
      enable = false;
      wayland.enable = true;
    };

    desktopManager.plasma6.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.niri."org.freedesktop.impl.portal.Settings" = lib.mkForce "kde";
    xdgOpenUsePortal = true;
  };

  environment.systemPackages = with pkgs; [
    crossmacro
    kdePackages.ark
    kdePackages.kcalc
    kdePackages.spectacle
    kdePackages.dolphin
    modrinth-app
    wl-clipboard
    xclip
  ];
}

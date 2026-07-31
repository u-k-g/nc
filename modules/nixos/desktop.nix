{
  lib,
  pkgs,
  ...
}:

let
  modrinthApp = pkgs.modrinth-app.overrideAttrs (_: {
    # nixpkgs' symlinkJoin package calls wrapGAppsHook manually, outside the
    # normal fixupPhase scope where this variable is usually defined.
    output = "out";
  });
in
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
    kdePackages.kcalc
    kdePackages.spectacle
    modrinthApp
    wl-clipboard
    xclip
  ];
}

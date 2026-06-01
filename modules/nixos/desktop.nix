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
      enable = false;
      wayland.enable = true;
    };

    desktopManager.plasma6.enable = true;
  };

  programs.dconf.enable = true;

  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          capslock = "overload(hyper, esc)";

          # PC keyboards are Ctrl, Super, Alt; make them feel like macOS Ctrl, Opt, Cmd.
          leftmeta = "leftalt";
          leftalt = "leftmeta";
          rightmeta = "rightalt";
          rightalt = "rightmeta";
        };

        "hyper:C-M-A-S" = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";
        };
      };
    };
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd virtual keyboard]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';

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

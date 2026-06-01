{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) optionals;
  user = config.nc.user;
  dotfiles = ../../dotfiles;
  heliumBrowser = pkgs.callPackage ../../packages/helium-browser { };
in
{
  home-manager.users.${user.name} = {
    home.packages =
      with pkgs;
      [
        kitty
        obsidian
        prismlauncher
        zed-editor
      ]
      ++ optionals pkgs.stdenv.isDarwin [
        pkgs.ghostty-bin
      ]
      ++ optionals pkgs.stdenv.isLinux [
        pkgs.freecad
        pkgs.ghostty
        heliumBrowser
        pkgs.kicad
        pkgs.orca-slicer
        pkgs.ungoogled-chromium
        pkgs.vesktop
      ];

    xdg.configFile = {
      "FreeCAD".source = dotfiles + /config/FreeCAD;
    };

    xdg.dataFile = lib.mkIf pkgs.stdenv.isLinux {
      "applications/helium.desktop" = {
        force = true;
        source = "${heliumBrowser}/share/applications/helium.desktop";
      };
    };
  };
}

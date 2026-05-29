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
in
{
  home-manager.users.${user.name} = {
    home.packages =
      with pkgs;
      [
        kitty
        obsidian
        zed-editor
      ]
      ++ optionals pkgs.stdenv.isDarwin [
        pkgs.ghostty-bin
      ]
      ++ optionals pkgs.stdenv.isLinux [
        pkgs.freecad
        pkgs.ghostty
        pkgs.kicad
        pkgs.orca-slicer
        pkgs.vesktop
      ];

    xdg.configFile = {
      "FreeCAD".source = dotfiles + /config/FreeCAD;
    };
  };
}

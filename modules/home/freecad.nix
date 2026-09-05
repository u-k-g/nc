{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  user = config.nc.user;
  workstation = pkgs.stdenv.hostPlatform.isDarwin || config.nc.nixos.workstation.enable;
  freecadConfigSource = ../../dotfiles/config/FreeCAD/v1-1;
in
{
  home.users.${user.name} = mkIf workstation {
    packages = mkIf pkgs.stdenv.hostPlatform.isLinux <| singleton pkgs.freecad;

    xdg.config.files."FreeCAD/v1-1/system.cfg" = {
      source = freecadConfigSource + /system.cfg;
      type = "copy";
    };
    xdg.config.files."FreeCAD/v1-1/user.cfg" = {
      source = freecadConfigSource + /user.cfg;
      type = "copy";
    };
  };
}

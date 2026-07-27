{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  user = config.nc.user;
  freecadConfigSource = ../../dotfiles/config/FreeCAD/v1-1;
  freecadConfigTarget = "${config.home-manager.users.${user.name}.xdg.configHome}/FreeCAD/v1-1";
  install = getExe' pkgs.coreutils "install";
  mkdir = getExe' pkgs.coreutils "mkdir";
in
{
  home-manager.users.${user.name} = {
    home.packages = lib.mkIf pkgs.stdenv.isLinux <| singleton pkgs.freecad;

    home.activation.freecad-config =
      config.home-manager.users.${user.name}.lib.dag.entryAfter [ "linkGeneration" ]
        ''
          target=${lib.escapeShellArg freecadConfigTarget}
          ${mkdir} -p "$target"
          ${install} -m 0644 ${freecadConfigSource}/system.cfg "$target/system.cfg"
          ${install} -m 0644 ${freecadConfigSource}/user.cfg "$target/user.cfg"
        '';
  };
}

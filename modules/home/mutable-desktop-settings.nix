{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.meta) getExe';
  inherit (lib.modules) mkIf;
  user = config.nc.user;
  theme = config.nc.theme;
  homeManager = config.home-manager.users.${user.name};
  install = getExe' pkgs.coreutils "install";
  readlink = getExe' pkgs.coreutils "readlink";
  rm = getExe' pkgs.coreutils "rm";
in
{
  home-manager.users.${user.name}.home.activation.mutable-desktop-settings =
    mkIf pkgs.stdenv.isLinux
    <| homeManager.lib.dag.entryAfter [ "linkGeneration" ] ''
      make_mutable() {
        target="$1"
        if [ -L "$target" ]; then
          resolved="$(${readlink} -f "$target")"
          ${rm} -f "$target"
          ${install} -m 0644 "$resolved" "$target"
        fi
      }

      make_mutable ${lib.escapeShellArg "${user.homeDirectory}/.gtkrc-2.0"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.configHome}/DankMaterialShell/settings.json"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.configHome}/DankMaterialShell/themes/nc-${theme.slug}.json"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.configHome}/niri/config.kdl"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.configHome}/gtk-3.0/settings.ini"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.configHome}/gtk-4.0/settings.ini"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.configHome}/gtk-3.0/gtk.css"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.configHome}/gtk-4.0/gtk.css"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.configHome}/kdeglobals"}
      make_mutable ${lib.escapeShellArg "${homeManager.xdg.dataHome}/color-schemes/NC-${theme.slug}.colors"}
    '';
}

{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe';
  inherit (lib.strings) concatMapStringsSep;
  user = config.nc.user;
  theme = config.nc.theme;
  homeManager = config.home-manager.users.${user.name};
  install = getExe' pkgs.coreutils "install";
  readlink = getExe' pkgs.coreutils "readlink";
  rm = getExe' pkgs.coreutils "rm";

  mutableFiles = [
    "${user.homeDirectory}/.zshrc"
    "${homeManager.xdg.configHome}/nushell/config.nu"
    "${homeManager.xdg.configHome}/zsh/.zshrc"
  ]
  ++ optionals pkgs.stdenv.isLinux [
    "${user.homeDirectory}/.gtkrc-2.0"
    "${homeManager.xdg.configHome}/DankMaterialShell/settings.json"
    "${homeManager.xdg.configHome}/DankMaterialShell/themes/nc-${theme.slug}.json"
    "${homeManager.xdg.configHome}/niri/config.kdl"
    "${homeManager.xdg.configHome}/gtk-3.0/settings.ini"
    "${homeManager.xdg.configHome}/gtk-4.0/settings.ini"
    "${homeManager.xdg.configHome}/gtk-3.0/gtk.css"
    "${homeManager.xdg.configHome}/gtk-4.0/gtk.css"
    "${homeManager.xdg.configHome}/kdeglobals"
    "${homeManager.xdg.dataHome}/color-schemes/NC-${theme.slug}.colors"
  ];
in
{
  home-manager.users.${user.name}.home.activation.mutable-desktop-settings =
    homeManager.lib.dag.entryAfter [ "linkGeneration" ]
      ''
        make_mutable() {
          target="$1"
          if [ -L "$target" ]; then
            resolved="$(${readlink} -f "$target")"
            ${rm} -f "$target"
            ${install} -m 0644 "$resolved" "$target"
          fi
        }

        ${concatMapStringsSep "\n" (path: "make_mutable ${lib.escapeShellArg path}") mutableFiles}
      '';
}

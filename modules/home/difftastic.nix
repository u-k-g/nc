{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.options) mkOption;
  inherit (lib.types) package;
  user = config.nc.user;
in
{
  options.nc.difftastic.package = mkOption {
    type = package;
    default = pkgs.writeShellScriptBin "difft" ''
      exec ${getExe pkgs.difftastic} --background ${
        if config.nc.theme.isDark then "dark" else "light"
      } "$@"
    '';
    readOnly = true;
    internal = true;
    description = "Theme-aware Difftastic wrapper shared by Git and Jujutsu.";
  };

  config.home-manager.users.${user.name} = {
    home.packages = singleton config.nc.difftastic.package;

    programs.git.settings = {
      diff.external = getExe config.nc.difftastic.package;
      diff.tool = "difftastic";
      difftool.difftastic.cmd = ''${getExe config.nc.difftastic.package} "$LOCAL" "$REMOTE"'';
    };
  };
}

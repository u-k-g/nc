{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) getExe;
  user = config.nc.user;
  difft = pkgs.writeShellScriptBin "difft" ''
    exec ${getExe pkgs.difftastic} --background ${
      if config.nc.theme.isDark then "dark" else "light"
    } "$@"
  '';
in
{
  home-manager.users.${user.name} = {
    home.packages = [ difft ];

    programs.git.settings = {
      diff.external = getExe difft;
      diff.tool = "difftastic";
      difftool.difftastic.cmd = ''${getExe difft} "$LOCAL" "$REMOTE"'';
    };
  };
}

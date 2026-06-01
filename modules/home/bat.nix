{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) getExe;
  user = config.nc.user;
in
{
  home-manager.users.${user.name} = {
    home.packages = [
      pkgs.bat
      pkgs.less
    ];

    xdg.configFile = {
      "bat/config".text = ''
        --theme=base16
        --pager="${getExe pkgs.less} --quit-if-one-screen --quit-on-intr --RAW-CONTROL-CHARS"
      '';
      "bat/themes/base16.tmTheme".text = config.nc.theme.tmTheme;
    };
  };
}

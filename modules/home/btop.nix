{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.nc.user;
  color_theme = "base16";
in
{
  home-manager.users.${user.name} = {
    home.packages = [ pkgs.btop ];

    xdg.configFile = {
      "btop/themes/${color_theme}.theme".text = config.nc.theme.btopTheme;
      "btop/btop.conf".text = lib.generators.toKeyValue { } {
        inherit color_theme;
        rounded_corners = config.nc.theme.cornerRadius > 0;
      };
    };
  };
}

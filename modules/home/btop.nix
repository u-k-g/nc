{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;

  user = config.nc.user;
  color_theme = "base16";
in
{
  home.users.${user.name} = {
    packages = singleton pkgs.btop;

    xdg.config.files = {
      "btop/themes/${color_theme}.theme".text = config.nc.theme.btopTheme;
      "btop/btop.conf".text = lib.generators.toKeyValue { } {
        inherit color_theme;
        rounded_corners = config.nc.theme.cornerRadius > 0;
        vim_keys = true;
      };
    };
  };
}

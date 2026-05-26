{ config, ... }:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
in
{
  home-manager.users.${user.name} = {
    xdg.configFile = {
      "sketchybar".source = dotfiles + /config/sketchybar;
    };
  };
}

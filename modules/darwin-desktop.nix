{ config, ... }:

let
  user = config.nc.user;
  dotfiles = ../dotfiles;
in
{
  home-manager.users.${user.name} = {
    home.file.".hammerspoon/init.lua".source = dotfiles + /config/hammerspoon/init.lua;

    xdg.configFile = {
      "hammerspoon".source = dotfiles + /config/hammerspoon;
      "sketchybar".source = dotfiles + /config/sketchybar;
    };
  };
}

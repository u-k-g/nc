{ config, ... }:

let
  user = config.nc.user;
  dotfiles = ../../dotfiles;
in
{
  services.sketchybar = {
    enable = true;
    config = ''
      export CONFIG_DIR="${user.homeDirectory}/.config/sketchybar"
      source "$CONFIG_DIR/sketchybarrc"
    '';
  };

  home-manager.users.${user.name} = {
    xdg.configFile = {
      "sketchybar".source = dotfiles + /config/sketchybar;
    };
  };
}

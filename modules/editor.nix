{ config, ... }:

let
  user = config.nc.user;
  dotfiles = ../dotfiles;
in
{
  home-manager.users.${user.name} = {
    programs.helix = {
      enable = true;
      defaultEditor = true;
    };

    xdg.configFile = {
      "helix/config.toml".source = dotfiles + /config/helix/config.toml;
      "helix/languages.toml".source = dotfiles + /config/helix/languages.toml;
      "helix/themes".source = dotfiles + /config/helix/themes;
      "zed/settings.json".source = dotfiles + /config/zed/settings.json;
      "zed/keymap.json".source = dotfiles + /config/zed/keymap.json;
    };
  };
}

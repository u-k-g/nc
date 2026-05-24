{ config, lib, ... }:

let
  inherit (lib.modules) mkDefault;
in
{
  xdg.enable = true;

  home.sessionVariables = {
    XDG_CACHE_HOME = mkDefault "${config.home.homeDirectory}/.cache";
    XDG_CONFIG_HOME = mkDefault "${config.home.homeDirectory}/.config";
    XDG_DATA_HOME = mkDefault "${config.home.homeDirectory}/.local/share";
    XDG_STATE_HOME = mkDefault "${config.home.homeDirectory}/.local/state";
  };

  programs.home-manager.enable = true;
}

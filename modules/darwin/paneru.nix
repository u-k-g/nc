{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.options) mkEnableOption;
in
{
  imports = [ inputs.paneru.darwinModules.paneru ];

  options.nc.darwin.paneru.enable = mkEnableOption "Paneru window manager";

  config.services.paneru = {
    enable = config.nc.darwin.paneru.enable;
    package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.paneru;
    luaConfig.enable = true;
    config = pkgs.replaceVars ../../dotfiles/config/paneru/init.lua {
      base05 = config.nc.theme.base05;
      icon_map =
        pkgs.writeText "paneru-icon-map.data"
        <| lib.strings.fileContents ../../dotfiles/config/sketchybar/plugins/icon_map.data;
      sketchybar = "/opt/homebrew/bin/sketchybar";
    };
  };
}

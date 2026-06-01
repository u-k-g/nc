{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkOption types;
in
{
  options.nc.theme = mkOption {
    type = types.raw;
    default = inputs.themes.custom (
      inputs.themes.raw.gruvbox-dark-hard
      // {
        cornerRadius = 4;
        borderWidth = 2;

        margin = 0;
        padding = 8;

        font.size.normal = 16;
        font.size.big = 20;

        font.sans.name = "IBM Plex Sans";
        font.sans.package = pkgs.ibm-plex;

        font.mono.name = "Iosevka Nerd Font Mono";
        font.mono.package = pkgs.nerd-fonts.iosevka;

        icons.name = "Gruvbox-Plus-Dark";
        icons.package = pkgs.gruvbox-plus-icons;
      }
    );
    description = "Shared ThemeNix theme for NC modules.";
  };
}

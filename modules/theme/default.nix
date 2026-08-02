{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrs enum;
  themePresets = {
    black-metal = inputs.themes.raw.black-metal;
    gruvbox-dark-hard = inputs.themes.raw.gruvbox-dark-hard;
    rose-pine = inputs.themes.raw.rose-pine;
    matte-black = {
      name = "Matte Black";
      author = "Taha YVR";
      base00 = "121212";
      base01 = "1E1E1E";
      base02 = "333333";
      base03 = "8A8A8D";
      base04 = "BEBEBE";
      base05 = "BEBEBE";
      base06 = "EAEAEA";
      base07 = "FFFFFF";
      base08 = "D35F5F";
      base09 = "E68E0D";
      base0A = "FFC107";
      base0B = "FFC107";
      base0C = "BEBEBE";
      base0D = "E68E0D";
      base0E = "D35F5F";
      base0F = "B91C1C";
    };
  };
in
{
  options.nc = {
    themePreset = mkOption {
      type = enum [
        "black-metal"
        "gruvbox-dark-hard"
        "rose-pine"
        "matte-black"
      ];
      default = "black-metal";
      description = "Color preset used by every themed NC application.";
    };

    theme = mkOption {
      type = attrs;
      description = "Shared ThemeNix theme for NC modules.";
    };
  };

  config.nc.theme =
    inputs.themes.custom
    <|
      themePresets.${config.nc.themePreset}
      // {
        slug = config.nc.themePreset;

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

        icons.name = "Papirus-Dark";
        icons.package = pkgs.papirus-icon-theme;
      };
}

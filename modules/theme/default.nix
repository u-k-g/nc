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
    black-rose = {
      name = "Black Rose";
      author = "metalelf0";
      base00 = "000000";
      base01 = "121212";
      base02 = "222222";
      base03 = "333333";
      base04 = "999999";
      base05 = "C1C1C1";
      base06 = "999999";
      base07 = "C1C1C1";
      base08 = "5F8787";
      base09 = "AAAAAA";
      base0A = "A06666";
      base0B = "DD9999";
      base0C = "AAAAAA";
      base0D = "888888";
      base0E = "999999";
      base0F = "444444";
    };
    grove = {
      name = "Grove";
      author = "T3 Code";
      base00 = "1B2821";
      base01 = "21362B";
      base02 = "36654C";
      base03 = "919595";
      base04 = "A9ABAB";
      base05 = "FFFAFF";
      base06 = "FFFAFF";
      base07 = "FFFAFF";
      base08 = "FB414A";
      base09 = "FE9A00";
      base0A = "69D69A";
      base0B = "9EE4BE";
      base0C = "69D69A";
      base0D = "69D69A";
      base0E = "69D69A";
      base0F = "F07372";
    };
    jade = {
      name = "Jade";
      author = "steez";
      base00 = "071C15";
      base01 = "051910";
      base02 = "162920";
      base03 = "53685B";
      base04 = "718064";
      base05 = "FBFBF7";
      base06 = "FBFBF7";
      base07 = "FBFBF7";
      base08 = "FF5345";
      base09 = "E5C736";
      base0A = "6BC3BD";
      base0B = "63B07A";
      base0C = "6BC3BD";
      base0D = "6BC3BD";
      base0E = "D2689C";
      base0F = "509475";
    };
    gruvbox-dark-hard = inputs.themes.raw.gruvbox-dark-hard;
    rose-pine = inputs.themes.raw.rose-pine;
  };
in
{
  options.nc = {
    themePreset = mkOption {
      type = enum [
        "black-rose"
        "grove"
        "jade"
        "gruvbox-dark-hard"
        "rose-pine"
      ];
      default = "grove";
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

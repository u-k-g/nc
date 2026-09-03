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
      base00 = "06100C";
      base01 = "121C15";
      base02 = "18221A";
      base03 = "53685B";
      base04 = "718064";
      base05 = "CACE9E";
      base06 = "F6F5DD";
      base07 = "FAFAF5";
      base08 = "FF5345";
      base09 = "E5C736";
      base0A = "2DD5B7";
      base0B = "63B07A";
      base0C = "8CD3CB";
      base0D = "8CD3CB";
      base0E = "D2689C";
      base0F = "509475";
    };
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
        "grove"
        "jade"
        "gruvbox-dark-hard"
        "rose-pine"
        "matte-black"
      ];
      default = "jade";
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

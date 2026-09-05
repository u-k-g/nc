{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.modules) mkIf;
  inherit (lib.strings) substring;
  user = config.nc.user;
  theme = config.nc.theme;
  gtkThemeName = "Adwaita-dark";
  kdeColorSchemeName = "NC-${theme.slug}";
  gtkSettings = ''
    [Settings]
    gtk-application-prefer-dark-theme=true
    gtk-font-name=${theme.font.sans.name} ${toString theme.font.size.normal}
    gtk-icon-theme-name=${theme.icons.name}
    gtk-theme-name=${gtkThemeName}
  '';
  hexDigit = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    A = 10;
    B = 11;
    C = 12;
    D = 13;
    E = 14;
    F = 15;
    a = 10;
    b = 11;
    c = 12;
    d = 13;
    e = 14;
    f = 15;
  };
  hexPairToDec =
    value: offset:
    16 * hexDigit.${substring offset 1 value} + hexDigit.${substring (offset + 1) 1 value};
  hexToRgb =
    value:
    "${toString (hexPairToDec value 0)},${toString (hexPairToDec value 2)},${toString (hexPairToDec value 4)}";
  rgb = {
    bg0 = hexToRgb theme.base00;
    bg1 = hexToRgb theme.base01;
    bg2 = hexToRgb theme.base02;
    bg3 = hexToRgb theme.base03;
    fg0 = hexToRgb theme.base05;
    fg1 = hexToRgb theme.base06;
    red = hexToRgb theme.base08;
    orange = hexToRgb theme.base09;
    yellow = hexToRgb theme.base0A;
    green = hexToRgb theme.base0B;
    aqua = hexToRgb theme.base0C;
    blue = hexToRgb theme.base0D;
    purple = hexToRgb theme.base0E;
  };
  colorSet = normalBg: alternateBg: ''
    BackgroundAlternate=${alternateBg}
    BackgroundNormal=${normalBg}
    DecorationFocus=${rgb.yellow}
    DecorationHover=${rgb.aqua}
    ForegroundActive=${rgb.yellow}
    ForegroundInactive=${rgb.bg3}
    ForegroundLink=${rgb.blue}
    ForegroundNegative=${rgb.red}
    ForegroundNeutral=${rgb.orange}
    ForegroundNormal=${rgb.fg0}
    ForegroundPositive=${rgb.green}
    ForegroundVisited=${rgb.purple}
  '';
in
{
  home.users.${user.name} = mkIf pkgs.stdenv.hostPlatform.isLinux {
    packages = lib.lists.singleton theme.icons.package;

    environment.sessionVariables = {
      GTK_THEME = gtkThemeName;
      GTK2_RC_FILES = "${user.homeDirectory}/.gtkrc-2.0";
    };

    files.".gtkrc-2.0" = {
      type = "copy";
      text = ''
        gtk-theme-name="${gtkThemeName}"
        gtk-icon-theme-name="${theme.icons.name}"
        gtk-font-name="${theme.font.sans.name} ${toString theme.font.size.normal}"
        gtk-application-prefer-dark-theme=true
      '';
    };

    xdg.config.files = {
      "gtk-3.0/settings.ini" = {
        type = "copy";
        text = gtkSettings;
      };
      "gtk-4.0/settings.ini" = {
        type = "copy";
        text = gtkSettings;
      };
      "gtk-3.0/gtk.css" = {
        type = "copy";
        text = theme.adwaitaGtkCss;
      };
      "gtk-4.0/gtk.css" = {
        type = "copy";
        text = theme.adwaitaGtkCss;
      };

      "kdeglobals" = {
        type = "copy";
        text = ''
          [General]
          ColorScheme=${kdeColorSchemeName}
          Name=NC ${theme.name}
          shadeSortColumn=true

          [Icons]
          Theme=${theme.icons.name}

          [KDE]
          LookAndFeelPackage=org.kde.breezedark.desktop
          SingleClick=false
          contrast=4
          widgetStyle=Breeze

          [UiSettings]
          ColorScheme=${kdeColorSchemeName}

          [WM]
          activeBackground=${rgb.bg1}
          activeBlend=${rgb.fg0}
          activeForeground=${rgb.fg0}
          inactiveBackground=${rgb.bg0}
          inactiveBlend=${rgb.bg3}
          inactiveForeground=${rgb.bg3}
        '';
      };
    };

    xdg.data.files."color-schemes/${kdeColorSchemeName}.colors" = {
      type = "copy";
      text = ''
        [ColorEffects:Disabled]
        Color=${rgb.bg3}
        ColorAmount=0
        ColorEffect=0
        ContrastAmount=0.65
        ContrastEffect=1
        IntensityAmount=0.1
        IntensityEffect=2

        [ColorEffects:Inactive]
        ChangeSelectionColor=true
        Color=${rgb.bg3}
        ColorAmount=0.025
        ColorEffect=2
        ContrastAmount=0.1
        ContrastEffect=2
        Enable=false
        IntensityAmount=0
        IntensityEffect=0

        [Colors:Button]
        ${colorSet rgb.bg1 rgb.bg2}

        [Colors:Complementary]
        ${colorSet rgb.bg0 rgb.bg1}

        [Colors:Header]
        ${colorSet rgb.bg1 rgb.bg0}

        [Colors:Header][Inactive]
        ${colorSet rgb.bg0 rgb.bg1}

        [Colors:Selection]
        BackgroundAlternate=${rgb.bg2}
        BackgroundNormal=${rgb.bg2}
        DecorationFocus=${rgb.yellow}
        DecorationHover=${rgb.aqua}
        ForegroundActive=${rgb.fg1}
        ForegroundInactive=${rgb.bg3}
        ForegroundLink=${rgb.yellow}
        ForegroundNegative=${rgb.red}
        ForegroundNeutral=${rgb.orange}
        ForegroundNormal=${rgb.fg1}
        ForegroundPositive=${rgb.green}
        ForegroundVisited=${rgb.purple}

        [Colors:Tooltip]
        ${colorSet rgb.bg1 rgb.bg0}

        [Colors:View]
        ${colorSet rgb.bg0 rgb.bg1}

        [Colors:Window]
        ${colorSet rgb.bg0 rgb.bg1}

        [General]
        ColorScheme=${kdeColorSchemeName}
        Name=NC ${theme.name}
        shadeSortColumn=true

        [KDE]
        contrast=4

        [WM]
        activeBackground=${rgb.bg1}
        activeBlend=${rgb.fg0}
        activeForeground=${rgb.fg0}
        inactiveBackground=${rgb.bg0}
        inactiveBlend=${rgb.bg3}
        inactiveForeground=${rgb.bg3}
      '';
    };

  };
}

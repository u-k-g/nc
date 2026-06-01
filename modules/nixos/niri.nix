{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) getExe;
  user = config.nc.user;
  theme = config.nc.theme;
  hex = color: "#${color}";
  heliumBrowser = pkgs.callPackage ../../packages/helium-browser { };
  dms = getExe pkgs.dms-shell;
  dmsThemePath = "${user.homeDirectory}/.config/DankMaterialShell/themes/nc-gruvbox.json";
  dmsTheme = {
    dark = {
      name = "NC Gruvbox Dark";
      surface = hex theme.base00;
      surfaceText = hex theme.base05;
      surfaceVariant = hex theme.base01;
      surfaceVariantText = hex theme.base06;
      background = hex theme.base00;
      backgroundText = hex theme.base05;
      outline = hex theme.base03;
      surfaceContainer = hex theme.base01;
      surfaceContainerHigh = hex theme.base02;
      surfaceContainerHighest = hex theme.base03;
      primary = hex theme.base0A;
      secondary = hex theme.base0D;
      primaryText = hex theme.base00;
      primaryContainer = hex theme.base02;
      surfaceTint = hex theme.base0C;
      error = hex theme.base08;
      warning = hex theme.base09;
      info = hex theme.base0B;
      matugen_type = "scheme-tonal-spot";
    };
    light = {
      name = "NC Gruvbox Light";
      surface = hex theme.base07;
      surfaceText = hex theme.base00;
      surfaceVariant = hex theme.base06;
      surfaceVariantText = hex theme.base01;
      background = hex theme.base07;
      backgroundText = hex theme.base00;
      outline = hex theme.base04;
      surfaceContainer = hex theme.base06;
      surfaceContainerHigh = hex theme.base05;
      surfaceContainerHighest = hex theme.base04;
      primary = hex theme.base0B;
      secondary = hex theme.base0D;
      primaryText = hex theme.base07;
      primaryContainer = hex theme.base05;
      surfaceTint = hex theme.base0C;
      error = hex theme.base08;
      warning = hex theme.base09;
      info = hex theme.base0B;
      matugen_type = "scheme-tonal-spot";
    };
  };
  dmsSettings = {
    currentThemeName = "custom";
    currentThemeCategory = "custom";
    customThemeFile = dmsThemePath;
    matugenScheme = "scheme-tonal-spot";

    fontFamily = theme.font.sans.name;
    monoFontFamily = "Iosevka Nerd Font Mono";
    fontScale = 1.0;

    cornerRadius = theme.cornerRadius;
    niriLayoutGapsOverride = 16;
    niriLayoutRadiusOverride = theme.cornerRadius;
    niriLayoutBorderSize = 0;

    widgetBackgroundColor = "sch";
    widgetColorMode = "default";
    controlCenterTileColorMode = "primary";
    buttonColorMode = "primary";
    workspaceColorMode = "default";
    workspaceOccupiedColorMode = "primary";
    workspaceUnfocusedColorMode = "default";
    workspaceFocusedBorderEnabled = false;
    workspaceFocusedBorderColor = "primary";
    workspaceFocusedBorderThickness = 2;

    showWorkspaceIndex = true;
    showWorkspaceApps = true;
    workspaceFollowFocus = true;
    showOccupiedWorkspacesOnly = false;
    runningAppsCurrentWorkspace = true;
    runningAppsGroupByApp = false;

    use24HourClock = true;
    showSeconds = false;
    weatherEnabled = false;
    showWeather = false;

    appLauncherViewMode = "list";
    spotlightModalViewMode = "list";
    sortAppsAlphabetically = false;
    dankLauncherV2Size = "compact";
    dankLauncherV2BorderEnabled = true;
    dankLauncherV2BorderColor = "primary";

    gtkThemingEnabled = true;
    qtThemingEnabled = true;
    syncModeWithPortal = true;

    barConfigs = [
      {
        id = "default";
        name = "Main Bar";
        enabled = true;
        position = 0;
        screenPreferences = [ "all" ];
        showOnLastDisplay = true;
        leftWidgets = [
          "launcherButton"
          "workspaceSwitcher"
          "focusedWindow"
        ];
        centerWidgets = [
          "clock"
          "music"
        ];
        rightWidgets = [
          "systemTray"
          "clipboard"
          "cpuUsage"
          "memUsage"
          "notificationButton"
          "battery"
          "controlCenterButton"
        ];
        spacing = 4;
        innerPadding = 4;
        bottomGap = 0;
        transparency = 1.0;
        widgetTransparency = 1.0;
        squareCorners = false;
        noBackground = false;
        maximizeWidgetIcons = false;
        maximizeWidgetText = false;
        removeWidgetPadding = false;
        widgetPadding = theme.padding;
        gothCornersEnabled = false;
        gothCornerRadiusOverride = false;
        gothCornerRadiusValue = theme.cornerRadius;
        borderEnabled = false;
        borderColor = "surfaceText";
        borderOpacity = 1.0;
        borderThickness = 1;
        widgetOutlineEnabled = false;
        widgetOutlineColor = "primary";
        widgetOutlineOpacity = 1.0;
        widgetOutlineThickness = 1;
        fontScale = 1.0;
        iconScale = 1.0;
        autoHide = false;
        autoHideDelay = 250;
        showOnWindowsOpen = false;
        openOnOverview = false;
        visible = true;
        popupGapsAuto = true;
        popupGapsManual = 4;
        maximizeDetection = true;
        scrollEnabled = true;
        scrollXBehavior = "column";
        scrollYBehavior = "workspace";
        shadowIntensity = 0;
        shadowOpacity = 60;
        shadowColorMode = "text";
        shadowCustomColor = "#000000";
        clickThrough = false;
      }
    ];
  };
in

{
  programs = {
    niri.enable = true;
    xwayland.enable = true;

    dsearch = {
      enable = true;
      systemd.enable = true;
    };

    dms-shell = {
      enable = true;
      quickshell.package = pkgs.quickshell;
      systemd.enable = true;

      enableAudioWavelength = true;
      enableCalendarEvents = true;
      enableClipboardPaste = true;
      enableDynamicTheming = true;
      enableSystemMonitoring = true;
      enableVPN = true;
    };
  };

  services.displayManager = {
    defaultSession = "niri";

    dms-greeter = {
      enable = true;
      configHome = config.nc.user.homeDirectory;
      compositor.name = "niri";
      quickshell.package = pkgs.quickshell;
    };
  };

  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    dgop
    dms-shell
    dsearch
    matugen
    niri
    niriswitcher
    nirius
    nwg-displays
    sunsetr
    xwayland-satellite
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  home-manager.users.${user.name}.xdg.configFile = {
    "niri/config.kdl" = {
      force = true;
      text = ''
        input {
            keyboard {
                numlock
            }

            touchpad {
                tap
                natural-scroll
            }

            mod-key "Alt"
            workspace-auto-back-and-forth
        }

        layout {
            gaps 16
            center-focused-column "never"

            preset-column-widths {
                proportion 0.33333
                proportion 0.5
                proportion 0.66667
            }

            default-column-width { proportion 0.5; }

            focus-ring { off; }
        }

        window-rule {
            match app-id=r#"firefox$"# title="^Picture-in-Picture$"
            open-floating true
        }

        binds {
            Alt+Slash { show-hotkey-overlay; }
            Alt+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
            Alt+Shift+Slash repeat=false { spawn "${dms}" "ipc" "call" "keybinds" "toggle" "niri"; }
            Alt+Comma repeat=false { spawn "${dms}" "ipc" "call" "settings" "focusOrToggle"; }
            Alt+X repeat=false { spawn "${dms}" "ipc" "call" "powermenu" "toggle"; }

            // Match the Darwin/Paneru app launchers. Alt is physical Option after keyd remaps PC Win to Option.
            Alt+W repeat=false { spawn "${getExe heliumBrowser}"; }
            Alt+O repeat=false { spawn "${getExe pkgs.obsidian}"; }
            Alt+Semicolon repeat=false { spawn "${getExe pkgs.kitty}"; }
            Alt+C repeat=false { spawn "${lib.getExe' pkgs.freecad "freecad"}"; }
            Alt+R repeat=false { spawn "${getExe pkgs.opencode-desktop}"; }
            Alt+Z repeat=false { spawn "${getExe pkgs.zed-editor}"; }

            Alt+H { focus-column-left; }
            Alt+J { focus-window-down; }
            Alt+K { focus-window-up; }
            Alt+L { focus-column-right; }

            Alt+Shift+H { move-column-left; }
            Alt+Shift+J { move-window-down; }
            Alt+Shift+K { move-window-up; }
            Alt+Shift+L { move-column-right; }

            Alt+Shift+T { consume-window-into-column; }
            Alt+Shift+G { expel-window-from-column; }
            Alt+Ctrl+F { toggle-window-floating; }
            Alt+F { maximize-column; }
            Alt+S { center-column; }
            Alt+Shift+Minus { set-column-width "-10%"; }
            Alt+Shift+Equal { set-column-width "+10%"; }

            Alt+1 { focus-workspace 1; }
            Alt+2 { focus-workspace 2; }
            Alt+3 { focus-workspace 3; }
            Alt+4 { focus-workspace 4; }
            Alt+5 { focus-workspace 5; }
            Alt+6 { focus-workspace 6; }
            Alt+7 { focus-workspace 7; }
            Alt+8 { focus-workspace 8; }
            Alt+9 { focus-workspace 9; }

            Alt+Shift+1 { move-window-to-workspace 1; }
            Alt+Shift+2 { move-window-to-workspace 2; }
            Alt+Shift+3 { move-window-to-workspace 3; }
            Alt+Shift+4 { move-window-to-workspace 4; }
            Alt+Shift+5 { move-window-to-workspace 5; }
            Alt+Shift+6 { move-window-to-workspace 6; }
            Alt+Shift+7 { move-window-to-workspace 7; }
            Alt+Shift+8 { move-window-to-workspace 8; }
            Alt+Shift+9 { move-window-to-workspace 9; }

            Alt+Q repeat=false { close-window; }
            Alt+M { maximize-window-to-edges; }
            Alt+V { toggle-window-floating; }
            Alt+Shift+V { switch-focus-between-floating-and-tiling; }
            Alt+Tab { focus-workspace-previous; }
            Alt+Space repeat=false { spawn "${dms}" "ipc" "call" "spotlight" "toggle"; }
            Alt+Shift+Space { toggle-overview; }

            XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
            XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
            XF86AudioMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
            XF86AudioMicMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
            XF86AudioPlay allow-when-locked=true { spawn-sh "playerctl play-pause"; }
            XF86AudioStop allow-when-locked=true { spawn-sh "playerctl stop"; }
            XF86AudioPrev allow-when-locked=true { spawn-sh "playerctl previous"; }
            XF86AudioNext allow-when-locked=true { spawn-sh "playerctl next"; }
            XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
            XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }

            Print { screenshot; }
            Ctrl+Print { screenshot-screen; }
            Alt+Print { screenshot-window; }

            Alt+Shift+E { quit; }
            Ctrl+Alt+Delete { quit; }
            Alt+Shift+P { power-off-monitors; }
        }
      '';
    };

    "DankMaterialShell/themes/nc-gruvbox.json" = {
      force = true;
      text = builtins.toJSON dmsTheme;
    };
    "DankMaterialShell/settings.json" = {
      force = true;
      text = builtins.toJSON dmsSettings;
    };
  };
}

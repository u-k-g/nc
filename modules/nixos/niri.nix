{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.generators) toJSON;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  user = config.nc.user;
  theme = config.nc.theme;
  hex = color: "#${color}";
  heliumBrowser = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium-widevine;
  edgePkgs = inputs.edge.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  suzuri = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.suzuri;
  dms = getExe pkgs.dms-shell;
  qtEnvironment = [
    "QT_QPA_PLATFORMTHEME=${config.qt.platformTheme}"
    "QT_STYLE_OVERRIDE=${config.qt.style}"
  ];
  focusOrLaunch = pkgs.writers.writeNuBin "nc-focus-or-launch" ''
    def main [pattern: string, ...command: string] {
      let result = (^${getExe pkgs.niri} msg -j windows | complete)
      let windows = if $result.exit_code == 0 {
        try { $result.stdout | from json } catch { [] }
      } else {
        []
      }

      let focused = (^${getExe pkgs.niri} msg -j focused-window | complete)
      let focused_id = if $focused.exit_code == 0 {
        try { $focused.stdout | from json | get id } catch { null }
      } else {
        null
      }

      let matches = ($windows
        | where {|window|
            ($window | get --optional app_id | default "" | into string | str downcase | str contains ($pattern | str downcase))
          }
        | sort-by {|window|
            [
              ($window | get --optional focus_timestamp.secs | default 0)
              ($window | get --optional focus_timestamp.nanos | default 0)
            ]
          }
      )

      let candidates = if ($matches | any {|window| $window.id == $focused_id }) {
        $matches | where {|window| $window.id != $focused_id }
      } else {
        $matches | reverse
      }

      let id = (try {
        if ($candidates | is-empty) {
          $matches | first | get id
        } else {
          $candidates | first | get id
        }
      } catch { null })

      if $id != null {
        exec ${getExe pkgs.niri} msg action focus-window --id $id
      }

      if ($command | is-empty) {
        exit 0
      }

      exec ...$command
    }
  '';
  cycleFocusedApp = pkgs.writers.writeNuBin "nc-cycle-focused-app" ''
    def main [] {
      let result = (^${getExe pkgs.niri} msg -j focused-window | complete)
      if $result.exit_code != 0 { exit 1 }
      let app_id = (try { $result.stdout | from json | get app_id } catch { "" })
      if $app_id == "" { exit 1 }
      exec ${getExe focusOrLaunch} $app_id
    }
  '';
  dmsThemePath = "${user.homeDirectory}/.config/DankMaterialShell/themes/nc-${theme.slug}.json";
  dmsTheme = {
    dark = {
      name = "NC ${theme.name} Dark";
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
      name = "NC ${theme.name} Light";
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
    popupTransparency = 0.38;

    fontFamily = "RecMonoLinear Nerd Font";
    monoFontFamily = "Iosevka Nerd Font Mono";
    fontScale = 1.0;

    cornerRadius = 5;
    niriLayoutGapsOverride = 16;
    niriLayoutRadiusOverride = theme.cornerRadius;
    niriLayoutBorderSize = 0;

    firstDayOfWeek = 2;
    clockFormat = "12h";
    showSeconds = true;
    padHours12Hour = true;
    clockDateFormat = "M/d";
    lockDateFormat = "ddd dd.MM";

    animationSpeed = 4;
    customAnimationDuration = 100;

    blurEnabled = true;
    blurWallpaperOnOverview = true;

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

    weatherEnabled = false;
    showWeather = false;

    appLauncherViewMode = "list";
    spotlightModalViewMode = "list";
    sortAppsAlphabetically = false;
    dankLauncherV2Size = "compact";
    dankLauncherV2BorderEnabled = true;
    dankLauncherV2BorderColor = "primary";
    spotlightBarShowModeChips = true;

    cursorSettings = {
      theme = "breeze_cursors";
      size = 22;
      niri = {
        hideWhenTyping = false;
        hideAfterInactiveMs = 0;
      };
      hyprland = {
        hideOnKeyPress = false;
        hideOnTouch = false;
        inactiveTimeout = 0;
      };
      dwl.cursorHideTimeout = 0;
      mango.cursorHideTimeout = 0;
    };

    gtkThemingEnabled = true;
    qtThemingEnabled = true;
    syncModeWithPortal = true;

    showDock = true;
    dockSmartAutoHide = true;
    dockOpenOnOverview = true;

    screenPreferences.wallpaper = lib.lists.singleton "all";

    barConfigs = lib.lists.singleton {
      id = "default";
      name = "Main Bar";
      enabled = true;
      position = 0;
      screenPreferences = lib.lists.singleton "all";
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
      transparency = 0.5;
      widgetTransparency = 1.0;
      squareCorners = false;
      noBackground = false;
      maximizeWidgetIcons = false;
      maximizeWidgetText = false;
      removeWidgetPadding = false;
      widgetPadding = theme.padding;
      gothCornersEnabled = false;
      gothCornerRadiusOverride = false;
      gothCornerRadiusValue = 10;
      borderEnabled = false;
      borderColor = "surfaceText";
      borderOpacity = 1.0;
      borderThickness = 1;
      widgetOutlineEnabled = false;
      widgetOutlineColor = "primary";
      widgetOutlineOpacity = 1.0;
      widgetOutlineThickness = 1;
      fontScale = 1.0;
      iconScale = 0.9;
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
    };
  };
in

{
  options.nc.nixos.niri.enable = mkEnableOption "Niri desktop environment";

  config = mkIf config.nc.nixos.niri.enable {
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

    environment.systemPackages = (with pkgs; [
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
    ]) ++ [
      pkgs.t3code
      suzuri
    ];

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      XCURSOR_THEME = dmsSettings.cursorSettings.theme;
      XCURSOR_SIZE = toString dmsSettings.cursorSettings.size;
    };

    systemd.user.services = {
      dms.serviceConfig.Environment = qtEnvironment;
      dsearch.serviceConfig.Environment = qtEnvironment;
    };

    home.users.${user.name}.xdg.config.files = {
      "niri/config.kdl" = {
        type = "copy";
        text = ''
          spawn-at-startup "${getExe pkgs.niriswitcher}"

          input {
              keyboard {
                  numlock
              }

              mouse {
                  accel-profile "flat"
              }

              touchpad {
                  accel-profile "flat"
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
              Ctrl+Alt+Slash { show-hotkey-overlay; }
              Ctrl+Alt+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
              Ctrl+Alt+Comma repeat=false { spawn "${dms}" "ipc" "call" "settings" "focusOrToggle"; }
              Ctrl+Alt+X repeat=false { spawn "${dms}" "ipc" "call" "powermenu" "toggle"; }
              // Toshy makes the physical Option position Alt on PC and Mac keyboards.
              Alt+W repeat=false { spawn "${getExe focusOrLaunch}" "helium" "${getExe heliumBrowser}"; }
              Alt+Semicolon repeat=false { spawn "${getExe focusOrLaunch}" "kitty" "${getExe edgePkgs.kitty}"; }
              Alt+Shift+F12 repeat=false { spawn "${getExe focusOrLaunch}" "kitty" "${getExe edgePkgs.kitty}"; }
              Alt+A repeat=false { spawn "${getExe focusOrLaunch}" "suzuri" "${getExe suzuri}"; }
              Alt+Shift+F repeat=false { spawn "${getExe focusOrLaunch}" "dolphin" "${getExe pkgs.kdePackages.dolphin}"; }
              Alt+R repeat=false { spawn "${getExe focusOrLaunch}" "opencode" "${getExe pkgs.opencode-desktop}"; }
              Alt+T repeat=false { spawn "${getExe focusOrLaunch}" "t3code" "${getExe pkgs.t3code}"; }
              Alt+Z repeat=false { spawn "${getExe focusOrLaunch}" "zed" "${getExe edgePkgs.zed-editor}"; }

              Alt+H { focus-column-left; }
              Alt+J { focus-workspace-down; }
              Alt+K { focus-workspace-up; }
              Alt+L { focus-column-right; }
              Alt+Ctrl+J { focus-window-down; }
              Alt+Ctrl+K { focus-window-up; }

              Alt+Shift+H { move-column-left; }
              Alt+Shift+J { move-window-to-workspace-down; }
              Alt+Shift+K { move-window-to-workspace-up; }
              Alt+Shift+L { move-column-right; }

              Alt+Shift+T { consume-window-into-column; }
              Alt+Shift+G { expel-window-from-column; }
              Alt+Ctrl+F { toggle-window-floating; }
              Alt+Super+F { toggle-window-floating; }
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

              Alt+F4 { close-window; }
              Alt+Tab repeat=false { spawn "${lib.getExe' pkgs.niriswitcher "niriswitcherctl"}" "show" "--window"; }
              Alt+Shift+Tab repeat=false { spawn "${lib.getExe' pkgs.niriswitcher "niriswitcherctl"}" "show" "--window"; }
              Alt+Grave repeat=false { spawn "${getExe cycleFocusedApp}"; }
              Alt+Shift+Grave repeat=false { spawn "${getExe cycleFocusedApp}"; }
              Ctrl+Alt+Space repeat=false { spawn "${dms}" "ipc" "call" "spotlight" "toggle"; }
              Ctrl+Alt+Shift+Space { toggle-overview; }

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

              Ctrl+Alt+Delete { quit; }
              Ctrl+Alt+Shift+P { power-off-monitors; }
          }
        '';
      };

      "DankMaterialShell/themes/nc-${theme.slug}.json" = {
        type = "copy";
        text = toJSON { } dmsTheme;
      };
      "DankMaterialShell/settings.json" = {
        type = "copy";
        text = toJSON { } dmsSettings;
      };
    };
  };

}

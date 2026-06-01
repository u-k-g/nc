{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) getExe;
  user = config.nc.user;
  heliumBrowser = pkgs.callPackage ../../packages/helium-browser { };
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
    dgop
    dms-shell
    dsearch
    matugen
    niri
    niriswitcher
    nirius
    nwg-displays
    sunsetr
  ];

  home-manager.users.${user.name}.xdg.configFile."niri/config.kdl" = {
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

          focus-ring {
              width 4
              active-color "#7fc8ff"
              inactive-color "#505050"
          }
      }

      window-rule {
          match app-id=r#"firefox$"# title="^Picture-in-Picture$"
          open-floating true
      }

      binds {
          Alt+Slash { show-hotkey-overlay; }
          Alt+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

          // Darwin/Paneru app launchers. Alt is physical Option after keyd remaps PC Win to Option.
          Alt+W repeat=false { spawn "${getExe heliumBrowser}"; }
          Alt+O repeat=false { spawn "${getExe pkgs.obsidian}"; }
          Alt+G repeat=false { spawn "${getExe pkgs.ghostty}"; }
          Alt+Y repeat=false { spawn "${getExe pkgs.kdePackages.dolphin}"; }
          Alt+C repeat=false { spawn "${lib.getExe' pkgs.freecad "freecad"}"; }
          Alt+R repeat=false { spawn "${getExe pkgs.opencode-desktop}"; }
          Alt+Z repeat=false { spawn "${getExe pkgs.zed-editor}"; }
          Alt+T repeat=false { spawn "${getExe pkgs.ghostty}"; }

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
          Alt+Space { toggle-overview; }

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
}

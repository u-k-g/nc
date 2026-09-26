{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkIf;
  inherit (lib.strings) escapeShellArg;
  user = config.nc.user;
  source = inputs.toshy;
  runtime = inputs.toshy.packages.${pkgs.stdenv.hostPlatform.system}.toshy-runtime;
  capsMarker = "###  SLICE_MARK_START: user_custom_modmaps  ###  EDITS OUTSIDE THESE MARKS WILL BE LOST ON UPGRADE";
  appsMarker = "###  SLICE_MARK_START: user_apps  ###  EDITS OUTSIDE THESE MARKS WILL BE LOST ON UPGRADE";
  toshyConfig = pkgs.callPackage (
    { coreutils, runCommand }:
    runCommand "toshy-config.py" { } ''
      ${getExe' coreutils "cp"} ${source}/default-toshy-config/toshy_config.py "$out"
      substituteInPlace "$out" \
        --replace-fail ${escapeShellArg "cnfg = Settings(current_folder_path)"} ${escapeShellArg ''
          cnfg = Settings(current_folder_path)
          # Match the Mac's US Option characters and keep Caps available for Hyper.
          cnfg.optspec_layout = 'US'
          cnfg.capslock_mode = 'caps_is_caps'
          cnfg.save_settings()
        ''} \
        --replace-fail ${escapeShellArg capsMarker} ${escapeShellArg ''
          ${capsMarker}
          setup_hyper(
              Key.CAPSLOCK,
              tap_output=Key.ESC,
              when=lambda ctx: cnfg.screen_has_focus and not ctx_app_is_remote,
          )

          # Reserve Paneru/Karabiner's Option chords before Toshy's Option
          # character keymaps, which appear later in the upstream config.
          keymap("NC niri Option chords", {
              **{C(f"Alt-{key}"): C(f"Alt-{key}") for key in (
                  "W", "A", "R", "T", "Z", "H", "J", "K", "L", "F", "S",
                  "Semicolon", "1", "2", "3", "4", "5", "6", "7", "8", "9",
              )},
              **{C(f"Alt-Shift-{key}"): C(f"Alt-Shift-{key}") for key in (
                  "F", "H", "J", "K", "L", "T", "G", "Minus", "Equal",
                  "1", "2", "3", "4", "5", "6", "7", "8", "9",
              )},
              C("Alt-RC-J"): C("Alt-RC-J"),
              C("Alt-RC-K"): C("Alt-RC-K"),
              C("Alt-Super-F"): C("Alt-Super-F"),
              # Cmd+grave already emits Alt+grave for same-app window cycling.
              C("Alt-Grave"): C("Alt-Shift-F12"),
          }, when=lambda ctx: cnfg.screen_has_focus and not ctx_app_is_remote)
        ''} \
        --replace-fail ${escapeShellArg appsMarker} ${escapeShellArg ''
          ${appsMarker}
          keymap("NC Mac and Hyper keys", {
              C("Hyper-h"): C("Left"),
              C("Hyper-j"): C("Down"),
              C("Hyper-k"): C("Up"),
              C("Hyper-l"): C("Right"),
              C("F6"): C("Delete"),
              C("RC-Space"): [iEF2NT(), C("C-Alt-Space")],
          }, when=lambda ctx: cnfg.screen_has_focus and not ctx_app_is_remote)
        ''}
    ''
  ) { };
in
{
  imports = singleton inputs.toshy.nixosModules.toshy;

  config = mkIf config.nc.nixos.niri.enable {
    services.toshy = {
      enable = true;
      users = singleton user.name;
    };

    home.users.${user.name} = {
      files.".local/state/toshy/runtime".source = runtime;

      xdg.config.files = {
        "toshy/toshy_config.py".source = toshyConfig;
        "toshy/toshy_common".source = source + /toshy_common;
        "toshy/scripts".source = source + /scripts;
        "toshy/wlroots-dbus-service".source = source + /wlroots-dbus-service;
        "toshy/toshy_gui".source = source + /toshy_gui;
        "toshy/assets".source = source + /assets;
        "toshy/toshy_tray.py".source = source + /toshy_tray.py;
        "toshy/toshy_layout_selector.py".source = source + /toshy_layout_selector.py;
      };
    };

    systemd.user.services = {
      toshy-wlroots-dbus = {
        description = "Toshy niri window context";
        wantedBy = singleton "graphical-session.target";
        partOf = singleton "graphical-session.target";
        path = [
          pkgs.bash
          pkgs.coreutils
          pkgs.procps
          pkgs.systemd
        ];
        environment.TOSHY_RUNTIME_DIR = "${runtime}";
        serviceConfig = {
          ExecStart = "${getExe pkgs.bash} ${source}/scripts/bin/toshy-wlroots-dbus-service.sh";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      toshy-config = {
        description = "Toshy Mac keyboard mappings";
        wantedBy = singleton "graphical-session.target";
        partOf = singleton "graphical-session.target";
        wants = singleton "toshy-wlroots-dbus.service";
        after = singleton "toshy-wlroots-dbus.service";
        path = [
          pkgs.bash
          pkgs.coreutils
          pkgs.procps
          pkgs.systemd
        ];
        environment.TOSHY_RUNTIME_DIR = "${runtime}";
        serviceConfig = {
          Environment = "TERM=xterm";
          ExecStart = "${getExe pkgs.bash} ${source}/scripts/tshysvc-config";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
  };
}

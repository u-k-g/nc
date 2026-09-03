{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  inherit (lib.modules) mkAfter mkForce mkIf;
  inherit (lib.options) mkEnableOption;

  cosmicSession = getExe' pkgs.cosmic-session "start-cosmic";
  environment = getExe' pkgs.coreutils "env";
  systemdCat = getExe' pkgs.systemd "systemd-cat";
  user = config.nc.user;
  managed = text: {
    type = "copy";
    inherit text;
  };

  cosmicRun = pkgs.callPackage (
    {
      coreutils,
      lib,
      systemd,
      writeShellApplication,
    }:
    let
      inherit (lib.meta) getExe';
      id = getExe' coreutils "id";
      systemctl = getExe' systemd "systemctl";
    in
    writeShellApplication {
      name = "cosmic-run";
      text = ''
        if (( $# == 0 )); then
          printf 'usage: cosmic-run COMMAND [ARGUMENT...]\n' >&2
          exit 64
        fi

        runtimeDirectory="''${XDG_RUNTIME_DIR:-/run/user/$(${id} --user)}"
        export XDG_RUNTIME_DIR="$runtimeDirectory"
        export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtimeDirectory/bus}"

        while IFS='=' read -r name value; do
          case "$name" in
            DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|XDG_CURRENT_DESKTOP|XDG_SESSION_DESKTOP|XDG_SESSION_TYPE)
              export "$name=$value"
              ;;
          esac
        done < <(${systemctl} --user show-environment)

        if [[ -z ''${WAYLAND_DISPLAY:-} || ! -S "$runtimeDirectory/$WAYLAND_DISPLAY" ]]; then
          unset WAYLAND_DISPLAY
          for socket in "$runtimeDirectory"/wayland-*; do
            if [[ -S "$socket" ]]; then
              export WAYLAND_DISPLAY="''${socket##*/}"
              break
            fi
          done
        fi

        if [[ -z ''${WAYLAND_DISPLAY:-} ]]; then
          printf 'cosmic-run: no live Wayland socket in %s\n' "$runtimeDirectory" >&2
          exit 69
        fi

        exec "$@"
      '';
    }
  ) { };
in
{
  options.nc.nixos.cosmic.enable = mkEnableOption "COSMIC desktop environment";

  config = mkIf config.nc.nixos.cosmic.enable {
    services.desktopManager.cosmic = {
      enable = true;
      xwayland.enable = true;
    };

    services.displayManager = {
      cosmic-greeter.enable = true;

      autoLogin = {
        enable = true;
        user = user.name;
      };
    };

    services.greetd.settings.default_session = mkForce {
      command = "${environment} XCURSOR_THEME=Pop ${systemdCat} --identifier=cosmic-session ${cosmicSession}";
      user = user.name;
    };

    services.xserver.enable = false;

    systemd.defaultUnit = "graphical.target";

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.systemPackages = singleton cosmicRun;

    home.users.${user.name}.xdg.config.files = {
      "cosmic-initial-setup-done" = managed "";

      "cosmic/com.system76.CosmicComp/v1/active_hint" = managed "false";
      "cosmic/com.system76.CosmicComp/v1/autotile" = managed "false";
      "cosmic/com.system76.CosmicComp/v1/cursor_hide_timeout" = managed "None";
      "cosmic/com.system76.CosmicComp/v1/focus_follows_cursor" = managed "false";

      "cosmic/com.system76.CosmicIdle/v1/screen_off_time" = managed "None";
      "cosmic/com.system76.CosmicIdle/v1/suspend_on_ac_time" = managed "None";
      "cosmic/com.system76.CosmicIdle/v1/suspend_on_battery_time" = managed "None";

      "cosmic/com.system76.CosmicTheme.Dark/v2/frosted_applets" = managed "false";
      "cosmic/com.system76.CosmicTheme.Dark/v2/frosted_panel" = managed "false";
      "cosmic/com.system76.CosmicTheme.Dark/v2/frosted_system_interface" = managed "false";
      "cosmic/com.system76.CosmicTheme.Dark/v2/frosted_windows" = managed "false";

      "cosmic/com.system76.CosmicTheme.Light/v2/frosted_applets" = managed "false";
      "cosmic/com.system76.CosmicTheme.Light/v2/frosted_panel" = managed "false";
      "cosmic/com.system76.CosmicTheme.Light/v2/frosted_system_interface" = managed "false";
      "cosmic/com.system76.CosmicTheme.Light/v2/frosted_windows" = managed "false";

      "gtk-3.0/settings.ini".text = mkAfter "gtk-enable-animations=false\n";
      "gtk-4.0/settings.ini".text = mkAfter "gtk-enable-animations=false\n";
    };
  };
}

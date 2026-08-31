{
  config,
  lib,
  ...
}:

let
  inherit (lib.modules) mkAfter mkIf;
  inherit (lib.options) mkEnableOption;

  user = config.nc.user;
  managed = text: {
    type = "copy";
    inherit text;
  };
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

    services.xserver.enable = false;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

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

{ ... }:

{
  flake.nixosModules.browser-cdp-service =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) escapeShellArgs;
      inherit (lib.types) port;

    in
    {
      options.nc.nixos.hermes.browser-cdp = {
        enable = mkEnableOption "headless Chromium for browser automation";

        port = mkOption {
          type = port;
          default = 9333;
          description = "Loopback CDP port for the isolated automation browser.";
        };
      };

      config.systemd.user.services.browser-cdp = mkIf config.nc.nixos.hermes.browser-cdp.enable {
        description = "Headless Chromium browser automation";
        wantedBy = singleton "default.target";
        unitConfig.ConditionUser = config.nc.user.name;
        startLimitIntervalSec = 0;

        serviceConfig = {
          ExecStart = escapeShellArgs [
            (getExe pkgs.chromium)
            "--remote-debugging-address=127.0.0.1"
            "--remote-debugging-port=${toString config.nc.nixos.hermes.browser-cdp.port}"
            "--user-data-dir=%h/.hermes/browser-automation-chromium-profile"
            "--headless=new"
          ];
          Restart = "always";
          RestartSec = 5;
          UMask = "0077";
          # Chromium's headless CDP navigation stalls when it inherits the
          # desktop session bus from the user manager.
          UnsetEnvironment = singleton "DBUS_SESSION_BUS_ADDRESS";
        };
      };
    };
}

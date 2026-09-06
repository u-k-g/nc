{ inputs, ... }:

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

      heliumBrowser = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium-widevine;
    in
    {
      options.nc.nixos.hermes.browser-cdp = {
        enable = mkEnableOption "headless Helium for browser automation";

        port = mkOption {
          type = port;
          default = 9333;
          description = "Loopback CDP port for the isolated automation browser.";
        };
      };

      config.systemd.user.services.browser-cdp = mkIf config.nc.nixos.hermes.browser-cdp.enable {
        description = "Headless Helium browser automation";
        wantedBy = singleton "default.target";
        unitConfig.ConditionUser = config.nc.user.name;
        startLimitIntervalSec = 0;

        serviceConfig = {
          ExecStart = escapeShellArgs [
            (getExe heliumBrowser)
            "--remote-debugging-port=${toString config.nc.nixos.hermes.browser-cdp.port}"
            "--user-data-dir=%h/.hermes/browser-automation-profile"
            "--headless=new"
          ];
          Restart = "always";
          RestartSec = 5;
          UMask = "0077";
        };
      };
    };
}

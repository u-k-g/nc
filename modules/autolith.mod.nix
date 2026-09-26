{ inputs, ... }:

{
  commonModules.autolith =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.types) bool;
    in
    {
      options.nc.autolith.enable = mkOption {
        type = bool;
        default = true;
        description = "Whether to install Autolith system-wide.";
      };

      config.environment.systemPackages =
        mkIf config.nc.autolith.enable
        <| singleton inputs.autolith.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
}

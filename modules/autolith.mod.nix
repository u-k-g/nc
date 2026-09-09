{ inputs, ... }:

{
  commonModules.autolith =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      environment.systemPackages =
        singleton
          inputs.autolith.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
}

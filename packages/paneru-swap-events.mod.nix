{ inputs, ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) optionalAttrs;
      inherit (lib.lists) singleton;
    in
    {
      packages = optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        paneru-swap-events =
          inputs.paneru.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
            (
              {
                patches ? [ ],
                ...
              }:
              {
              patches = patches ++ singleton ./paneru-swap-events.patch;
              }
            );
      };
    };
}

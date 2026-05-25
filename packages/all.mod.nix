{ ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        fast-workspace-switch = pkgs.callPackage ./fast-workspace-switch { };
      };
    };
}

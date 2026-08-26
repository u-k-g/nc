{ ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages =
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          fast-workspace-switch = pkgs.callPackage ./fast-workspace-switch { };
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64) {
          helium-browser = pkgs.callPackage ./helium-browser { };
        };
    };
}

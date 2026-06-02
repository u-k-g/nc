{ ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages =
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          fast-workspace-switch = pkgs.callPackage ./fast-workspace-switch { };
          t3-code-nightly = pkgs.callPackage ./t3-code-nightly { };
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          helium-browser = pkgs.callPackage ./helium-browser { };
        };
    };
}

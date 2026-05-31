{ ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages =
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          fast-workspace-switch = pkgs.callPackage ./fast-workspace-switch { };
          pi-coding-agent = pkgs.callPackage ./pi-coding-agent { };
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          helium-browser = pkgs.callPackage ./helium-browser { };
          pi-coding-agent = pkgs.callPackage ./pi-coding-agent { };
        };
    };
}
